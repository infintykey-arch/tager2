import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as sqflite;

class AppDatabase {
  AppDatabase(this.database);

  final sqflite.Database database;

  static const int schemaVersion = 1;
  static const String fileName = 'tager2.db';

  static Future<AppDatabase> open({
    sqflite.DatabaseFactory? databaseFactory,
    String? databasePath,
  }) async {
    final factory = databaseFactory ?? sqflite.databaseFactory;
    final pathOnDisk =
        databasePath ?? path.join(await sqflite.getDatabasesPath(), fileName);

    final database = await factory.openDatabase(
      pathOnDisk,
      options: sqflite.OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) => _createSchema(db),
        onUpgrade: (db, oldVersion, newVersion) async {
          // Add explicit, ordered migrations here when the schema changes.
          if (oldVersion < 1) {
            await _createSchema(db);
          }
        },
      ),
    );

    return AppDatabase(database);
  }

  static Future<void> _createSchema(sqflite.DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        purchase_price_minor INTEGER NOT NULL DEFAULT 0
          CHECK (purchase_price_minor >= 0),
        sale_price_minor INTEGER NOT NULL DEFAULT 0
          CHECK (sale_price_minor >= 0),
        minimum_stock REAL NOT NULL DEFAULT 0
          CHECK (minimum_stock >= 0),
        is_archived INTEGER NOT NULL DEFAULT 0
          CHECK (is_archived IN (0, 1)),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        quantity_delta REAL NOT NULL CHECK (quantity_delta <> 0),
        source_type TEXT NOT NULL,
        source_id TEXT,
        note TEXT,
        occurred_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_stock_movements_product_time
      ON stock_movements(product_id, occurred_at DESC)
    ''');
    await db.execute('''
      CREATE INDEX idx_products_active_name
      ON products(is_archived, name COLLATE NOCASE)
    ''');
  }

  Future<void> close() => database.close();
}
