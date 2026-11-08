import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'app/tager_app.dart';
import 'core/ads/app_open_ad_service.dart';
import 'core/ads/startup_ads_initializer.dart';
import 'data/local/app_database.dart';
import 'features/products/data/products_repository.dart';
import 'features/sales/data/sales_repository.dart';
import 'features/purchases/data/purchases_repository.dart';
import 'features/expenses/data/expenses_repository.dart';
import 'features/backup/data/database_backup_repository.dart';
import 'features/analytics/data/report_repository.dart';
import 'features/notes/data/notes_repository.dart';
import 'features/settings/data/app_settings_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    // Keep barcode decoding local: the package's automatic fallback downloads
    // zxing-wasm from a CDN on browsers without BarcodeDetector.
    MobileScannerPlatform.instance.setWebBarcodeReader(
      WebBarcodeReader.barcodeDetector,
    );
  }

  final appDatabase = AppDatabase();
  final productsRepository = DriftProductsRepository(appDatabase);
  final salesRepository = DriftSalesRepository(appDatabase);
  final purchasesRepository = DriftPurchasesRepository(appDatabase);
  final expensesRepository = DriftExpensesRepository(appDatabase);
  final backupRepository = DatabaseBackupRepository(appDatabase);
  final reportRepository = LocalReportRepository(appDatabase);
  final notesRepository = DriftNotesRepository(appDatabase);
  final settingsRepository = DriftAppSettingsRepository(appDatabase);

  scheduleAdsInitializationAfterFirstFrame(
    AppOpenAdService.instance.initialize,
  );

  runApp(
    TagerApp(
      productsRepository: productsRepository,
      salesRepository: salesRepository,
      purchasesRepository: purchasesRepository,
      expensesRepository: expensesRepository,
      backupRepository: backupRepository,
      reportRepository: reportRepository,
      notesRepository: notesRepository,
      settingsRepository: settingsRepository,
    ),
  );
}
