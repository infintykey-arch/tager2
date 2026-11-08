import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/data/local/app_database.dart';
import 'package:tager2/features/products/data/products_repository.dart';
import 'package:tager2/features/products/domain/product.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (db) {
          db.execute('PRAGMA user_version = 1');
          db.execute('''
            CREATE TABLE products (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              purchase_price_minor INTEGER NOT NULL DEFAULT 0,
              sale_price_minor INTEGER NOT NULL DEFAULT 0,
              minimum_stock REAL NOT NULL DEFAULT 0.0,
              is_archived INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          db.execute('''
            CREATE TABLE stock_movements (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              product_id INTEGER NOT NULL REFERENCES products(id),
              quantity_delta REAL NOT NULL,
              source_type TEXT NOT NULL,
              source_id TEXT,
              note TEXT,
              occurred_at TEXT NOT NULL
            )
          ''');
          db.execute('''
            INSERT INTO products (
              id, name, purchase_price_minor, sale_price_minor,
              minimum_stock, is_archived, created_at, updated_at
            ) VALUES (7, 'سمن', 8500, 11000, 2, 0,
              '2026-11-01T10:00:00.000Z', '2026-11-01T10:00:00.000Z')
          ''');
          db.execute('''
            INSERT INTO stock_movements (
              product_id, quantity_delta, source_type, source_id, note, occurred_at
            ) VALUES (7, 4, 'opening_balance', 'product:7', 'رصيد افتتاحي',
              '2026-11-01T10:00:00.000Z')
          ''');
        },
      ),
    );
  });

  tearDown(() => database.close());

  test('يرقي مخطط الإصدار الأول مع الحفاظ على المنتج والحركات', () async {
    final repository = DriftProductsRepository(database);
    final existing = (await repository.getProducts(
      filter: ProductListFilter.allActive,
    )).single;

    expect(existing.id, 7);
    expect(existing.stockOnHand, 4);
    expect(existing.codeValue, isNull);
    expect(await repository.getMovements(7), hasLength(1));
    final migratedRow = await database.select(database.products).getSingle();
    expect(migratedRow.averageCostMilliMinor, 8500000);
    expect(migratedRow.averageCostReliable, isFalse);

    await repository.save(
      Product(
        id: existing.id,
        name: existing.name,
        purchasePriceMinor: existing.purchasePriceMinor,
        salePriceMinor: existing.salePriceMinor,
        minimumStock: existing.minimumStock,
        stockOnHand: existing.stockOnHand,
        codeValue: '6221234567890',
        codeType: 'barcode',
      ),
    );

    final coded = await repository.getProducts(
      filter: ProductListFilter.withCode,
    );
    expect(coded.single.id, 7);
    expect(coded.single.codeValue, '6221234567890');
    expect(coded.single.stockOnHand, 4);
    expect(await repository.getMovements(7), hasLength(1));
  });
}
