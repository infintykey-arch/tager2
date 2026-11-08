import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/data/local/app_database.dart';
import 'package:tager2/features/backup/data/database_backup_repository.dart';
import 'package:tager2/features/expenses/data/expenses_repository.dart';
import 'package:tager2/features/products/data/products_repository.dart';
import 'package:tager2/features/products/domain/product.dart';
import 'package:tager2/features/purchases/data/purchases_repository.dart';
import 'package:tager2/features/sales/data/sales_repository.dart';
import 'package:tager2/features/analytics/data/report_repository.dart';
import 'package:tager2/features/notes/data/notes_repository.dart';

void main() {
  late AppDatabase database;
  late DriftProductsRepository products;
  late DriftSalesRepository sales;
  late DriftPurchasesRepository purchases;
  late DriftExpensesRepository expenses;
  late DriftNotesRepository notes;
  late DatabaseBackupRepository backups;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    products = DriftProductsRepository(database);
    sales = DriftSalesRepository(database);
    purchases = DriftPurchasesRepository(database);
    expenses = DriftExpensesRepository(database);
    notes = DriftNotesRepository(database);
    backups = DatabaseBackupRepository(database);
  });

  tearDown(() => database.close());

  Future<void> addSampleData() async {
    await products.save(
      const Product(
        name: 'لبن',
        purchasePriceMinor: 800,
        salePriceMinor: 1250,
        minimumStock: 2,
        stockOnHand: 5,
      ),
    );
    final product = (await products.getProducts()).single;
    await sales.createSale(
      SaleDraft(
        lines: [SaleLineDraft(productId: product.id!, quantity: 1)],
        paymentKind: SalePaymentKind.credit,
        customerName: 'أحمد',
        amountPaidMinor: 500,
        requestKey: 'backup-sale-1',
      ),
    );
    await purchases.createPurchase(
      PurchaseDraft(
        supplierName: 'مورد النور',
        lines: [
          PurchaseLineDraft(
            productId: product.id,
            productName: 'لبن',
            purchasePriceMinor: 800,
            salePriceMinor: 1250,
            quantity: 2,
          ),
        ],
        amountPaidMinor: 300,
        requestKey: 'backup-purchase-1',
      ),
    );
    await expenses.createExpense(
      ExpenseDraft(
        category: 'نقل',
        location: 'السوق',
        amountMinor: 250,
        requestKey: 'backup-expense-1',
      ),
    );
    await notes.saveNote(title: 'مورد الأسبوع', content: 'اتصل بمورد الزيت.');
  }

  test(
    'ينشئ نسخة قابلة للاستعادة من المنتجات والفواتير والدفعات والمصروفات',
    () async {
      await addSampleData();
      final bytes = await backups.createBackupBytes();
      final summary = backups.inspectBackup(bytes);

      expect(summary.schemaVersion, database.schemaVersion);
      expect(summary.rowCounts['products'], 1);
      expect(summary.rowCounts['sales'], 1);
      expect(summary.rowCounts['saleLines'], 1);
      expect(summary.rowCounts['salePayments'], 1);
      expect(summary.rowCounts['purchases'], 1);
      expect(summary.rowCounts['purchaseLines'], 1);
      expect(summary.rowCounts['purchasePayments'], 1);
      expect(summary.rowCounts['expenses'], 1);
      expect(summary.rowCounts['notes'], 1);

      await products.save(
        const Product(
          name: 'منتج زائد',
          purchasePriceMinor: 0,
          salePriceMinor: 100,
          minimumStock: 0,
          stockOnHand: 0,
        ),
      );
      await expenses.createExpense(
        const ExpenseDraft(
          category: 'أخرى',
          amountMinor: 999,
          requestKey: 'after-backup',
        ),
      );

      await backups.restoreBackup(bytes);

      expect((await products.getProducts()).map((item) => item.name), ['لبن']);
      expect(await sales.getOpenCreditSales(), hasLength(1));
      expect(await purchases.getOpenPurchases(), hasLength(1));
      expect((await expenses.getRecent()).single.amountMinor, 250);
      expect((await expenses.getRecent()).single.location, 'السوق');
      expect((await notes.getNotes()).single.content, 'اتصل بمورد الزيت.');
      expect((await sales.getSale(1))!.lines.single.costTotalMinor, 800);
      expect(
        (await database.select(database.products).getSingle())
            .averageCostReliable,
        isTrue,
      );
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );

  test(
    'يستعيد نسخة الإصدار 5 القديمة دون اختلاق تكلفة لأسطر البيع السابقة',
    () async {
      await addSampleData();
      final bytes = await backups.createBackupBytes();
      final raw = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      raw['schemaVersion'] = 5;
      final tables = raw['tables'] as Map<String, dynamic>;
      final oldExpense = Map<String, dynamic>.from(
        (tables['expenses'] as List<dynamic>).single as Map,
      )..remove('location');
      tables['expenses'] = [oldExpense];
      final oldProduct =
          Map<String, dynamic>.from(
              (tables['products'] as List<dynamic>).single as Map,
            )
            ..remove('averageCostMilliMinor')
            ..remove('averageCostReliable');
      tables['products'] = [oldProduct];
      final oldSaleLine =
          Map<String, dynamic>.from(
              (tables['saleLines'] as List<dynamic>).single as Map,
            )
            ..remove('unitCostMilliMinor')
            ..remove('costTotalMinor');
      tables['saleLines'] = [oldSaleLine];

      await backups.restoreBackup(
        Uint8List.fromList(utf8.encode(jsonEncode(raw))),
      );

      expect((await expenses.getRecent()).single.location, isNull);
      expect(await notes.getNotes(), isEmpty);
      expect(
        (await database.select(database.products).getSingle())
            .averageCostReliable,
        isFalse,
      );
      expect((await sales.getSale(1))!.lines.single.costTotalMinor, isNull);
      final sale = (await sales.getSale(1))!;
      final report = await LocalReportRepository(database).getSummary(
        DateTime(sale.createdAt.year, sale.createdAt.month, sale.createdAt.day),
        DateTime(
          sale.createdAt.year,
          sale.createdAt.month,
          sale.createdAt.day + 1,
        ),
      );
      expect(report.netProfitMinor, isNull);
    },
  );

  test('نسخة غير صالحة لا تحذف البيانات الحالية', () async {
    await addSampleData();
    await expectLater(
      backups.restoreBackup(Uint8List.fromList(utf8.encode('{bad json'))),
      throwsA(isA<FormatException>()),
    );
    expect((await products.getProducts()).single.name, 'لبن');
    expect(await sales.getOpenCreditSales(), hasLength(1));
  });

  test(
    'فشل إدخال علاقة غير صالحة يعيد قاعدة البيانات كاملة كما كانت',
    () async {
      await addSampleData();
      final backupBytes = await backups.createBackupBytes();
      final raw = jsonDecode(utf8.decode(backupBytes)) as Map<String, dynamic>;
      final tables = raw['tables'] as Map<String, dynamic>;
      final saleLines = tables['saleLines'] as List<dynamic>;
      final firstLine = Map<String, dynamic>.from(saleLines.single as Map);
      firstLine['productId'] = 999999;
      tables['saleLines'] = [firstLine];
      final invalidBackup = Uint8List.fromList(utf8.encode(jsonEncode(raw)));

      await expectLater(
        backups.restoreBackup(invalidBackup),
        throwsA(anything),
      );
      expect((await products.getProducts()).single.name, 'لبن');
      expect(await sales.getOpenCreditSales(), hasLength(1));
      expect(await purchases.getOpenPurchases(), hasLength(1));
      expect((await expenses.getRecent()).single.amountMinor, 250);
    },
  );
}
