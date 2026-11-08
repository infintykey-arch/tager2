import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/app/tager_app.dart';
import 'package:tager2/core/ads/startup_ads_initializer.dart';
import 'package:tager2/data/local/app_database.dart';
import 'package:tager2/features/analytics/data/report_repository.dart';
import 'package:tager2/features/backup/data/database_backup_repository.dart';
import 'package:tager2/features/expenses/data/expenses_repository.dart';
import 'package:tager2/features/notes/data/notes_repository.dart';
import 'package:tager2/features/products/data/products_repository.dart';
import 'package:tager2/features/products/domain/product.dart';
import 'package:tager2/features/purchases/data/purchases_repository.dart';
import 'package:tager2/features/sales/data/sales_repository.dart';
import 'package:tager2/features/settings/data/app_settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'عشر بدايات باردة متتابعة تفتح الصفحة العربية وتنجح أول استعلامات Drift، ثم تستأنف دون أخطاء',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (var coldStart = 1; coldStart <= 10; coldStart++) {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        final products = DriftProductsRepository(database);
        final sales = DriftSalesRepository(database);
        final purchases = DriftPurchasesRepository(database);
        final expenses = DriftExpensesRepository(database);
        final backup = DatabaseBackupRepository(database);
        final reports = LocalReportRepository(database);
        final notes = DriftNotesRepository(database);

        await tester.pumpWidget(
          TagerApp(
            productsRepository: products,
            salesRepository: sales,
            purchasesRepository: purchases,
            expensesRepository: expenses,
            backupRepository: backup,
            reportRepository: reports,
            notesRepository: notes,
            settingsRepository: DriftAppSettingsRepository(database),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('tager-app-brand-logo')),
          findsOneWidget,
        );
        expect(find.text('كل الأصناف'), findsOneWidget);
        expect(find.text('إضافة منتج جديد'), findsAtLeastNWidgets(1));
        expect(
          Directionality.of(tester.element(find.text('كل الأصناف'))),
          TextDirection.rtl,
        );
        expect(await products.getProducts(), isEmpty);
        expect(
          await products.getProducts(filter: ProductListFilter.missing),
          isEmpty,
        );
        expect(
          await products.getProducts(filter: ProductListFilter.lowStock),
          isEmpty,
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'بدء بارد رقم $coldStart',
        );

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(find.text('كل الأصناف'), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: 'استئناف رقم $coldStart',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await database.close();
      }
    },
  );

  testWidgets('فشل أول استعلام لا يغلق التطبيق ويعرض إعادة المحاولة', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      _app(products: _FailingProductsRepository(), database: database),
    );
    await tester.pumpAndSettle();

    expect(find.text('تعذر تحميل المنتجات'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.byKey(const ValueKey('tager-app-brand-logo')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'إطار البداية يبقى ظاهرًا أثناء تأخر قاعدة البيانات ثم يعرض نتائجها',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final delayedProducts = _DelayedProductsRepository();

      await tester.pumpWidget(
        _app(products: delayedProducts, database: database),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('tager-app-brand-logo')),
        findsOneWidget,
      );
      expect(find.text('كل الأصناف'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(delayedProducts.pending.length, 3);
      expect(tester.takeException(), isNull);

      for (final query in delayedProducts.pending) {
        query.complete(const <Product>[]);
      }
      await tester.pumpAndSettle();
      expect(find.text('لا توجد منتجات بعد'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'الواجهة تظهر قبل طلب الإعلان ولا يبدأ الطلب إلا بعد نجاح التهيئة',
    (tester) async {
      final initialization = Completer<void>();
      var initializationCalls = 0;
      var adRequests = 0;

      scheduleAdsInitializationAfterFirstFrame(() async {
        initializationCalls++;
        await initialization.future;
        adRequests++;
      });

      expect(initializationCalls, 0);
      expect(adRequests, 0);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('واجهة البداية'))),
      );

      expect(find.text('واجهة البداية'), findsOneWidget);
      expect(initializationCalls, 1);
      expect(adRequests, 0);
      expect(tester.takeException(), isNull);

      initialization.complete();
      await tester.pump();
      expect(adRequests, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('فشل تهيئة الإعلانات بعد أول إطار لا يخرج التطبيق', (
    tester,
  ) async {
    scheduleAdsInitializationAfterFirstFrame(() async {
      throw StateError('simulated ad SDK initialization failure');
    });

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('واجهة البداية'))),
    );
    await tester.pump();

    expect(find.text('واجهة البداية'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  required ProductsRepository products,
  required AppDatabase database,
}) {
  return TagerApp(
    productsRepository: products,
    salesRepository: DriftSalesRepository(database),
    purchasesRepository: DriftPurchasesRepository(database),
    expensesRepository: DriftExpensesRepository(database),
    backupRepository: DatabaseBackupRepository(database),
    reportRepository: LocalReportRepository(database),
    notesRepository: DriftNotesRepository(database),
    settingsRepository: DriftAppSettingsRepository(database),
  );
}

class _FailingProductsRepository implements ProductsRepository {
  @override
  Future<List<Product>> getProducts({
    String search = '',
    ProductListFilter filter = ProductListFilter.available,
  }) =>
      Future<List<Product>>.error(StateError('simulated first-query failure'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedProductsRepository implements ProductsRepository {
  final pending = <Completer<List<Product>>>[];

  @override
  Future<List<Product>> getProducts({
    String search = '',
    ProductListFilter filter = ProductListFilter.available,
  }) {
    final completer = Completer<List<Product>>();
    pending.add(completer);
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
