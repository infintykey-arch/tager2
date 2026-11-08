import 'package:drift/drift.dart';

import '../../../core/payment_snapshot.dart';
import '../../../data/local/app_database.dart';

enum SalePaymentKind { cash, credit }

class SaleLineDraft {
  const SaleLineDraft({required this.productId, required this.quantity});

  final int productId;
  final double quantity;
}

class SaleDraft {
  const SaleDraft({
    required this.lines,
    required this.paymentKind,
    required this.requestKey,
    this.customerName,
    this.amountPaidMinor = 0,
    this.occurredAt,
  });

  final List<SaleLineDraft> lines;
  final SalePaymentKind paymentKind;
  final String requestKey;
  final String? customerName;
  final int amountPaidMinor;
  final DateTime? occurredAt;
}

class SaleLineSnapshot {
  const SaleLineSnapshot({
    required this.productId,
    required this.productName,
    required this.unitPriceMinor,
    required this.quantity,
    required this.lineTotalMinor,
    this.unitCostMilliMinor,
    this.costTotalMinor,
  });

  final int? productId;
  final String productName;
  final int unitPriceMinor;
  final double quantity;
  final int lineTotalMinor;
  final int? unitCostMilliMinor;
  final int? costTotalMinor;
}

class SaleReceipt {
  const SaleReceipt({
    required this.id,
    required this.invoiceNumber,
    required this.paymentKind,
    required this.customerName,
    required this.totalMinor,
    required this.paidMinor,
    required this.createdAt,
    required this.lines,
    this.payments = const [],
  });

  final int id;
  final String invoiceNumber;
  final SalePaymentKind paymentKind;
  final String? customerName;
  final int totalMinor;
  final int paidMinor;
  final DateTime createdAt;
  final List<SaleLineSnapshot> lines;
  final List<PaymentSnapshot> payments;

  int get remainingMinor => totalMinor - paidMinor;
}

abstract interface class SalesRepository {
  Future<SaleReceipt> createSale(SaleDraft draft);

  Future<SaleReceipt?> getSale(int saleId);

  Future<List<SaleReceipt>> getOpenCreditSales();

  Future<SaleReceipt> addPayment({
    required int saleId,
    required int amountMinor,
    required String requestKey,
    DateTime? occurredAt,
  });
}

class DriftSalesRepository implements SalesRepository {
  DriftSalesRepository(this._database);

  final AppDatabase _database;

  @override
  Future<SaleReceipt> createSale(SaleDraft draft) async {
    final requestKey = draft.requestKey.trim();
    if (requestKey.isEmpty) {
      throw ArgumentError('مفتاح العملية مطلوب لمنع تكرار الفاتورة.');
    }
    if (draft.lines.isEmpty) {
      throw ArgumentError('أضف صنفًا واحدًا على الأقل إلى الفاتورة.');
    }

    final quantities = <int, double>{};
    for (final line in draft.lines) {
      if (line.productId <= 0 ||
          !line.quantity.isFinite ||
          line.quantity <= 0) {
        throw ArgumentError('الكمية أو رقم الصنف غير صالح.');
      }
      final thousandths = line.quantity * 1000;
      if ((thousandths - thousandths.round()).abs() > 0.000001) {
        throw ArgumentError('الكمية تقبل حتى ثلاث خانات عشرية فقط.');
      }
      quantities.update(
        line.productId,
        (current) => current + line.quantity,
        ifAbsent: () => line.quantity,
      );
    }

    final customerName = draft.customerName?.trim();
    if (draft.paymentKind == SalePaymentKind.credit &&
        (customerName == null || customerName.isEmpty)) {
      throw ArgumentError('اسم العميل مطلوب للبيع الآجل.');
    }
    if (draft.amountPaidMinor < 0) {
      throw ArgumentError('المبلغ المدفوع لا يمكن أن يكون سالبًا.');
    }

    final occurredAt = (draft.occurredAt ?? DateTime.now()).toUtc();
    final occurredAtText = occurredAt.toIso8601String();

    return _database.transaction(() async {
      final existing =
          await (_database.select(_database.sales)
                ..where((table) => table.requestKey.equals(requestKey))
                ..limit(1))
              .get();
      if (existing.isNotEmpty) {
        final receipt = await _loadReceipt(existing.single.id);
        if (receipt == null) {
          throw StateError('تعذر استعادة الفاتورة المسجلة.');
        }
        return receipt;
      }

      final lines = <SaleLineSnapshot>[];
      var totalMinor = 0;
      for (final entry in quantities.entries) {
        final rows = await _database
            .customSelect(
              '''
              SELECT
                p.id,
                p.name,
                p.sale_price_minor,
                p.average_cost_milli_minor,
                p.average_cost_reliable,
                p.is_archived,
                CAST(COALESCE(stock_summary.quantity_on_hand, 0) AS REAL)
                  AS available
              FROM products AS p
              LEFT JOIN product_stock_summary AS stock_summary
                ON stock_summary.product_id = p.id
              WHERE p.id = ?
              LIMIT 1
              ''',
              variables: [Variable.withInt(entry.key)],
            )
            .get();
        if (rows.isEmpty) {
          throw StateError('أحد الأصناف لم يعد موجودًا. أعد مراجعة الفاتورة.');
        }

        final row = rows.single;
        if (row.read<int>('is_archived') != 0) {
          throw StateError('الصنف «${row.read<String>('name')}» محذوف.');
        }
        final name = row.read<String>('name');
        final available = row.read<double>('available');
        if (entry.value > available + 0.0000001) {
          throw StateError(
            'المتاح من «$name» هو ${_formatQuantity(available)} فقط.',
          );
        }

        final unitPriceMinor = row.read<int>('sale_price_minor');
        final lineTotalMinor = (unitPriceMinor * entry.value).round();
        final costReliable = row.read<int>('average_cost_reliable') != 0;
        final unitCostMilliMinor = costReliable
            ? row.read<int>('average_cost_milli_minor')
            : null;
        final costTotalMinor = unitCostMilliMinor == null
            ? null
            : _costTotalMinor(unitCostMilliMinor, entry.value);
        totalMinor += lineTotalMinor;
        lines.add(
          SaleLineSnapshot(
            productId: entry.key,
            productName: name,
            unitPriceMinor: unitPriceMinor,
            quantity: entry.value,
            lineTotalMinor: lineTotalMinor,
            unitCostMilliMinor: unitCostMilliMinor,
            costTotalMinor: costTotalMinor,
          ),
        );
      }

      final paidMinor = draft.paymentKind == SalePaymentKind.cash
          ? totalMinor
          : draft.amountPaidMinor;
      if (paidMinor > totalMinor) {
        throw ArgumentError('المبلغ المدفوع أكبر من إجمالي الفاتورة.');
      }

      int? customerId;
      if (draft.paymentKind == SalePaymentKind.credit) {
        final normalizedName = _normalizeCustomerName(customerName!);
        final customers =
            await (_database.select(_database.customers)
                  ..where(
                    (table) => table.normalizedName.equals(normalizedName),
                  )
                  ..limit(1))
                .get();
        if (customers.isNotEmpty) {
          customerId = customers.single.id;
        } else {
          customerId = await _database
              .into(_database.customers)
              .insert(
                CustomersCompanion.insert(
                  name: customerName,
                  normalizedName: normalizedName,
                  createdAt: occurredAtText,
                  updatedAt: occurredAtText,
                ),
              );
        }
      }

      final saleId = await _database
          .into(_database.sales)
          .insert(
            SalesCompanion.insert(
              customerId: Value(customerId),
              customerNameSnapshot: Value(
                customerName == null || customerName.isEmpty
                    ? null
                    : customerName,
              ),
              paymentType: draft.paymentKind.name,
              totalMinor: totalMinor,
              requestKey: requestKey,
              createdAt: occurredAtText,
            ),
          );
      final invoiceNumber = _invoiceNumber(occurredAt, saleId);
      await (_database.update(_database.sales)
            ..where((table) => table.id.equals(saleId)))
          .write(SalesCompanion(invoiceNumber: Value(invoiceNumber)));

      for (final line in lines) {
        await _database
            .into(_database.saleLines)
            .insert(
              SaleLinesCompanion.insert(
                saleId: saleId,
                productId: Value(line.productId!),
                productName: line.productName,
                unitPriceMinor: line.unitPriceMinor,
                quantity: line.quantity,
                lineTotalMinor: line.lineTotalMinor,
                unitCostMilliMinor: Value(line.unitCostMilliMinor),
                costTotalMinor: Value(line.costTotalMinor),
              ),
            );
        await _database
            .into(_database.stockMovements)
            .insert(
              StockMovementsCompanion.insert(
                productId: line.productId!,
                quantityDelta: -line.quantity,
                sourceType: 'sale',
                sourceId: Value('$saleId'),
                note: Value('فاتورة $invoiceNumber'),
                occurredAt: occurredAtText,
              ),
            );
      }

      if (paidMinor > 0) {
        await _database
            .into(_database.salePayments)
            .insert(
              SalePaymentsCompanion.insert(
                saleId: saleId,
                amountMinor: paidMinor,
                requestKey: 'sale:$requestKey:initial',
                occurredAt: occurredAtText,
              ),
            );
      }

      final receipt = await _loadReceipt(saleId);
      if (receipt == null) {
        throw StateError('تعذر قراءة الفاتورة بعد حفظها.');
      }
      return receipt;
    });
  }

  @override
  Future<SaleReceipt?> getSale(int saleId) => _loadReceipt(saleId);

  @override
  Future<List<SaleReceipt>> getOpenCreditSales() async {
    final rows = await _database.customSelect('''
          SELECT s.id
          FROM sales AS s
          LEFT JOIN sale_payments AS p ON p.sale_id = s.id
          WHERE s.payment_type = 'credit'
          GROUP BY s.id
          HAVING s.total_minor - COALESCE(SUM(p.amount_minor), 0) > 0
          ORDER BY s.created_at DESC, s.id DESC
          LIMIT 500
          ''').get();
    final receipts = <SaleReceipt>[];
    for (final row in rows) {
      final receipt = await _loadReceipt(row.read<int>('id'));
      if (receipt != null && receipt.remainingMinor > 0) {
        receipts.add(receipt);
      }
    }
    return receipts;
  }

  @override
  Future<SaleReceipt> addPayment({
    required int saleId,
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
          await (_database.select(_database.salePayments)
                ..where(
                  (table) => table.requestKey.equals(normalizedRequestKey),
                )
                ..limit(1))
              .get();
      if (previous.isNotEmpty) {
        if (previous.single.saleId != saleId) {
          throw StateError('مفتاح الدفعة مستخدم لفاتورة أخرى.');
        }
        final receipt = await _loadReceipt(saleId);
        if (receipt == null) throw StateError('الفاتورة غير موجودة.');
        return receipt;
      }

      final receipt = await _loadReceipt(saleId);
      if (receipt == null) throw StateError('الفاتورة غير موجودة.');
      if (amountMinor > receipt.remainingMinor) {
        throw StateError('المبلغ أكبر من المتبقي على الفاتورة.');
      }

      await _database
          .into(_database.salePayments)
          .insert(
            SalePaymentsCompanion.insert(
              saleId: saleId,
              amountMinor: amountMinor,
              requestKey: normalizedRequestKey,
              occurredAt: (occurredAt ?? DateTime.now())
                  .toUtc()
                  .toIso8601String(),
            ),
          );

      final updatedReceipt = await _loadReceipt(saleId);
      if (updatedReceipt == null) throw StateError('الفاتورة غير موجودة.');
      return updatedReceipt;
    });
  }

  Future<SaleReceipt?> _loadReceipt(int saleId) async {
    final saleRows =
        await (_database.select(_database.sales)
              ..where((table) => table.id.equals(saleId))
              ..limit(1))
            .get();
    if (saleRows.isEmpty) return null;
    final sale = saleRows.single;

    final lineRows =
        await (_database.select(_database.saleLines)
              ..where((table) => table.saleId.equals(saleId))
              ..orderBy([(table) => OrderingTerm.asc(table.id)]))
            .get();
    final paymentRows =
        await (_database.select(_database.salePayments)
              ..where((table) => table.saleId.equals(saleId))
              ..orderBy([
                (table) => OrderingTerm.asc(table.occurredAt),
                (table) => OrderingTerm.asc(table.id),
              ]))
            .get();
    final paidMinor = paymentRows.fold<int>(
      0,
      (sum, payment) => sum + payment.amountMinor,
    );
    final lines = lineRows
        .map(
          (line) => SaleLineSnapshot(
            productId: line.productId,
            productName: line.productName,
            unitPriceMinor: line.unitPriceMinor,
            quantity: line.quantity,
            lineTotalMinor: line.lineTotalMinor,
            unitCostMilliMinor: line.unitCostMilliMinor,
            costTotalMinor: line.costTotalMinor,
          ),
        )
        .toList(growable: false);
    final paymentKind = switch (sale.paymentType) {
      'credit' => SalePaymentKind.credit,
      _ => SalePaymentKind.cash,
    };
    return SaleReceipt(
      id: sale.id,
      invoiceNumber: sale.invoiceNumber ?? 'S-${sale.id}',
      paymentKind: paymentKind,
      customerName: sale.customerNameSnapshot,
      totalMinor: sale.totalMinor,
      paidMinor: paidMinor,
      createdAt: DateTime.parse(sale.createdAt).toLocal(),
      lines: lines,
      payments: paymentRows
          .map(
            (payment) => PaymentSnapshot(
              amountMinor: payment.amountMinor,
              occurredAt: DateTime.parse(payment.occurredAt).toLocal(),
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
    return 'S-$datePart-${id.toString().padLeft(6, '0')}';
  }

  String _normalizeCustomerName(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  int _costTotalMinor(int unitCostMilliMinor, double quantity) {
    final quantityMilli = (quantity * 1000).round();
    return (unitCostMilliMinor * quantityMilli + 500000) ~/ 1000000;
  }

  String _formatQuantity(double value) {
    final fixed = value.toStringAsFixed(3);
    return fixed
        .replaceFirst(RegExp(r'\.0+$'), '')
        .replaceFirst(RegExp(r'(\.\d*?)0+$'), r'$1');
  }
}
