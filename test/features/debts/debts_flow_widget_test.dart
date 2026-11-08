import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/app/tager_app.dart';
import 'package:tager2/data/local/app_database.dart';
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
  testWidgets('عرض ديون العملاء والموردين وإغلاقها بدفعة', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final products = DriftProductsRepository(database);
    final sales = DriftSalesRepository(database);
    final purchases = DriftPurchasesRepository(database);
    final expenses = DriftExpensesRepository(database);
    final backup = DatabaseBackupRepository(database);
    final reports = LocalReportRepository(database);
    await products.save(
      const Product(
        name: 'لبن',
        purchasePriceMinor: 800,
        salePriceMinor: 1250,
        minimumStock: 2,
        stockOnHand: 5,
      ),
    );
    final productId = (await products.getProducts()).single.id!;
    await sales.createSale(
      SaleDraft(
        lines: [SaleLineDraft(productId: productId, quantity: 2)],
        paymentKind: SalePaymentKind.credit,
        customerName: 'أحمد علي',
        amountPaidMinor: 500,
        requestKey: 'debt-widget-sale',
      ),
    );
    await purchases.createPurchase(
      PurchaseDraft(
        supplierName: 'مورد الألبان',
        lines: [
          PurchaseLineDraft(
            productId: productId,
            productName: 'لبن',
            purchasePriceMinor: 800,
            salePriceMinor: 1250,
            quantity: 1,
          ),
        ],
        amountPaidMinor: 300,
        requestKey: 'debt-widget-purchase',
      ),
    );

    await tester.pumpWidget(
      TagerApp(
        productsRepository: products,
        salesRepository: sales,
        purchasesRepository: purchases,
        expensesRepository: expenses,
        backupRepository: backup,
        reportRepository: reports,
        notesRepository: DriftNotesRepository(database),
        settingsRepository: DriftAppSettingsRepository(database),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('فتح القائمة'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'ديون العملاء'));
    await tester.pumpAndSettle();
    expect(find.text('أحمد علي'), findsOneWidget);
    expect(find.textContaining('المتبقي 20.00 ج.م'), findsOneWidget);
    expect(find.text('عدد العملاء المدينين'), findsOneWidget);
    final invoiceNumber =
        (await sales.getOpenCreditSales()).single.invoiceNumber;
    await tester.tap(find.text(invoiceNumber));
    await tester.pumpAndSettle();
    expect(find.text('سجل الدفعات'), findsOneWidget);
    expect(find.text('لبن'), findsOneWidget);
    expect(find.textContaining('5.00 ج.م'), findsWidgets);
    await tester.tap(find.byTooltip('إغلاق تفاصيل الفاتورة'));
    await tester.pumpAndSettle();
    final debtSearch = find.byType(TextField).first;
    await tester.enterText(debtSearch, 'غير موجود');
    await tester.pumpAndSettle();
    expect(find.text('لا توجد نتائج مطابقة للبحث.'), findsOneWidget);
    await tester.enterText(debtSearch, 'أحمد');
    await tester.pumpAndSettle();
    expect(find.text('أحمد علي'), findsOneWidget);
    await tester.tap(find.text('تسجيل دفعة'));
    await tester.pumpAndSettle();
    final customerPaymentField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(customerPaymentField, '20');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(customerPaymentField).controller!.text,
      '20',
    );
    final saveCustomerPayment = find.ancestor(
      of: find.text('حفظ الدفعة'),
      matching: find.byType(FilledButton),
    );
    expect(
      tester.widget<FilledButton>(saveCustomerPayment).onPressed,
      isNotNull,
    );
    await tester.tap(find.text('حفظ الدفعة'));
    await tester.pumpAndSettle();
    expect((await sales.getSale(1))!.paidMinor, 2500);
    expect(await sales.getOpenCreditSales(), isEmpty);
    expect(find.text('لا توجد ديون عملاء مفتوحة'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('فتح القائمة'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'ديون الموردين'));
    await tester.pumpAndSettle();
    expect(find.text('مورد الألبان'), findsOneWidget);
    expect(find.text('عدد الموردين'), findsOneWidget);
    await tester.tap(find.text('تسجيل دفعة'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '5',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ الدفعة'));
    await tester.pumpAndSettle();
    expect((await purchases.getPurchase(1))!.paidMinor, 800);
    expect(await purchases.getOpenPurchases(), isEmpty);
    expect(find.text('لا توجد مبالغ مستحقة للموردين'), findsOneWidget);

    await database.close();
  });
}
