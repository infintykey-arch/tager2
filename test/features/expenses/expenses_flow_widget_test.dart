import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/app/tager_app.dart';
import 'package:tager2/data/local/app_database.dart';
import 'package:tager2/features/products/data/products_repository.dart';
import 'package:tager2/features/sales/data/sales_repository.dart';
import 'package:tager2/features/purchases/data/purchases_repository.dart';
import 'package:tager2/features/expenses/data/expenses_repository.dart';
import 'package:tager2/features/expenses/presentation/expenses_page.dart';
import 'package:tager2/features/backup/data/database_backup_repository.dart';
import 'package:tager2/features/analytics/data/report_repository.dart';
import 'package:tager2/features/notes/data/notes_repository.dart';
import 'package:tager2/features/settings/data/app_settings_repository.dart';

void main() {
  testWidgets('تسجيل مصروف يحدّث إجمالي اليوم وقائمة المصروفات', (
    tester,
  ) async {
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
    await tester.tap(find.widgetWithText(ListTile, 'المصروفات'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد مصروفات مسجلة بعد.'), findsOneWidget);
    expect(find.text('مصروفات هذا الشهر'), findsOneWidget);

    await tester.tap(find.text('تحديد فترة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('عرض الفترة'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد مصروفات في هذه الفترة.'), findsOneWidget);
    await tester.tap(find.text('مسح الفترة'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('تسجيل مصروف'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(ExpenseEditorSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), '125.50');
    await tester.enterText(fields.at(1), 'توصيل طلبية');
    await tester.enterText(fields.at(2), 'السوق');
    await tester.tap(find.text('حفظ المصروف'));
    await tester.pumpAndSettle();

    expect(find.text('125.50 ج.م'), findsNWidgets(3));
    expect(find.textContaining('توصيل طلبية'), findsOneWidget);
    expect(find.textContaining('المكان: السوق'), findsOneWidget);
    expect((await expenses.getRecent()).single.amountMinor, 12550);
    expect((await expenses.getRecent()).single.location, 'السوق');
    expect(
      await expenses.getTotalBetween(
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
        DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day + 1,
        ),
      ),
      12550,
    );

    await database.close();
  });
}
