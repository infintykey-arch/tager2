import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/data/local/app_database.dart';
import 'package:tager2/features/products/data/products_repository.dart';
import 'package:tager2/features/products/domain/product.dart';
import 'package:tager2/features/sales/data/sales_repository.dart';
import 'package:tager2/features/settings/data/app_settings_repository.dart';

void main() {
  test('يحفظ المنتج والفاتورة والثيم بعد إغلاق SQLite وإعادة فتحها', () async {
    final directory = await Directory.systemTemp.createTemp(
      'tager2-persistence-',
    );
    var database = AppDatabase.forTesting(
      NativeDatabase(File('${directory.path}/tager2.db')),
    );
    addTearDown(() async {
      await database.close();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final products = DriftProductsRepository(database);
    final sales = DriftSalesRepository(database);
    final settings = DriftAppSettingsRepository(database);
    await products.save(
      const Product(
        name: 'لبن اختبار الاستمرارية',
        purchasePriceMinor: 800,
        salePriceMinor: 1250,
        minimumStock: 1,
        stockOnHand: 4,
      ),
    );
    final product = (await products.getProducts(
      filter: ProductListFilter.allActive,
    )).single;
    final receipt = await sales.createSale(
      SaleDraft(
        lines: [SaleLineDraft(productId: product.id!, quantity: 1)],
        paymentKind: SalePaymentKind.cash,
        requestKey: 'persistence-reopen-sale',
      ),
    );
    await settings.saveDarkTheme(true);

    await database.close();
    database = AppDatabase.forTesting(
      NativeDatabase(File('${directory.path}/tager2.db')),
    );

    final reopenedProducts = DriftProductsRepository(database);
    final reopenedSales = DriftSalesRepository(database);
    final reopenedSettings = DriftAppSettingsRepository(database);
    final savedProduct = (await reopenedProducts.getProducts(
      filter: ProductListFilter.allActive,
    )).single;
    final savedReceipt = await reopenedSales.getSale(receipt.id);

    expect(database.schemaVersion, 10);
    expect(savedProduct.name, 'لبن اختبار الاستمرارية');
    expect(savedProduct.stockOnHand, 3);
    expect(savedReceipt, isNotNull);
    expect(savedReceipt!.totalMinor, 1250);
    expect(savedReceipt.lines, hasLength(1));
    expect(await reopenedSettings.loadDarkTheme(), isTrue);
    final rankedPage = await reopenedProducts.getProductsPage(
      search: 'لبن',
      filter: ProductListFilter.allActive,
    );
    expect(rankedPage.products.single.id, savedProduct.id);
    final summary = await database
        .select(database.productSalesSummaries)
        .getSingle();
    expect(summary.quantitySold, 1);
    final stockSummary = await database
        .select(database.productStockSummaries)
        .getSingle();
    expect(stockSummary.quantityOnHand, 3);
  });

  test(
    'يرقي بيانات v9 المعبأة ويعيد بناء ملخص البيع والفهرس دون فقد البيانات',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'tager2-v9-migration-',
      );
      var database = AppDatabase.forTesting(
        NativeDatabase(File('${directory.path}/tager2.db')),
      );
      addTearDown(() async {
        await database.close();
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final products = DriftProductsRepository(database);
      final sales = DriftSalesRepository(database);
      final settings = DriftAppSettingsRepository(database);
      await products.save(
        const Product(
          name: 'تفاح أحمر',
          purchasePriceMinor: 100,
          salePriceMinor: 150,
          minimumStock: 1,
          stockOnHand: 10,
        ),
      );
      await products.save(
        const Product(
          name: 'تفاح أخضر',
          purchasePriceMinor: 100,
          salePriceMinor: 150,
          minimumStock: 1,
          stockOnHand: 10,
        ),
      );
      final existing = await products.getProducts(
        filter: ProductListFilter.allActive,
      );
      await sales.createSale(
        SaleDraft(
          lines: [SaleLineDraft(productId: existing[0].id!, quantity: 1)],
          paymentKind: SalePaymentKind.cash,
          requestKey: 'v9-migration-lower-sales',
        ),
      );
      await sales.createSale(
        SaleDraft(
          lines: [SaleLineDraft(productId: existing[1].id!, quantity: 4)],
          paymentKind: SalePaymentKind.cash,
          requestKey: 'v9-migration-top-sales',
        ),
      );
      await settings.saveDarkTheme(true);

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
      var reopenedProducts = DriftProductsRepository(database);
      final migratedPage = await reopenedProducts.getProductsPage(
        filter: ProductListFilter.allActive,
        limit: 20,
      );
      expect(migratedPage.products, hasLength(2));
      expect(migratedPage.products.first.name, 'تفاح أخضر');
      expect(migratedPage.products.first.stockOnHand, 6);
      expect(migratedPage.products.last.stockOnHand, 9);
      expect(migratedPage.hasMore, isFalse);
      await database.rebuildProductSearchGrams();
      final greenProductId = existing.last.id!;
      await (database.delete(
        database.productSearchGrams,
      )..where((row) => row.productId.equals(greenProductId))).go();
      await (database.update(database.appPreferences)..where(
            (row) =>
                row.preferenceKey.equals('_system_product_search_index_v1'),
          ))
          .write(
            AppPreferencesCompanion(
              value: Value('building:${existing.first.id}'),
            ),
          );
      await database.close();
      database = AppDatabase.forTesting(
        NativeDatabase(File('${directory.path}/tager2.db')),
      );
      reopenedProducts = DriftProductsRepository(database);
      expect(await database.isProductSearchIndexReady(), isFalse);
      final typoSearch = await reopenedProducts.getProductsPage(
        search: 'تفح',
        filter: ProductListFilter.allActive,
      );
      expect(typoSearch.products.map((product) => product.name), [
        'تفاح أخضر',
        'تفاح أحمر',
      ]);
      await database.ensureProductSearchIndexReady();
      expect(await database.isProductSearchIndexReady(), isTrue);
      expect(
        await (database.select(
          database.productSearchGrams,
        )..where((row) => row.productId.equals(greenProductId))).get(),
        isNotEmpty,
      );
      expect(
        await DriftAppSettingsRepository(database).loadDarkTheme(),
        isTrue,
      );

      final redProductId = existing.first.id!;
      final redLine = (await (database.select(
        database.saleLines,
      )..where((line) => line.productId.equals(redProductId))).get()).single;
      await (database.update(database.saleLines)
            ..where((line) => line.id.equals(redLine.id)))
          .write(SaleLinesCompanion(quantity: const Value(2)));
      var redSummary = await (database.select(
        database.productSalesSummaries,
      )..where((row) => row.productId.equals(redProductId))).getSingle();
      expect(redSummary.quantitySold, 2);
      await (database.delete(
        database.saleLines,
      )..where((line) => line.id.equals(redLine.id))).go();
      redSummary = await (database.select(
        database.productSalesSummaries,
      )..where((row) => row.productId.equals(redProductId))).getSingle();
      expect(redSummary.quantitySold, 0);

      await reopenedProducts.save(
        const Product(
          name: 'اختبار ملخص رصيد',
          purchasePriceMinor: 100,
          salePriceMinor: 150,
          minimumStock: 1,
          stockOnHand: 1,
        ),
      );
      final triggerProduct = await (database.select(
        database.products,
      )..where((row) => row.name.equals('اختبار ملخص رصيد'))).getSingle();
      await reopenedProducts.adjustStock(
        triggerProduct.id,
        2,
        note: 'اختبار triggers',
      );
      final adjustment =
          (await (database.select(database.stockMovements)..where(
                    (row) =>
                        row.productId.equals(triggerProduct.id) &
                        row.sourceType.equals('manual_adjustment'),
                  ))
                  .get())
              .single;
      var stockSummary = await (database.select(
        database.productStockSummaries,
      )..where((row) => row.productId.equals(triggerProduct.id))).getSingle();
      expect(stockSummary.quantityOnHand, 3);
      await (database.update(database.stockMovements)
            ..where((row) => row.id.equals(adjustment.id)))
          .write(StockMovementsCompanion(quantityDelta: const Value(3)));
      stockSummary = await (database.select(
        database.productStockSummaries,
      )..where((row) => row.productId.equals(triggerProduct.id))).getSingle();
      expect(stockSummary.quantityOnHand, 4);
      await (database.delete(
        database.stockMovements,
      )..where((row) => row.id.equals(adjustment.id))).go();
      stockSummary = await (database.select(
        database.productStockSummaries,
      )..where((row) => row.productId.equals(triggerProduct.id))).getSingle();
      expect(stockSummary.quantityOnHand, 1);

      await database.rebuildProductSalesSummary();
      await database.rebuildProductSalesSummary();
      await database.rebuildProductStockSummary();
      await database.rebuildProductStockSummary();
      redSummary = await (database.select(
        database.productSalesSummaries,
      )..where((row) => row.productId.equals(redProductId))).getSingle();
      expect(redSummary.quantitySold, 0);
      stockSummary = await (database.select(
        database.productStockSummaries,
      )..where((row) => row.productId.equals(triggerProduct.id))).getSingle();
      expect(stockSummary.quantityOnHand, 1);
      reopenedProducts.invalidateProductPages();
      final rebuiltPage = await reopenedProducts.getProductsPage(
        search: 'تفح',
        filter: ProductListFilter.allActive,
        limit: 20,
      );
      expect(rebuiltPage.products.map((product) => product.name), [
        'تفاح أخضر',
        'تفاح أحمر',
      ]);
    },
  );
}
