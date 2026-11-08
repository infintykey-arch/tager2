import 'package:drift/drift.dart';

import '../../../core/payment_snapshot.dart';
import '../../../data/local/app_database.dart';

class PurchaseLineDraft {
  const PurchaseLineDraft({
    required this.productName,
    required this.purchasePriceMinor,
    required this.salePriceMinor,
    required this.quantity,
    this.productId,
  });

  final int? productId;
  final String productName;
  final int purchasePriceMinor;
  final int salePriceMinor;
  final double quantity;
}

class PurchaseDraft {
  const PurchaseDraft({
    required this.supplierName,
    required this.lines,
    required this.amountPaidMinor,
    required this.requestKey,
    this.occurredAt,
  });

  final String supplierName;
  final List<PurchaseLineDraft> lines;
  final int amountPaidMinor;
  final String requestKey;
  final DateTime? occurredAt;
}

class PurchaseLineSnapshot {
  const PurchaseLineSnapshot({
    required this.productId,
    required this.productName,
    required this.purchasePriceMinor,
    required this.salePriceMinor,
    required this.quantity,
    required this.lineTotalMinor,
  });

  final int? productId;
  final String productName;
  final int purchasePriceMinor;
  final int salePriceMinor;
  final double quantity;
  final int lineTotalMinor;
}

class PurchaseReceipt {
  const PurchaseReceipt({
    required this.id,
    required this.invoiceNumber,
    required this.supplierName,
    required this.totalMinor,
    required this.paidMinor,
    required this.createdAt,
    required this.lines,
    this.payments = const [],
  });

  final int id;
  final String invoiceNumber;
  final String supplierName;
  final int totalMinor;
  final int paidMinor;
  final DateTime createdAt;
  final List<PurchaseLineSnapshot> lines;
  final List<PaymentSnapshot> payments;

  int get remainingMinor => totalMinor - paidMinor;
}

abstract interface class PurchasesRepository {
  Future<PurchaseReceipt> createPurchase(PurchaseDraft draft);

  Future<PurchaseReceipt?> getPurchase(int purchaseId);

  Future<List<PurchaseReceipt>> getOpenPurchases();

  Future<int> getSupplierCount();

  Future<PurchaseReceipt> addPayment({
    required int purchaseId,
    required int amountMinor,
    required String requestKey,
    DateTime? occurredAt,
  });
}

class DriftPurchasesRepository implements PurchasesRepository {
  DriftPurchasesRepository(this._database);

  final AppDatabase _database;

  @override
  Future<PurchaseReceipt> createPurchase(PurchaseDraft draft) async {
    final supplierName = draft.supplierName.trim();
    final requestKey = draft.requestKey.trim();
    if (supplierName.isEmpty) {
      throw ArgumentError('اسم المورد مطلوب.');
    }
    if (requestKey.isEmpty) {
      throw ArgumentError('مفتاح العملية مطلوب لمنع تكرار فاتورة الشراء.');
    }
    if (draft.lines.isEmpty) {
      throw ArgumentError('أضف صنفًا واحدًا على الأقل إلى فاتورة الشراء.');
    }
    if (draft.amountPaidMinor < 0) {
      throw ArgumentError('المبلغ المدفوع لا يمكن أن يكون سالبًا.');
    }
    for (final line in draft.lines) {
      final thousandths = line.quantity * 1000;
      if (!line.quantity.isFinite ||
          line.quantity <= 0 ||
          (thousandths - thousandths.round()).abs() > 0.000001) {
        throw ArgumentError('الكمية تقبل أرقامًا موجبة حتى ثلاث خانات عشرية.');
      }
      if (line.purchasePriceMinor < 0 || line.salePriceMinor < 0) {
        throw ArgumentError('الأسعار لا يمكن أن تكون سالبة.');
      }
      if (line.productId == null && line.productName.trim().isEmpty) {
        throw ArgumentError('أدخل اسم المنتج الجديد.');
      }
    }

    final occurredAt = (draft.occurredAt ?? DateTime.now()).toUtc();
    final occurredAtText = occurredAt.toIso8601String();
    return _database.transaction(() async {
      final existing =
          await (_database.select(_database.purchases)
                ..where((table) => table.requestKey.equals(requestKey))
                ..limit(1))
              .get();
      if (existing.isNotEmpty) {
        final receipt = await _loadReceipt(existing.single.id);
        if (receipt == null) {
          throw StateError('تعذر استعادة فاتورة الشراء المسجلة.');
        }
        return receipt;
      }

      final normalizedSupplierName = _normalizeName(supplierName);
      final supplierRows =
          await (_database.select(_database.suppliers)
                ..where(
                  (table) =>
                      table.normalizedName.equals(normalizedSupplierName),
                )
                ..limit(1))
              .get();
      final supplierId = supplierRows.isNotEmpty
          ? supplierRows.single.id
          : await _database
                .into(_database.suppliers)
                .insert(
                  SuppliersCompanion.insert(
                    name: supplierName,
                    normalizedName: normalizedSupplierName,
                    createdAt: occurredAtText,
                    updatedAt: occurredAtText,
                  ),
                );

      final lines = <PurchaseLineSnapshot>[];
      final weightedCosts = <int, _WeightedCostState>{};
      final invoiceAverageCosts = _invoiceAverageCostByProduct(draft.lines);
      final legacyCostTransitions = <int, _LegacyCostTransition>{};
      var totalMinor = 0;
      for (final draftLine in draft.lines) {
        int productId;
        String productName;
        if (draftLine.productId == null) {
          productName = draftLine.productName.trim();
          productId = await _database
              .into(_database.products)
              .insert(
                ProductsCompanion.insert(
                  name: productName,
                  purchasePriceMinor: Value(draftLine.purchasePriceMinor),
                  salePriceMinor: Value(draftLine.salePriceMinor),
                  minimumStock: const Value(0),
                  createdAt: occurredAtText,
                  updatedAt: occurredAtText,
                ),
              );
        } else {
          final productRows =
              await (_database.select(_database.products)
                    ..where((table) => table.id.equals(draftLine.productId!))
                    ..limit(1))
                  .get();
          if (productRows.isEmpty || productRows.single.isArchived) {
            throw StateError('أحد المنتجات غير موجود أو محذوف.');
          }
          final product = productRows.single;
          productId = product.id;
          productName = product.name;
          await (_database.update(
            _database.products,
          )..where((table) => table.id.equals(productId))).write(
            ProductsCompanion(
              purchasePriceMinor: Value(draftLine.purchasePriceMinor),
              salePriceMinor: Value(draftLine.salePriceMinor),
              updatedAt: Value(occurredAtText),
            ),
          );
        }

        var costState = weightedCosts[productId];
        if (costState == null) {
          await _ensurePurchaseIsNotBackdated(productId, occurredAt);
          costState = await _loadWeightedCost(productId);
          weightedCosts[productId] = costState;
          if (!costState.isReliable && costState.quantityMilli > 0) {
            final transitionCost = invoiceAverageCosts[productId];
            if (transitionCost == null) {
              throw StateError('تعذر تحديد متوسط سعر فاتورة الشراء للصنف.');
            }
            legacyCostTransitions[productId] = _LegacyCostTransition(
              legacyQuantityMilli: costState.quantityMilli,
              transitionCostMilliMinor: transitionCost,
            );
            costState.applyLegacyCostTransition(transitionCost);
          }
        }
        costState.addPurchase(
          purchasePriceMinor: draftLine.purchasePriceMinor,
          quantity: draftLine.quantity,
        );

        final lineTotalMinor =
            (draftLine.purchasePriceMinor * draftLine.quantity).round();
        totalMinor += lineTotalMinor;
        lines.add(
          PurchaseLineSnapshot(
            productId: productId,
            productName: productName,
            purchasePriceMinor: draftLine.purchasePriceMinor,
            salePriceMinor: draftLine.salePriceMinor,
            quantity: draftLine.quantity,
            lineTotalMinor: lineTotalMinor,
          ),
        );
      }

      for (final entry in weightedCosts.entries) {
        await (_database.update(
          _database.products,
        )..where((table) => table.id.equals(entry.key))).write(
          ProductsCompanion(
            averageCostMilliMinor: Value(entry.value.averageCostMilliMinor),
            averageCostReliable: Value(entry.value.isReliable),
          ),
        );
      }

      if (draft.amountPaidMinor > totalMinor) {
        throw ArgumentError('المبلغ المدفوع أكبر من إجمالي فاتورة الشراء.');
      }

      final purchaseId = await _database
          .into(_database.purchases)
          .insert(
            PurchasesCompanion.insert(
              supplierId: Value(supplierId),
              supplierNameSnapshot: supplierName,
              totalMinor: totalMinor,
              requestKey: requestKey,
              createdAt: occurredAtText,
            ),
          );
      final invoiceNumber = _invoiceNumber(occurredAt, purchaseId);
      await (_database.update(_database.purchases)
            ..where((table) => table.id.equals(purchaseId)))
          .write(PurchasesCompanion(invoiceNumber: Value(invoiceNumber)));

      for (final line in lines) {
        await _database
            .into(_database.purchaseLines)
            .insert(
              PurchaseLinesCompanion.insert(
                purchaseId: purchaseId,
                productId: Value(line.productId),
                productName: line.productName,
                purchasePriceMinor: line.purchasePriceMinor,
                salePriceMinor: line.salePriceMinor,
                quantity: line.quantity,
                lineTotalMinor: line.lineTotalMinor,
              ),
            );
        await _database
            .into(_database.stockMovements)
            .insert(
              StockMovementsCompanion.insert(
                productId: line.productId!,
                quantityDelta: line.quantity,
                sourceType: 'purchase',
                sourceId: Value('$purchaseId'),
                note: Value('فاتورة $invoiceNumber'),
                occurredAt: occurredAtText,
              ),
            );
      }

      for (final entry in legacyCostTransitions.entries) {
        await _database
            .into(_database.stockMovements)
            .insert(
              StockMovementsCompanion.insert(
                productId: entry.key,
                quantityDelta: 0,
                sourceType: 'cost_transition',
                sourceId: Value('$purchaseId'),
                note: Value(
                  _legacyCostTransitionNote(entry.value, invoiceNumber),
                ),
                occurredAt: occurredAtText,
              ),
            );
      }

      if (draft.amountPaidMinor > 0) {
        await _database
            .into(_database.purchasePayments)
            .insert(
              PurchasePaymentsCompanion.insert(
                purchaseId: purchaseId,
                amountMinor: draft.amountPaidMinor,
                requestKey: 'purchase:$requestKey:initial',
                occurredAt: occurredAtText,
              ),
            );
      }

      final receipt = await _loadReceipt(purchaseId);
      if (receipt == null) throw StateError('تعذر قراءة فاتورة الشراء.');
      return receipt;
    });
  }

  @override
  Future<PurchaseReceipt?> getPurchase(int purchaseId) =>
      _loadReceipt(purchaseId);

  @override
  Future<List<PurchaseReceipt>> getOpenPurchases() async {
    final rows = await _database.customSelect('''
          SELECT p.id
          FROM purchases AS p
          LEFT JOIN purchase_payments AS pay ON pay.purchase_id = p.id
          GROUP BY p.id
          HAVING p.total_minor - COALESCE(SUM(pay.amount_minor), 0) > 0
          ORDER BY p.created_at DESC, p.id DESC
          LIMIT 500
          ''').get();
    final receipts = <PurchaseReceipt>[];
    for (final row in rows) {
      final receipt = await _loadReceipt(row.read<int>('id'));
      if (receipt != null && receipt.remainingMinor > 0) {
        receipts.add(receipt);
      }
    }
    return receipts;
  }

  @override
  Future<int> getSupplierCount() async {
    final rows = await _database
        .customSelect(
          'SELECT COUNT(*) AS supplier_count FROM suppliers LIMIT 1',
        )
        .get();
    return rows.single.read<int>('supplier_count');
  }

  @override
  Future<PurchaseReceipt> addPayment({
    required int purchaseId,
    required int amountMinor,
    required String requestKey,
    DateTime? occurredAt,
  }) async {
    final normalizedRequestKey = requestKey.trim();
    if (amountMinor <= 0 || normalizedRequestKey.isEmpty) {
      throw ArgumentError('أدخل مبلغًا موجبًا ومفتاح عملية صحيحًا.');
    }

    return _database.transaction(() async {
      final previous =
          await (_database.select(_database.purchasePayments)
                ..where(
                  (table) => table.requestKey.equals(normalizedRequestKey),
                )
                ..limit(1))
              .get();
      if (previous.isNotEmpty) {
        if (previous.single.purchaseId != purchaseId) {
          throw StateError('مفتاح الدفعة مستخدم لفاتورة أخرى.');
        }
        final receipt = await _loadReceipt(purchaseId);
        if (receipt == null) throw StateError('فاتورة الشراء غير موجودة.');
        return receipt;
      }

      final receipt = await _loadReceipt(purchaseId);
      if (receipt == null) throw StateError('فاتورة الشراء غير موجودة.');
      if (amountMinor > receipt.remainingMinor) {
        throw StateError('المبلغ أكبر من المتبقي للمورد.');
      }

      await _database
          .into(_database.purchasePayments)
          .insert(
            PurchasePaymentsCompanion.insert(
              purchaseId: purchaseId,
              amountMinor: amountMinor,
              requestKey: normalizedRequestKey,
              occurredAt: (occurredAt ?? DateTime.now())
                  .toUtc()
                  .toIso8601String(),
            ),
          );
      final updated = await _loadReceipt(purchaseId);
      if (updated == null) throw StateError('فاتورة الشراء غير موجودة.');
      return updated;
    });
  }

  Future<PurchaseReceipt?> _loadReceipt(int purchaseId) async {
    final purchaseRows =
        await (_database.select(_database.purchases)
              ..where((table) => table.id.equals(purchaseId))
              ..limit(1))
            .get();
    if (purchaseRows.isEmpty) return null;
    final purchase = purchaseRows.single;
    final lineRows =
        await (_database.select(_database.purchaseLines)
              ..where((table) => table.purchaseId.equals(purchaseId))
              ..orderBy([(table) => OrderingTerm.asc(table.id)]))
            .get();
    final paymentRows =
        await (_database.select(_database.purchasePayments)
              ..where((table) => table.purchaseId.equals(purchaseId))
              ..orderBy([
                (table) => OrderingTerm.asc(table.occurredAt),
                (table) => OrderingTerm.asc(table.id),
              ]))
            .get();
    final paidMinor = paymentRows.fold<int>(
      0,
      (sum, payment) => sum + payment.amountMinor,
    );
    return PurchaseReceipt(
      id: purchase.id,
      invoiceNumber: purchase.invoiceNumber ?? 'P-${purchase.id}',
      supplierName: purchase.supplierNameSnapshot,
      totalMinor: purchase.totalMinor,
      paidMinor: paidMinor,
      createdAt: DateTime.parse(purchase.createdAt).toLocal(),
      payments: paymentRows
          .map(
            (payment) => PaymentSnapshot(
              amountMinor: payment.amountMinor,
              occurredAt: DateTime.parse(payment.occurredAt).toLocal(),
            ),
          )
          .toList(growable: false),
      lines: lineRows
          .map(
            (line) => PurchaseLineSnapshot(
              productId: line.productId,
              productName: line.productName,
              purchasePriceMinor: line.purchasePriceMinor,
              salePriceMinor: line.salePriceMinor,
              quantity: line.quantity,
              lineTotalMinor: line.lineTotalMinor,
            ),
          )
          .toList(growable: false),
    );
  }

  String _invoiceNumber(DateTime date, int id) {
    final local = date.toLocal();
    final datePart =
        '${local.year.toString().padLeft(4, '0')}'
        '${local.month.toString().padLeft(2, '0')}'
        '${local.day.toString().padLeft(2, '0')}';
    return 'P-$datePart-${id.toString().padLeft(6, '0')}';
  }

  String _normalizeName(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  Future<_WeightedCostState> _loadWeightedCost(int productId) async {
    final productRows =
        await (_database.select(_database.products)
              ..where((table) => table.id.equals(productId))
              ..limit(1))
            .get();
    if (productRows.isEmpty) throw StateError('المنتج غير موجود.');
    final stockRows = await _database
        .customSelect(
          '''
          SELECT CAST(COALESCE(quantity_on_hand, 0) AS REAL) AS stock_on_hand
          FROM product_stock_summary
          WHERE product_id = ?
          LIMIT 1
          ''',
          variables: [Variable.withInt(productId)],
        )
        .get();
    final stock = stockRows.single.read<double>('stock_on_hand');
    final stockMilli = stock * 1000;
    if (!stockMilli.isFinite ||
        (stockMilli - stockMilli.round()).abs() > 0.001) {
      throw StateError('كمية المخزون الحالية لا تقبل دقة ثلاث خانات عشرية.');
    }
    if (stockMilli < -0.001) {
      throw StateError('لا يمكن حساب متوسط التكلفة مع رصيد مخزون سالب.');
    }
    final row = productRows.single;
    return _WeightedCostState(
      quantityMilli: stockMilli.round(),
      averageCostMilliMinor: row.averageCostMilliMinor,
      isReliable: row.averageCostReliable,
    );
  }

  Map<int, int> _invoiceAverageCostByProduct(List<PurchaseLineDraft> lines) {
    final quantityByProduct = <int, int>{};
    final weightedCostByProduct = <int, int>{};
    for (final line in lines) {
      final productId = line.productId;
      if (productId == null) continue;
      final quantityMilli = (line.quantity * 1000).round();
      quantityByProduct.update(
        productId,
        (current) => current + quantityMilli,
        ifAbsent: () => quantityMilli,
      );
      weightedCostByProduct.update(
        productId,
        (current) => current + line.purchasePriceMinor * 1000 * quantityMilli,
        ifAbsent: () => line.purchasePriceMinor * 1000 * quantityMilli,
      );
    }

    return {
      for (final entry in weightedCostByProduct.entries)
        entry.key:
            (entry.value + quantityByProduct[entry.key]! ~/ 2) ~/
            quantityByProduct[entry.key]!,
    };
  }

  String _legacyCostTransitionNote(
    _LegacyCostTransition transition,
    String invoiceNumber,
  ) {
    final quantity = transition.legacyQuantityMilli / 1000;
    final quantityText = quantity
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'\.0+$'), '')
        .replaceFirst(RegExp(r'(\.\d*?)0+$'), r'$1');
    final cost = transition.transitionCostMilliMinor / 100000;
    return 'تقييم انتقالي للرصيد القديم: $quantityText وحدة بسعر '
        '${cost.toStringAsFixed(3)} ج.م للوحدة، وفق متوسط أسعار فاتورة '
        '$invoiceNumber. لم تتغير تكاليف المبيعات السابقة.';
  }

  Future<void> _ensurePurchaseIsNotBackdated(
    int productId,
    DateTime occurredAt,
  ) async {
    final rows = await _database
        .customSelect(
          '''
          SELECT occurred_at
          FROM stock_movements
          WHERE product_id = ?
          ORDER BY occurred_at DESC, id DESC
          LIMIT 1
          ''',
          variables: [Variable.withInt(productId)],
        )
        .get();
    if (rows.isEmpty) return;
    final latestMovement = DateTime.parse(
      rows.single.read<String>('occurred_at'),
    );
    if (occurredAt.isBefore(latestMovement)) {
      throw StateError(
        'تاريخ الشراء يسبق آخر حركة مخزون لهذا الصنف. '
        'إدخال فواتير شراء بأثر رجعي غير مدعوم حتى تُحدَّد طريقة إعادة احتساب التكلفة.',
      );
    }
  }
}

class _LegacyCostTransition {
  const _LegacyCostTransition({
    required this.legacyQuantityMilli,
    required this.transitionCostMilliMinor,
  });

  final int legacyQuantityMilli;
  final int transitionCostMilliMinor;
}

class _WeightedCostState {
  _WeightedCostState({
    required this.quantityMilli,
    required this.averageCostMilliMinor,
    required this.isReliable,
  });

  int quantityMilli;
  int averageCostMilliMinor;
  bool isReliable;

  void applyLegacyCostTransition(int costMilliMinor) {
    if (isReliable || quantityMilli <= 0) {
      throw StateError('لا يمكن تطبيق تقييم انتقالي على هذا الرصيد.');
    }
    averageCostMilliMinor = costMilliMinor;
    isReliable = true;
  }

  void addPurchase({
    required int purchasePriceMinor,
    required double quantity,
  }) {
    final purchaseQuantityMilli = (quantity * 1000).round();
    if (quantityMilli == 0) {
      averageCostMilliMinor = purchasePriceMinor * 1000;
      isReliable = true;
    } else {
      final combinedQuantityMilli = quantityMilli + purchaseQuantityMilli;
      final weightedTotal =
          averageCostMilliMinor * quantityMilli +
          purchasePriceMinor * 1000 * purchaseQuantityMilli;
      averageCostMilliMinor =
          (weightedTotal + combinedQuantityMilli ~/ 2) ~/ combinedQuantityMilli;
    }
    quantityMilli += purchaseQuantityMilli;
  }
}
