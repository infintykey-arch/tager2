import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/data/local/app_database.dart';
import 'package:tager2/features/products/data/products_repository.dart';
import 'package:tager2/features/products/domain/product.dart';
import 'package:tager2/features/settings/data/app_settings_repository.dart';

void main() {
  test('يخدم متجرًا محليًا كبيرًا بصفحات مفهرسة وبحث عربي لا يفوّت النتائج', () async {
    const datasetSize = 100000;
    const batchSize = 250;
    const pageSize = 60;
    final directory = await Directory.systemTemp.createTemp(
      'tager2-performance-',
    );
    var database = AppDatabase.forTesting(
      NativeDatabase(File('${directory.path}/tager2.db')),
    );
    addTearDown(() async {
      await database.close();
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final timestamp = DateTime.utc(2026, 11, 1).toIso8601String();
    String productName(int id) {
      if (id == 1) return 'تفاح أحمر';
      if (id >= 2 && id <= 201) {
        return 'تفصيل مرشح ${id.toString().padLeft(6, '0')}';
      }
      if (id == 262) return 'أفضل منتج مبيعًا';
      if (id == 263 || id == 264) return 'صنف تعادل';
      if (id >= 300 && id <= 399) {
        return 'تفاح مطابق ${id.toString().padLeft(6, '0')}';
      }
      return 'صنف مخزن ${id.toString().padLeft(6, '0')}';
    }

    int soldQuantity(int id) {
      if (id == 262) return 300;
      if (id >= 2 && id <= 201) return 100;
      if (id == 263 || id == 264) return 7;
      if (id >= 300 && id <= 399) return 50;
      return 1;
    }

    double targetStock(int id) => switch (id % 3) {
      0 => 0,
      1 => 5,
      _ => 15,
    };

    final insertWatch = Stopwatch()..start();
    for (var start = 1; start <= datasetSize; start += batchSize) {
      final end = (start + batchSize - 1).clamp(1, datasetSize);
      final productRows = <ProductsCompanion>[];
      final movementRows = <StockMovementsCompanion>[];
      final salesRows = <SalesCompanion>[];
      final lineRows = <SaleLinesCompanion>[];

      for (var id = start; id <= end; id++) {
        final stock = targetStock(id);
        final firstDelta = stock == 0 ? 1.0 : stock / 2;
        final secondDelta = stock == 0 ? -1.0 : stock - firstDelta;
        final sold = soldQuantity(id);
        final name = productName(id);

        productRows.add(
          ProductsCompanion.insert(
            id: Value(id),
            name: name,
            purchasePriceMinor: const Value(100),
            salePriceMinor: const Value(150),
            minimumStock: const Value(10),
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
        movementRows
          ..add(
            StockMovementsCompanion.insert(
              id: Value((id - 1) * 2 + 1),
              productId: id,
              quantityDelta: firstDelta,
              sourceType: 'stress_test',
              occurredAt: timestamp,
            ),
          )
          ..add(
            StockMovementsCompanion.insert(
              id: Value((id - 1) * 2 + 2),
              productId: id,
              quantityDelta: secondDelta,
              sourceType: 'stress_test',
              occurredAt: timestamp,
            ),
          );
        salesRows.add(
          SalesCompanion.insert(
            id: Value(id),
            invoiceNumber: Value('STRESS-$id'),
            paymentType: 'cash',
            totalMinor: sold * 150,
            requestKey: 'stress-sale-$id',
            createdAt: timestamp,
          ),
        );
        lineRows.add(
          SaleLinesCompanion.insert(
            id: Value(id),
            saleId: id,
            productId: Value(id),
            productName: name,
            unitPriceMinor: 150,
            quantity: sold.toDouble(),
            lineTotalMinor: sold * 150,
          ),
        );
      }

      await database.batch((batch) {
        batch.insertAll(database.products, productRows);
        batch.insertAll(database.stockMovements, movementRows);
        batch.insertAll(database.sales, salesRows);
        batch.insertAll(database.saleLines, lineRows);
      });
    }
    await database.rebuildProductSearchGrams();
    insertWatch.stop();

    final repository = DriftProductsRepository(database);
    final fullWatch = Stopwatch()..start();
    var allProducts = await repository.getProducts(
      filter: ProductListFilter.allActive,
    );
    fullWatch.stop();
    expect(allProducts, hasLength(datasetSize));
    expect(allProducts.first.id, 262);

    final pageWatch = Stopwatch()..start();
    final firstPage = await repository.getProductsPage(
      filter: ProductListFilter.allActive,
      limit: pageSize,
    );
    final secondPage = await repository.getProductsPage(
      filter: ProductListFilter.allActive,
      offset: pageSize,
      limit: pageSize,
    );
    pageWatch.stop();
    expect(firstPage.products, hasLength(pageSize));
    expect(firstPage.hasMore, isTrue);
    expect(secondPage.products, hasLength(pageSize));
    expect(
      firstPage.products
          .map((product) => product.id)
          .toSet()
          .intersection(
            secondPage.products.map((product) => product.id).toSet(),
          ),
      isEmpty,
    );
    expect(firstPage.products.first.id, 262);
    final tiedNames = firstPage.products
        .skip(1)
        .map((product) => product.name)
        .toList();
    final sortedTiedNames = [...tiedNames]..sort();
    expect(tiedNames, sortedTiedNames);

    final typoWatch = Stopwatch()..start();
    final typoResults = await repository.getProductsPage(
      search: 'تفح',
      filter: ProductListFilter.allActive,
      limit: pageSize,
    );
    typoWatch.stop();
    expect(
      typoResults.products.map((product) => product.id),
      List<int>.generate(pageSize, (index) => 300 + index),
    );
    expect(typoResults.hasMore, isTrue);
    final secondTypoPage = await repository.getProductsPage(
      search: 'تفح',
      filter: ProductListFilter.allActive,
      offset: pageSize,
      limit: pageSize,
    );
    expect(secondTypoPage.products.map((product) => product.id), [
      ...List<int>.generate(40, (index) => 360 + index),
      1,
    ]);
    expect(secondTypoPage.hasMore, isFalse);
    final normalizedSearch = await repository.getProductsPage(
      search: 'احمر',
      filter: ProductListFilter.allActive,
    );
    expect(normalizedSearch.products.map((product) => product.id), [1]);
    final tiedSearch = await repository.getProductsPage(
      search: 'تعادل',
      filter: ProductListFilter.allActive,
    );
    expect(tiedSearch.products.map((product) => product.id), [263, 264]);

    final counts = await repository.getStockCounts();
    var expectedMissing = 0;
    var expectedLowStock = 0;
    var expectedAvailable = 0;
    for (var id = 1; id <= datasetSize; id++) {
      final stock = targetStock(id);
      if (stock <= 0) {
        expectedMissing++;
      } else {
        expectedAvailable++;
        if (stock <= 10) expectedLowStock++;
      }
    }
    expect(counts.available, expectedAvailable);
    expect(counts.lowStock, expectedLowStock);
    expect(counts.missing, expectedMissing);

    // Intentional ranking boundary: 200 higher-selling decoys precede 100
    // matching names, so true results straddle candidate pages of 240 rows.
    // The first 60 must be complete and sorted, then page two returns the rest.
    expect(datasetSize, greaterThan(261));
    // ignore: avoid_print
    print(
      'PERF dataset=$datasetSize stockMovements=${datasetSize * 2} '
      'saleLines=$datasetSize seedMs=${insertWatch.elapsedMilliseconds} '
      'fullListMs=${fullWatch.elapsedMilliseconds} fullRows=${allProducts.length} '
      'twoPagesMs=${pageWatch.elapsedMilliseconds} pageRows=${pageSize * 2} '
      'typoBeyond240Ms=${typoWatch.elapsedMilliseconds} '
      'typoResults=${typoResults.products.length}',
    );

    allProducts = const <Product>[];
    await DriftAppSettingsRepository(database).saveDarkTheme(true);
    for (final trigger in [
      'trg_products_sales_summary_insert',
      'trg_sale_lines_sales_summary_insert',
      'trg_sale_lines_sales_summary_delete',
      'trg_sale_lines_sales_summary_update_old',
      'trg_sale_lines_sales_summary_update_new',
      'trg_products_stock_summary_insert',
      'trg_stock_movements_summary_insert',
      'trg_stock_movements_summary_delete',
      'trg_stock_movements_summary_update_old',
      'trg_stock_movements_summary_update_new',
    ]) {
      await database.customStatement('DROP TRIGGER IF EXISTS $trigger');
    }
    await database.customStatement('DROP TABLE product_search_grams');
    await database.customStatement('DROP TABLE product_stock_summary');
    await database.customStatement('DROP TABLE product_sales_summary');
    await database.customStatement('PRAGMA user_version = 9');
    await database.close();

    database = AppDatabase.forTesting(
      NativeDatabase(File('${directory.path}/tager2.db')),
    );
    final migrationWatch = Stopwatch()..start();
    final migratedRepository = DriftProductsRepository(database);
    final migratedPage = await migratedRepository.getProductsPage(
      filter: ProductListFilter.allActive,
      limit: pageSize,
    );
    expect(migratedPage.products, hasLength(pageSize));
    expect(migratedPage.products.first.id, 262);
    migrationWatch.stop();
    final firstSearchWatch = Stopwatch()..start();
    final migratedTypoResults = await migratedRepository.getProductsPage(
      search: 'تفح',
      filter: ProductListFilter.allActive,
      limit: pageSize,
    );
    firstSearchWatch.stop();
    expect(
      migratedTypoResults.products.map((product) => product.id),
      List<int>.generate(pageSize, (index) => 300 + index),
    );
    expect(migratedTypoResults.hasMore, isTrue);
    expect(firstSearchWatch.elapsed, lessThan(const Duration(seconds: 2)));
    final migratedSecondTypoPage = await migratedRepository.getProductsPage(
      search: 'تفح',
      filter: ProductListFilter.allActive,
      offset: pageSize,
      limit: pageSize,
    );
    expect(migratedSecondTypoPage.products.map((product) => product.id), [
      ...List<int>.generate(40, (index) => 360 + index),
      1,
    ]);
    expect(migratedSecondTypoPage.hasMore, isFalse);
    final migratedCounts = await migratedRepository.getStockCounts();
    expect(migratedCounts.available, expectedAvailable);
    expect(migratedCounts.lowStock, expectedLowStock);
    expect(migratedCounts.missing, expectedMissing);
    expect(await DriftAppSettingsRepository(database).loadDarkTheme(), isTrue);
    final indexBuildWatch = Stopwatch()..start();
    await database.ensureProductSearchIndexReady();
    indexBuildWatch.stop();
    migratedRepository.invalidateProductPages();
    final indexedTypoResults = await migratedRepository.getProductsPage(
      search: 'تفح',
      filter: ProductListFilter.allActive,
      limit: pageSize,
    );
    expect(
      indexedTypoResults.products.map((product) => product.id),
      List<int>.generate(pageSize, (index) => 300 + index),
    );
    expect(indexedTypoResults.hasMore, isTrue);
    // ignore: avoid_print
    print(
      'PERF v9ToV10Rows=$datasetSize migrationAndFirstReadMs='
      '${migrationWatch.elapsedMilliseconds} '
      'firstSearchFallbackMs=${firstSearchWatch.elapsedMilliseconds} '
      'searchIndexBackgroundBuildMs=${indexBuildWatch.elapsedMilliseconds} '
      'migratedSearchRows=${migratedTypoResults.products.length}',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
