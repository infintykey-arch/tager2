import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/app/tager_app.dart';
import 'package:tager2/features/products/data/products_repository.dart';
import 'package:tager2/features/products/domain/product.dart';
import 'package:tager2/features/sales/data/sales_repository.dart';
import 'package:tager2/features/purchases/data/purchases_repository.dart';
import 'package:tager2/features/expenses/data/expenses_repository.dart';
import 'package:tager2/features/backup/data/database_backup_repository.dart';
import 'package:tager2/features/analytics/data/report_repository.dart';
import 'package:tager2/features/notes/data/notes_repository.dart';
import 'package:tager2/features/settings/data/app_settings_repository.dart';

void main() {
  testWidgets('يعرض واجهة عربية باتجاه RTL وحالة البداية الفارغة', (
    tester,
  ) async {
    await tester.pumpWidget(
      const TagerApp(
        productsRepository: _EmptyProductsRepository(),
        salesRepository: _EmptySalesRepository(),
        purchasesRepository: _EmptyPurchasesRepository(),
        expensesRepository: _EmptyExpensesRepository(),
        backupRepository: _EmptyBackupRepository(),
        reportRepository: _EmptyReportRepository(),
        notesRepository: _EmptyNotesRepository(),
        settingsRepository: _EmptyAppSettingsRepository(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byKey(const ValueKey('tager-app-brand-logo')), findsOneWidget);
    expect(find.text('كل الأصناف'), findsOneWidget);
    expect(find.text('إضافة منتج جديد'), findsAtLeastNWidgets(1));
    expect(
      Directionality.of(tester.element(find.text('كل الأصناف'))),
      TextDirection.rtl,
    );

    await tester.tap(find.byTooltip('فتح القائمة'));
    await tester.pumpAndSettle();
    final drawer = find.byType(Drawer);
    expect(
      find.descendant(of: drawer, matching: find.text('تاجر')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: drawer,
        matching: find.byKey(const ValueKey('tager-drawer-brand-logo')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: drawer, matching: find.text('تاجر ٢')),
      findsNothing,
    );
    await tester.tap(find.widgetWithText(ListTile, 'الرئيسية'));
    await tester.pumpAndSettle();

    final missingAction = find.text('الأصناف الناقصة');
    expect(missingAction, findsOneWidget);
    await tester.tap(missingAction);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('لا توجد أصناف ناقصة'), findsOneWidget);

    await tester.tap(find.byTooltip('فتح القائمة'));
    await tester.pumpAndSettle();
    final drawerScrollable = find.descendant(
      of: find.byType(Drawer),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('التحليل'),
      250,
      scrollable: drawerScrollable,
    );
    await tester.tap(find.widgetWithText(ListTile, 'التحليل'));
    await tester.pumpAndSettle();
    expect(find.text('نظرة على النشاط'), findsOneWidget);
  });
}

class _EmptyNotesRepository implements NotesRepository {
  const _EmptyNotesRepository();

  @override
  Future<List<Note>> getNotes() async => const [];

  @override
  Future<Note> saveNote({
    int? id,
    required String title,
    required String content,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteNote(int id) async {}
}

class _EmptyReportRepository implements ReportRepository {
  const _EmptyReportRepository();

  @override
  Future<ReportSummary> getSummary(DateTime start, DateTime end) async =>
      const ReportSummary(
        sales: ReportMetric(totalMinor: 0, invoiceCount: 0),
        purchases: ReportMetric(totalMinor: 0, invoiceCount: 0),
        expenses: ReportMetric(totalMinor: 0, invoiceCount: 0),
      );

  @override
  Future<List<ReportInvoice>> getInvoices(
    DateTime start,
    DateTime end, {
    int limit = 500,
  }) async => const [];
}

class _EmptyProductsRepository implements ProductsRepository {
  const _EmptyProductsRepository();

  @override
  Future<List<Product>> getProducts({
    String search = '',
    ProductListFilter filter = ProductListFilter.available,
  }) async => const [];

  @override
  Future<ProductCodeMatch?> findProductByCode(String code) async => null;

  @override
  Future<List<Product>> findUncodedActiveProducts({String search = ''}) async =>
      const [];

  @override
  Future<void> assignCode(
    int productId,
    String code, {
    required String codeType,
  }) async {}

  @override
  Future<void> save(Product product) async {}

  @override
  Future<void> adjustStock(
    int productId,
    double quantityDelta, {
    required String note,
  }) async {}

  @override
  Future<void> archive(int productId) async {}

  @override
  Future<void> restore(int productId) async {}

  @override
  Future<void> deletePermanently(int productId) async {}

  @override
  Future<List<StockMovement>> getMovements(int productId) async => const [];
}

class _EmptySalesRepository implements SalesRepository {
  const _EmptySalesRepository();

  @override
  Future<SaleReceipt> createSale(SaleDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<SaleReceipt?> getSale(int saleId) async => null;

  @override
  Future<List<SaleReceipt>> getOpenCreditSales() async => const [];

  @override
  Future<SaleReceipt> addPayment({
    required int saleId,
    required int amountMinor,
    required String requestKey,
    DateTime? occurredAt,
  }) async => throw UnimplementedError();
}

class _EmptyPurchasesRepository implements PurchasesRepository {
  const _EmptyPurchasesRepository();

  @override
  Future<PurchaseReceipt> createPurchase(PurchaseDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<PurchaseReceipt?> getPurchase(int purchaseId) async => null;

  @override
  Future<List<PurchaseReceipt>> getOpenPurchases() async => const [];

  @override
  Future<int> getSupplierCount() async => 0;

  @override
  Future<PurchaseReceipt> addPayment({
    required int purchaseId,
    required int amountMinor,
    required String requestKey,
    DateTime? occurredAt,
  }) async => throw UnimplementedError();
}

class _EmptyExpensesRepository implements ExpensesRepository {
  const _EmptyExpensesRepository();

  @override
  Future<ExpenseEntry> createExpense(ExpenseDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<List<ExpenseEntry>> getRecent({int limit = 200}) async => const [];

  @override
  Future<List<ExpenseEntry>> getBetween(
    DateTime start,
    DateTime end, {
    int limit = 1000,
  }) async => const [];

  @override
  Future<int> getTotalBetween(DateTime start, DateTime end) async => 0;
}

class _EmptyBackupRepository implements DatabaseBackupRepository {
  const _EmptyBackupRepository();

  @override
  Future<Uint8List> createBackupBytes() async => Uint8List(0);

  @override
  BackupSummary inspectBackup(Uint8List bytes) => BackupSummary(
    createdAt: DateTime.utc(2026),
    schemaVersion: 6,
    rowCounts: const {},
  );

  @override
  Future<void> restoreBackup(Uint8List bytes) async {}
}

class _EmptyAppSettingsRepository implements AppSettingsRepository {
  const _EmptyAppSettingsRepository();

  @override
  Future<bool> loadDarkTheme() async => false;

  @override
  Future<void> saveDarkTheme(bool enabled) async {}
}
