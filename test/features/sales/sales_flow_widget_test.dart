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
  testWidgets('تدفق البيع النقدي من البطاقة إلى خصم المخزون', (tester) async {
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

    await tester.tap(find.byTooltip('بدء فاتورة بيع'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('لبن').first);
    await tester.pumpAndSettle();
    expect(find.text('مراجعة الفاتورة (1)'), findsOneWidget);

    await tester.tap(find.text('مراجعة الفاتورة (1)'));
    await tester.pumpAndSettle();
    expect(find.text('فاتورة بيع جديدة'), findsOneWidget);
    expect(find.text('إجمالي الفاتورة'), findsOneWidget);

    await tester.tap(find.text('تأكيد البيع النقدي'));
    await tester.pumpAndSettle();

    expect(find.textContaining('تم حفظ S-'), findsOneWidget);
    expect((await products.getProducts()).single.stockOnHand, 4);
    await database.close();
  });
}
