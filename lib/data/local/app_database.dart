import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as sqflite;

import '../../features/products/domain/product_search.dart';

part 'app_database.g.dart';

@DataClassName('ProductRow')
class Products extends Table {
  @override
  String get tableName => 'products';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get purchasePriceMinor =>
      integer().named('purchase_price_minor').withDefault(const Constant(0))();
  IntColumn get averageCostMilliMinor => integer()
      .named('average_cost_milli_minor')
      .withDefault(const Constant(0))();
  BoolColumn get averageCostReliable => boolean()
      .named('average_cost_reliable')
      .withDefault(const Constant(true))();
  IntColumn get salePriceMinor =>
      integer().named('sale_price_minor').withDefault(const Constant(0))();
  RealColumn get minimumStock =>
      real().named('minimum_stock').withDefault(const Constant(0))();
  BoolColumn get isArchived =>
      boolean().named('is_archived').withDefault(const Constant(false))();
  TextColumn get codeValue => text().named('code_value').nullable()();
  TextColumn get codeType => text().named('code_type').nullable()();
  TextColumn get createdAt => text().named('created_at')();
  TextColumn get updatedAt => text().named('updated_at')();
}

@DataClassName('StockMovementRow')
class StockMovements extends Table {
  @override
  String get tableName => 'stock_movements';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId =>
      integer().named('product_id').references(Products, #id)();
  RealColumn get quantityDelta => real().named('quantity_delta')();
  TextColumn get sourceType => text().named('source_type')();
  TextColumn get sourceId => text().named('source_id').nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get occurredAt => text().named('occurred_at')();
}

@DataClassName('CustomerRow')
class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get normalizedName => text().named('normalized_name').unique()();
  TextColumn get createdAt => text().named('created_at')();
  TextColumn get updatedAt => text().named('updated_at')();
}

@DataClassName('SaleRow')
class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoiceNumber =>
      text().named('invoice_number').nullable().unique()();
  IntColumn get customerId => integer()
      .named('customer_id')
      .nullable()
      .references(Customers, #id, onDelete: KeyAction.setNull)();
  TextColumn get customerNameSnapshot =>
      text().named('customer_name_snapshot').nullable()();
  TextColumn get paymentType => text().named('payment_type')();
  IntColumn get totalMinor => integer().named('total_minor')();
  TextColumn get requestKey => text().named('request_key').unique()();
  TextColumn get createdAt => text().named('created_at')();
}

@DataClassName('SaleLineRow')
class SaleLines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId => integer()
      .named('sale_id')
      .references(Sales, #id, onDelete: KeyAction.cascade)();
  IntColumn get productId => integer()
      .named('product_id')
      .nullable()
      .references(Products, #id, onDelete: KeyAction.setNull)();
  TextColumn get productName => text().named('product_name')();
  IntColumn get unitPriceMinor => integer().named('unit_price_minor')();
  RealColumn get quantity => real()();
  IntColumn get lineTotalMinor => integer().named('line_total_minor')();
  IntColumn get unitCostMilliMinor =>
      integer().named('unit_cost_milli_minor').nullable()();
  IntColumn get costTotalMinor =>
      integer().named('cost_total_minor').nullable()();
}

@DataClassName('SalePaymentRow')
class SalePayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId => integer()
      .named('sale_id')
      .references(Sales, #id, onDelete: KeyAction.cascade)();
  IntColumn get amountMinor => integer().named('amount_minor')();
  TextColumn get requestKey => text().named('request_key').unique()();
  TextColumn get occurredAt => text().named('occurred_at')();
}

@DataClassName('SupplierRow')
class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get normalizedName => text().named('normalized_name').unique()();
  TextColumn get createdAt => text().named('created_at')();
  TextColumn get updatedAt => text().named('updated_at')();
}

@DataClassName('PurchaseRow')
class Purchases extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoiceNumber =>
      text().named('invoice_number').nullable().unique()();
  IntColumn get supplierId => integer()
      .named('supplier_id')
      .nullable()
      .references(Suppliers, #id, onDelete: KeyAction.setNull)();
  TextColumn get supplierNameSnapshot =>
      text().named('supplier_name_snapshot')();
  IntColumn get totalMinor => integer().named('total_minor')();
  TextColumn get requestKey => text().named('request_key').unique()();
  TextColumn get createdAt => text().named('created_at')();
}

@DataClassName('PurchaseLineRow')
class PurchaseLines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get purchaseId => integer()
      .named('purchase_id')
      .references(Purchases, #id, onDelete: KeyAction.cascade)();
  IntColumn get productId => integer()
      .named('product_id')
      .nullable()
      .references(Products, #id, onDelete: KeyAction.setNull)();
  TextColumn get productName => text().named('product_name')();
  IntColumn get purchasePriceMinor => integer().named('purchase_price_minor')();
  IntColumn get salePriceMinor => integer().named('sale_price_minor')();
  RealColumn get quantity => real()();
  IntColumn get lineTotalMinor => integer().named('line_total_minor')();
}

@DataClassName('PurchasePaymentRow')
class PurchasePayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get purchaseId => integer()
      .named('purchase_id')
      .references(Purchases, #id, onDelete: KeyAction.cascade)();
  IntColumn get amountMinor => integer().named('amount_minor')();
  TextColumn get requestKey => text().named('request_key').unique()();
  TextColumn get occurredAt => text().named('occurred_at')();
}

@DataClassName('ExpenseRow')
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get category => text()();
  TextColumn get description => text().nullable()();
  TextColumn get location => text().nullable()();
  IntColumn get amountMinor => integer().named('amount_minor')();
  TextColumn get requestKey => text().named('request_key').unique()();
  TextColumn get occurredAt => text().named('occurred_at')();
}

@DataClassName('NoteRow')
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get createdAt => text().named('created_at')();
  TextColumn get updatedAt => text().named('updated_at')();
}

@DataClassName('AppPreferenceRow')
class AppPreferences extends Table {
  @override
  String get tableName => 'app_preferences';

  TextColumn get preferenceKey => text().named('preference_key')();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {preferenceKey};
}

@DataClassName('ProductSalesSummaryRow')
class ProductSalesSummaries extends Table {
  @override
  String get tableName => 'product_sales_summary';

  IntColumn get productId => integer()
      .named('product_id')
      .references(Products, #id, onDelete: KeyAction.cascade)();
  RealColumn get quantitySold =>
      real().named('quantity_sold').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {productId};
}

@DataClassName('ProductStockSummaryRow')
class ProductStockSummaries extends Table {
  @override
  String get tableName => 'product_stock_summary';

  IntColumn get productId => integer()
      .named('product_id')
      .references(Products, #id, onDelete: KeyAction.cascade)();
  RealColumn get quantityOnHand =>
      real().named('quantity_on_hand').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {productId};
}

@DataClassName('ProductSearchGramRow')
class ProductSearchGrams extends Table {
  @override
  String get tableName => 'product_search_grams';

  IntColumn get productId => integer()
      .named('product_id')
      .references(Products, #id, onDelete: KeyAction.cascade)();
  TextColumn get gram => text()();

  @override
  Set<Column> get primaryKey => {productId, gram};
}

@DriftDatabase(
  tables: [
    Products,
    StockMovements,
    Customers,
    Sales,
    SaleLines,
    SalePayments,
    Suppliers,
    Purchases,
    PurchaseLines,
    PurchasePayments,
    Expenses,
    Notes,
    AppPreferences,
    ProductSalesSummaries,
    ProductStockSummaries,
    ProductSearchGrams,
  ],
)
class AppDatabase extends _$AppDatabase {
  static const _productSearchIndexKey = '_system_product_search_index_v1';

  Future<void>? _productSearchIndexBuild;

  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'tager2',
      native: DriftNativeOptions(
        // يحافظ على ملف قاعدة Android الذي أنشأه الأساس الأولي.
        databasePath: () async =>
            path.join(await sqflite.getDatabasesPath(), 'tager2.db'),
      ),
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
        onResult: (result) {
          if (result.missingFeatures.isNotEmpty) {
            // ignore: avoid_print
            print(
              'Drift Web storage: ${result.chosenImplementation}; '
              'missing features: ${result.missingFeatures}',
            );
          }
        },
      ),
    );
  }

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createIndexes();
      await _createSalesSummaryTriggers();
      await _createStockSummaryTriggers();
      await _writeProductSearchIndexState('complete:0');
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(products, products.codeValue);
        await migrator.addColumn(products, products.codeType);
      }
      if (from < 3) {
        await migrator.createTable(customers);
        await migrator.createTable(sales);
        await migrator.createTable(saleLines);
        await migrator.createTable(salePayments);
      }
      if (from < 4) {
        await migrator.createTable(suppliers);
        await migrator.createTable(purchases);
        await migrator.createTable(purchaseLines);
        await migrator.createTable(purchasePayments);
      }
      if (from < 5) {
        await migrator.createTable(expenses);
      }
      if (from == 5) {
        await migrator.addColumn(expenses, expenses.location);
      }
      if (from < 7) {
        await migrator.addColumn(products, products.averageCostMilliMinor);
        await migrator.addColumn(products, products.averageCostReliable);
        if (from >= 3) {
          await migrator.addColumn(saleLines, saleLines.unitCostMilliMinor);
          await migrator.addColumn(saleLines, saleLines.costTotalMinor);
        }
        await customStatement('''
          UPDATE products
          SET average_cost_milli_minor = purchase_price_minor * 1000,
              average_cost_reliable = CASE
                WHEN COALESCE((
                  SELECT SUM(quantity_delta)
                  FROM stock_movements
                  WHERE stock_movements.product_id = products.id
                ), 0) > 0 THEN 0
                ELSE 1
              END
        ''');
      }
      if (from < 8) {
        await migrator.createTable(notes);
      }
      if (from < 9) {
        await migrator.createTable(appPreferences);
      }
      if (from < 10) {
        await migrator.createTable(productSalesSummaries);
        await migrator.createTable(productStockSummaries);
        await migrator.createTable(productSearchGrams);
        await rebuildProductSalesSummary();
        await rebuildProductStockSummary();
        await _createSalesSummaryTriggers();
        await _createStockSummaryTriggers();
        await _writeProductSearchIndexState('building:0');
      }
      await _createIndexes();
    },
  );

  Future<void> rebuildProductSalesSummary() async {
    await delete(productSalesSummaries).go();
    await customStatement('''
      INSERT INTO product_sales_summary(product_id, quantity_sold)
      SELECT p.id, COALESCE(SUM(sl.quantity), 0)
      FROM products AS p
      LEFT JOIN sale_lines AS sl ON sl.product_id = p.id
      GROUP BY p.id
    ''');
  }

  Future<void> rebuildProductStockSummary() async {
    await delete(productStockSummaries).go();
    await customStatement('''
      INSERT INTO product_stock_summary(product_id, quantity_on_hand)
      SELECT p.id, COALESCE(SUM(sm.quantity_delta), 0)
      FROM products AS p
      LEFT JOIN stock_movements AS sm ON sm.product_id = p.id
      GROUP BY p.id
    ''');
  }

  Future<void> rebuildProductSearchGrams({
    bool withinTransaction = false,
  }) async {
    await _runSearchIndexTransaction(withinTransaction, () async {
      await delete(productSearchGrams).go();
      await _writeProductSearchIndexState('building:0');
    });
    await _continueProductSearchIndexBuild(
      'building:0',
      withinTransaction: withinTransaction,
    );
  }

  Future<bool> isProductSearchIndexReady() async {
    final state = await _readProductSearchIndexState();
    return state.startsWith('complete:');
  }

  void startProductSearchIndexBuild() {
    unawaited(_startProductSearchIndexBuildSafely());
  }

  Future<void> _startProductSearchIndexBuildSafely() async {
    try {
      await ensureProductSearchIndexReady();
    } catch (error) {
      // ignore: avoid_print
      print('Local product search index build failed: $error');
    }
  }

  Future<void> ensureProductSearchIndexReady() async {
    final alreadyRunning = _productSearchIndexBuild;
    if (alreadyRunning != null) return alreadyRunning;
    final state = await _readProductSearchIndexState();
    if (state.startsWith('complete:')) return;
    final activeBuild = _productSearchIndexBuild;
    if (activeBuild != null) return activeBuild;

    final build = _continueProductSearchIndexBuild(state);
    _productSearchIndexBuild = build;
    try {
      await build;
    } finally {
      if (identical(_productSearchIndexBuild, build)) {
        _productSearchIndexBuild = null;
      }
    }
  }

  Future<void> _continueProductSearchIndexBuild(
    String state, {
    bool withinTransaction = false,
  }) async {
    final marker = state.split(':');
    var lastProductId = marker.length == 2 && marker.first == 'building'
        ? int.tryParse(marker.last) ?? 0
        : 0;
    while (true) {
      final didWork = await _runSearchIndexTransaction(
        withinTransaction,
        () async {
          final rows = await customSelect(
            '''
            SELECT id, name FROM products
            WHERE id > ? ORDER BY id ASC LIMIT 250
            ''',
            variables: [Variable.withInt(lastProductId)],
          ).get();
          if (rows.isEmpty) {
            await _writeProductSearchIndexState('complete:$lastProductId');
            return false;
          }

          final productIds = rows.map((row) => row.read<int>('id')).toList();
          await (delete(
            productSearchGrams,
          )..where((table) => table.productId.isIn(productIds))).go();
          final grams = <ProductSearchGramsCompanion>[];
          for (final row in rows) {
            final productId = row.read<int>('id');
            for (final gram in productSearchIndexGrams(
              row.read<String>('name'),
            )) {
              grams.add(
                ProductSearchGramsCompanion.insert(
                  productId: productId,
                  gram: gram,
                ),
              );
            }
          }
          if (grams.isNotEmpty) {
            await batch((batch) => batch.insertAll(productSearchGrams, grams));
          }
          lastProductId = productIds.last;
          await _writeProductSearchIndexState('building:$lastProductId');
          return true;
        },
      );
      if (!didWork) break;
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<String> _readProductSearchIndexState() async {
    final rows = await customSelect(
      '''
      SELECT value FROM app_preferences
      WHERE preference_key = ? LIMIT 1
      ''',
      variables: [Variable.withString(_productSearchIndexKey)],
    ).get();
    if (rows.isEmpty) {
      await _writeProductSearchIndexState('building:0');
      return 'building:0';
    }
    return rows.single.read<String>('value');
  }

  Future<void> _writeProductSearchIndexState(String state) async {
    await into(appPreferences).insertOnConflictUpdate(
      AppPreferencesCompanion.insert(
        preferenceKey: _productSearchIndexKey,
        value: state,
      ),
    );
  }

  Future<T> _runSearchIndexTransaction<T>(
    bool withinTransaction,
    Future<T> Function() action,
  ) {
    if (withinTransaction) return action();
    return transaction(action);
  }

  Future<void> _createSalesSummaryTriggers() async {
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_products_sales_summary_insert
      AFTER INSERT ON products
      BEGIN
        INSERT OR IGNORE INTO product_sales_summary(product_id, quantity_sold)
        VALUES (NEW.id, 0);
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_sale_lines_sales_summary_insert
      AFTER INSERT ON sale_lines
      WHEN NEW.product_id IS NOT NULL
      BEGIN
        INSERT INTO product_sales_summary(product_id, quantity_sold)
        VALUES (NEW.product_id, NEW.quantity)
        ON CONFLICT(product_id) DO UPDATE SET
          quantity_sold = quantity_sold + excluded.quantity_sold;
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_sale_lines_sales_summary_delete
      AFTER DELETE ON sale_lines
      WHEN OLD.product_id IS NOT NULL
      BEGIN
        UPDATE product_sales_summary
        SET quantity_sold = quantity_sold - OLD.quantity
        WHERE product_id = OLD.product_id;
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_sale_lines_sales_summary_update_old
      AFTER UPDATE OF product_id, quantity ON sale_lines
      WHEN OLD.product_id IS NOT NULL
      BEGIN
        UPDATE product_sales_summary
        SET quantity_sold = quantity_sold - OLD.quantity
        WHERE product_id = OLD.product_id;
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_sale_lines_sales_summary_update_new
      AFTER UPDATE OF product_id, quantity ON sale_lines
      WHEN NEW.product_id IS NOT NULL
      BEGIN
        INSERT INTO product_sales_summary(product_id, quantity_sold)
        VALUES (NEW.product_id, NEW.quantity)
        ON CONFLICT(product_id) DO UPDATE SET
          quantity_sold = quantity_sold + excluded.quantity_sold;
      END
    ''');
  }

  Future<void> _createStockSummaryTriggers() async {
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_products_stock_summary_insert
      AFTER INSERT ON products
      BEGIN
        INSERT OR IGNORE INTO product_stock_summary(product_id, quantity_on_hand)
        VALUES (NEW.id, 0);
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_stock_movements_summary_insert
      AFTER INSERT ON stock_movements
      BEGIN
        INSERT INTO product_stock_summary(product_id, quantity_on_hand)
        VALUES (NEW.product_id, NEW.quantity_delta)
        ON CONFLICT(product_id) DO UPDATE SET
          quantity_on_hand = quantity_on_hand + excluded.quantity_on_hand;
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_stock_movements_summary_delete
      AFTER DELETE ON stock_movements
      BEGIN
        UPDATE product_stock_summary
        SET quantity_on_hand = quantity_on_hand - OLD.quantity_delta
        WHERE product_id = OLD.product_id;
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_stock_movements_summary_update_old
      AFTER UPDATE OF product_id, quantity_delta ON stock_movements
      BEGIN
        UPDATE product_stock_summary
        SET quantity_on_hand = quantity_on_hand - OLD.quantity_delta
        WHERE product_id = OLD.product_id;
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_stock_movements_summary_update_new
      AFTER UPDATE OF product_id, quantity_delta ON stock_movements
      BEGIN
        INSERT INTO product_stock_summary(product_id, quantity_on_hand)
        VALUES (NEW.product_id, NEW.quantity_delta)
        ON CONFLICT(product_id) DO UPDATE SET
          quantity_on_hand = quantity_on_hand + excluded.quantity_on_hand;
      END
    ''');
  }

  Future<void> _createIndexes() async {
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_stock_movements_product_time
      ON stock_movements(product_id, occurred_at DESC)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_products_active_name
      ON products(is_archived, name COLLATE NOCASE)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_products_code_value
      ON products(code_value)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_sales_customer_created
      ON sales(customer_id, created_at DESC)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_sale_lines_sale
      ON sale_lines(sale_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_sale_lines_product
      ON sale_lines(product_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_sale_payments_sale_time
      ON sale_payments(sale_id, occurred_at DESC)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_purchases_supplier_created
      ON purchases(supplier_id, created_at DESC)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_purchase_lines_purchase
      ON purchase_lines(purchase_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_purchase_payments_time
      ON purchase_payments(purchase_id, occurred_at DESC)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_expenses_time
      ON expenses(occurred_at DESC, id DESC)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_stock_movements_product_quantity
      ON stock_movements(product_id, quantity_delta)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_product_sales_quantity
      ON product_sales_summary(quantity_sold DESC, product_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_product_stock_quantity
      ON product_stock_summary(quantity_on_hand, product_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_product_search_grams_gram
      ON product_search_grams(gram, product_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_sales_created_id
      ON sales(created_at DESC, id DESC)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_purchases_created_id
      ON purchases(created_at DESC, id DESC)
    ''');
  }
}
