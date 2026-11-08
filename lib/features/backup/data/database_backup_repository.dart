import 'dart:convert';
import 'dart:typed_data';

import '../../../data/local/app_database.dart';

class BackupSummary {
  const BackupSummary({
    required this.createdAt,
    required this.schemaVersion,
    required this.rowCounts,
  });

  final DateTime createdAt;
  final int schemaVersion;
  final Map<String, int> rowCounts;

  int get totalRows => rowCounts.values.fold(0, (sum, count) => sum + count);
}

class DatabaseBackupRepository {
  DatabaseBackupRepository(this._database);

  static const formatName = 'tager2-local-backup';
  static const formatVersion = 1;
  static const maximumBackupBytes = 100 * 1024 * 1024;

  final AppDatabase _database;

  Future<Uint8List> createBackupBytes() async {
    final tables = <String, List<Map<String, dynamic>>>{
      'products': (await _database.select(_database.products).get())
          .map((row) => row.toJson())
          .toList(growable: false),
      'stockMovements': (await _database.select(_database.stockMovements).get())
          .map((row) => row.toJson())
          .toList(growable: false),
      'customers': (await _database.select(_database.customers).get())
          .map((row) => row.toJson())
          .toList(growable: false),
      'sales': (await _database.select(_database.sales).get())
          .map((row) => row.toJson())
          .toList(growable: false),
      'saleLines': (await _database.select(_database.saleLines).get())
          .map((row) => row.toJson())
          .toList(growable: false),
      'salePayments': (await _database.select(_database.salePayments).get())
          .map((row) => row.toJson())
          .toList(growable: false),
      'suppliers': (await _database.select(_database.suppliers).get())
          .map((row) => row.toJson())
          .toList(growable: false),
      'purchases': (await _database.select(_database.purchases).get())
          .map((row) => row.toJson())
          .toList(growable: false),
      'purchaseLines': (await _database.select(_database.purchaseLines).get())
          .map((row) => row.toJson())
          .toList(growable: false),
      'purchasePayments':
          (await _database.select(_database.purchasePayments).get())
              .map((row) => row.toJson())
              .toList(growable: false),
      'expenses': (await _database.select(_database.expenses).get())
          .map((row) => row.toJson())
          .toList(growable: false),
      'notes': (await _database.select(_database.notes).get())
          .map((row) => row.toJson())
          .toList(growable: false),
    };
    final json = <String, Object?>{
      'format': formatName,
      'formatVersion': formatVersion,
      'schemaVersion': _database.schemaVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'tables': tables,
    };
    final bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(json)),
    );
    if (bytes.length > maximumBackupBytes) {
      throw StateError('حجم النسخة أكبر من الحد المدعوم حاليًا.');
    }
    return bytes;
  }

  BackupSummary inspectBackup(Uint8List bytes) {
    final payload = _decodeBackup(bytes);
    return BackupSummary(
      createdAt: payload.createdAt,
      schemaVersion: payload.schemaVersion,
      rowCounts: Map.unmodifiable(payload.rowCounts),
    );
  }

  Future<void> restoreBackup(Uint8List bytes) async {
    final payload = _decodeBackup(bytes);
    await _database.transaction(() async {
      // حذف السجلات التابعة أولًا كي تبقى القيود المرجعية سليمة.
      await _database.delete(_database.salePayments).go();
      await _database.delete(_database.saleLines).go();
      await _database.delete(_database.sales).go();
      await _database.delete(_database.purchasePayments).go();
      await _database.delete(_database.purchaseLines).go();
      await _database.delete(_database.purchases).go();
      await _database.delete(_database.stockMovements).go();
      await _database.delete(_database.notes).go();
      await _database.delete(_database.expenses).go();
      await _database.delete(_database.customers).go();
      await _database.delete(_database.suppliers).go();
      await _database.delete(_database.products).go();

      await _database.batch((batch) {
        if (payload.products.isNotEmpty) {
          batch.insertAll(
            _database.products,
            payload.products.map((row) => row.toCompanion(false)).toList(),
          );
        }
        if (payload.customers.isNotEmpty) {
          batch.insertAll(
            _database.customers,
            payload.customers.map((row) => row.toCompanion(false)).toList(),
          );
        }
        if (payload.suppliers.isNotEmpty) {
          batch.insertAll(
            _database.suppliers,
            payload.suppliers.map((row) => row.toCompanion(false)).toList(),
          );
        }
        if (payload.sales.isNotEmpty) {
          batch.insertAll(
            _database.sales,
            payload.sales.map((row) => row.toCompanion(false)).toList(),
          );
        }
        if (payload.saleLines.isNotEmpty) {
          batch.insertAll(
            _database.saleLines,
            payload.saleLines.map((row) => row.toCompanion(false)).toList(),
          );
        }
        if (payload.salePayments.isNotEmpty) {
          batch.insertAll(
            _database.salePayments,
            payload.salePayments.map((row) => row.toCompanion(false)).toList(),
          );
        }
        if (payload.purchases.isNotEmpty) {
          batch.insertAll(
            _database.purchases,
            payload.purchases.map((row) => row.toCompanion(false)).toList(),
          );
        }
        if (payload.purchaseLines.isNotEmpty) {
          batch.insertAll(
            _database.purchaseLines,
            payload.purchaseLines.map((row) => row.toCompanion(false)).toList(),
          );
        }
        if (payload.purchasePayments.isNotEmpty) {
          batch.insertAll(
            _database.purchasePayments,
            payload.purchasePayments
                .map((row) => row.toCompanion(false))
                .toList(),
          );
        }
        if (payload.stockMovements.isNotEmpty) {
          batch.insertAll(
            _database.stockMovements,
            payload.stockMovements
                .map((row) => row.toCompanion(false))
                .toList(),
          );
        }
        if (payload.expenses.isNotEmpty) {
          batch.insertAll(
            _database.expenses,
            payload.expenses.map((row) => row.toCompanion(false)).toList(),
          );
        }
        if (payload.notes.isNotEmpty) {
          batch.insertAll(
            _database.notes,
            payload.notes.map((row) => row.toCompanion(false)).toList(),
          );
        }
      });

      await _database.rebuildProductSalesSummary();
      await _database.rebuildProductStockSummary();
      await _database.rebuildProductSearchGrams(withinTransaction: true);

      final violations = await _database
          .customSelect('PRAGMA foreign_key_check')
          .get();
      if (violations.isNotEmpty) {
        throw FormatException('تحتوي النسخة على علاقات بيانات غير سليمة.');
      }
    });
  }

  _BackupPayload _decodeBackup(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maximumBackupBytes) {
      throw FormatException('حجم ملف النسخة غير صالح.');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw FormatException('الملف ليس نسخة JSON صالحة.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('هيكل ملف النسخة غير صالح.');
    }
    if (decoded['format'] != formatName ||
        decoded['formatVersion'] != formatVersion) {
      throw FormatException('صيغة النسخة غير مدعومة.');
    }

    final schemaVersion = decoded['schemaVersion'];
    if (schemaVersion is! int ||
        schemaVersion < 4 ||
        schemaVersion > _database.schemaVersion) {
      throw FormatException('إصدار بيانات النسخة غير مدعوم في هذا التطبيق.');
    }
    final createdAtValue = decoded['createdAt'];
    if (createdAtValue is! String) {
      throw FormatException('تاريخ النسخة غير موجود أو غير صالح.');
    }
    final createdAt = DateTime.tryParse(createdAtValue);
    if (createdAt == null) {
      throw FormatException('تاريخ النسخة غير صالح.');
    }
    final rawTables = decoded['tables'];
    if (rawTables is! Map<String, dynamic>) {
      throw FormatException('جداول النسخة غير موجودة.');
    }

    List<Map<String, dynamic>> rawRows(String name, {bool optional = false}) {
      final value = rawTables[name];
      if (value == null && optional) return const [];
      if (value is! List || value.length > 100000) {
        throw FormatException('قائمة $name في النسخة غير صالحة.');
      }
      return value
          .map((row) {
            if (row is! Map) {
              throw FormatException('يوجد سجل غير صالح في $name.');
            }
            return Map<String, dynamic>.from(row);
          })
          .toList(growable: false);
    }

    List<T> rows<T>(
      String name,
      T Function(Map<String, dynamic>) decode, {
      bool optional = false,
    }) {
      try {
        return rawRows(
          name,
          optional: optional,
        ).map(decode).toList(growable: false);
      } on FormatException {
        rethrow;
      } catch (_) {
        throw FormatException('تعذر قراءة سجل من جدول $name.');
      }
    }

    final products = rawRows('products')
        .map((row) {
          if (schemaVersion < 7) {
            row['averageCostMilliMinor'] =
                ((row['purchasePriceMinor'] as num?)?.toInt() ?? 0) * 1000;
            row['averageCostReliable'] = false;
          }
          return ProductRow.fromJson(row);
        })
        .toList(growable: false);
    final stockMovements = rows('stockMovements', StockMovementRow.fromJson);
    final customers = rows('customers', CustomerRow.fromJson);
    final sales = rows('sales', SaleRow.fromJson);
    final saleLines = rawRows('saleLines')
        .map((row) {
          if (schemaVersion < 7) {
            row['unitCostMilliMinor'] = null;
            row['costTotalMinor'] = null;
          }
          return SaleLineRow.fromJson(row);
        })
        .toList(growable: false);
    final salePayments = rows('salePayments', SalePaymentRow.fromJson);
    final suppliers = rows('suppliers', SupplierRow.fromJson);
    final purchases = rows('purchases', PurchaseRow.fromJson);
    final purchaseLines = rows('purchaseLines', PurchaseLineRow.fromJson);
    final purchasePayments = rows(
      'purchasePayments',
      PurchasePaymentRow.fromJson,
    );
    final expenses = rows(
      'expenses',
      ExpenseRow.fromJson,
      optional: schemaVersion == 4,
    );
    final notes = schemaVersion < 8
        ? const <NoteRow>[]
        : rows('notes', NoteRow.fromJson);

    return _BackupPayload(
      schemaVersion: schemaVersion,
      createdAt: createdAt,
      products: products,
      stockMovements: stockMovements,
      customers: customers,
      sales: sales,
      saleLines: saleLines,
      salePayments: salePayments,
      suppliers: suppliers,
      purchases: purchases,
      purchaseLines: purchaseLines,
      purchasePayments: purchasePayments,
      expenses: expenses,
      notes: notes,
    );
  }
}

class _BackupPayload {
  const _BackupPayload({
    required this.schemaVersion,
    required this.createdAt,
    required this.products,
    required this.stockMovements,
    required this.customers,
    required this.sales,
    required this.saleLines,
    required this.salePayments,
    required this.suppliers,
    required this.purchases,
    required this.purchaseLines,
    required this.purchasePayments,
    required this.expenses,
    required this.notes,
  });

  final int schemaVersion;
  final DateTime createdAt;
  final List<ProductRow> products;
  final List<StockMovementRow> stockMovements;
  final List<CustomerRow> customers;
  final List<SaleRow> sales;
  final List<SaleLineRow> saleLines;
  final List<SalePaymentRow> salePayments;
  final List<SupplierRow> suppliers;
  final List<PurchaseRow> purchases;
  final List<PurchaseLineRow> purchaseLines;
  final List<PurchasePaymentRow> purchasePayments;
  final List<ExpenseRow> expenses;
  final List<NoteRow> notes;

  Map<String, int> get rowCounts => {
    'products': products.length,
    'stockMovements': stockMovements.length,
    'customers': customers.length,
    'sales': sales.length,
    'saleLines': saleLines.length,
    'salePayments': salePayments.length,
    'suppliers': suppliers.length,
    'purchases': purchases.length,
    'purchaseLines': purchaseLines.length,
    'purchasePayments': purchasePayments.length,
    'expenses': expenses.length,
    'notes': notes.length,
  };
}
