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
import 'package:tager2/features/purchases/data/purchases_repository.dart';
import 'package:tager2/features/sales/data/sales_repository.dart';
import 'package:tager2/features/settings/data/app_settings_repository.dart';

void main() {
  testWidgets('يستعيد الوضع الداكن المحفوظ عند بدء التطبيق', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = DriftAppSettingsRepository(database);
    await settings.saveDarkTheme(true);

    await tester.pumpWidget(
      TagerApp(
        productsRepository: DriftProductsRepository(database),
        salesRepository: DriftSalesRepository(database),
        purchasesRepository: DriftPurchasesRepository(database),
        expensesRepository: DriftExpensesRepository(database),
        backupRepository: DatabaseBackupRepository(database),
        reportRepository: LocalReportRepository(database),
        notesRepository: DriftNotesRepository(database),
        settingsRepository: settings,
      ),
    );
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode ==
          ThemeMode.dark) {
        break;
      }
    }

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
