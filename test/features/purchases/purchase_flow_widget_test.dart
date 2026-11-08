import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/app/tager_app.dart';
import 'package:tager2/data/local/app_database.dart';
import 'package:tager2/features/analytics/data/report_repository.dart';
import 'package:tager2/features/backup/data/database_backup_repository.dart';
import 'package:tager2/features/expenses/data/expenses_repository.dart';
import 'package:tager2/features/notes/data/notes_repository.dart';
import 'package:tager2/features/products/data/products_repository.dart';
import 'package:tager2/features/products/domain/product.dart';
import 'package:tager2/features/purchases/data/purchases_repository.dart';
import 'package:tager2/features/purchases/presentation/invoice_import_review_sheet.dart';
import 'package:tager2/features/purchases/presentation/purchase_invoice_sheet.dart';
import 'package:tager2/features/sales/data/sales_repository.dart';

void main() {
  testWidgets(
    'يراجع البيانات المستخرجة ويحفظ فاتورة الشراء ويظهر الصنف على الهاتف والتابلت',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final products = DriftProductsRepository(database);
      final sales = DriftSalesRepository(database);
      final purchases = DriftPurchasesRepository(database);
      final expenses = DriftExpensesRepository(database);
      final backup = DatabaseBackupRepository(database);
      final reports = LocalReportRepository(database);
      final notes = DriftNotesRepository(database);
      await products.save(
        const Product(
          name: 'أرز',
          purchasePriceMinor: 12000,
          salePriceMinor: 15000,
          minimumStock: 3,
          stockOnHand: 25,
        ),
      );
      await products.save(
        const Product(
          name: 'سكر',
          purchasePriceMinor: 8000,
          salePriceMinor: 10000,
          minimumStock: 4,
          stockOnHand: 18,
        ),
      );
      await products.save(
        const Product(
          name: 'زيت',
          purchasePriceMinor: 6000,
          salePriceMinor: 8500,
          minimumStock: 2,
          stockOnHand: 12,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          home: MainShell(
            productsRepository: products,
            salesRepository: sales,
            purchasesRepository: purchases,
            expensesRepository: expenses,
            backupRepository: backup,
            reportRepository: reports,
            notesRepository: notes,
            themeMode: ThemeMode.light,
            onThemeModeChanged: (_) {},
            initialInvoiceImportText: 'شاي\t10\t15\t3',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('فتح القائمة'));
      await tester.pumpAndSettle();
      expect(find.text('التقارير'), findsOneWidget);
      expect(find.text('التحليل'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text('الأصناف الناقصة'),
        ),
        findsNothing,
      );
      await tester.tap(find.widgetWithText(ListTile, 'الرئيسية'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('إضافة منتج جديد').first);
      await tester.pumpAndSettle();
      expect(find.byType(InvoiceImportReviewSheet), findsOneWidget);
      expect(find.text('مراجعة البيانات المستخرجة'), findsOneWidget);
      expect(find.text('شاي'), findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(820, 1180);
      await tester.pumpAndSettle();
      expect(find.byType(InvoiceImportReviewSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('إضافة الأصناف إلى الفاتورة'));
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(find.byType(InvoiceImportReviewSheet), findsNothing);
      expect(find.byType(PurchaseInvoiceSheet), findsOneWidget);
      expect(tester.takeException(), isNull);

      final invoiceFields = find.descendant(
        of: find.byType(PurchaseInvoiceSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(invoiceFields.first, 'مخزن النور');
      await tester.enterText(invoiceFields.at(1), '20');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('حفظ فاتورة الشراء'));
      await tester.pumpAndSettle();
      expect(find.byType(PurchaseInvoiceSheet), findsNothing);
      final tea = (await products.getProducts(search: 'شاي')).single;
      expect(tea.stockOnHand, 3);
      expect(tea.purchasePriceMinor, 1000);
      expect(tea.salePriceMinor, 1500);
      final receipt = (await database.select(database.purchases).get()).single;
      expect(receipt.totalMinor, 3000);
      final paymentRows = await database
          .select(database.purchasePayments)
          .get();
      expect(paymentRows.single.amountMinor, 2000);
      expect(find.text('شاي'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
