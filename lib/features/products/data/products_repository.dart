import 'package:sqflite/sqflite.dart';

import '../domain/product.dart';

abstract interface class ProductsRepository {
  Future<List<Product>> getProducts({
    String search = '',
    bool lowStockOnly = false,
  });

  Future<void> save(Product product);

  Future<void> adjustStock(
    int productId,
    double quantityDelta, {
    required String note,
  });

  Future<void> archive(int productId);

  Future<List<StockMovement>> getMovements(int productId);
}

class SqliteProductsRepository implements ProductsRepository {
  SqliteProductsRepository(this._database);

  final Database _database;

  @override
  Future<List<Product>> getProducts({
    String search = '',
    bool lowStockOnly = false,
  }) async {
    final conditions = <String>['p.is_archived = 0'];
    final arguments = <Object?>[];
    final normalizedSearch = search.trim();

    if (normalizedSearch.isNotEmpty) {
      conditions.add('p.name LIKE ?');
      arguments.add('%$normalizedSearch%');
    }

    final having = lowStockOnly
        ? 'HAVING COALESCE(SUM(sm.quantity_delta), 0) <= p.minimum_stock'
        : '';

    final rows = await _database.rawQuery('''
      SELECT
        p.id,
        p.name,
        p.purchase_price_minor,
        p.sale_price_minor,
        p.minimum_stock,
        p.created_at,
        p.updated_at,
        COALESCE(SUM(sm.quantity_delta), 0) AS stock_on_hand
      FROM products AS p
      LEFT JOIN stock_movements AS sm ON sm.product_id = p.id
      WHERE ${conditions.join(' AND ')}
      GROUP BY p.id
      $having
      ORDER BY p.name COLLATE NOCASE ASC
      ''', arguments);

    return rows.map(Product.fromDatabaseRow).toList(growable: false);
  }

  @override
  Future<void> save(Product product) async {
    final name = product.name.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(product.name, 'name', 'اسم المنتج مطلوب.');
    }
    if (product.purchasePriceMinor < 0 || product.salePriceMinor < 0) {
      throw ArgumentError('لا يمكن أن يكون السعر سالبًا.');
    }
    if (!product.minimumStock.isFinite || product.minimumStock < 0) {
      throw ArgumentError('حد التنبيه يجب أن يكون صفرًا أو أكثر.');
    }
    if (!product.stockOnHand.isFinite || product.stockOnHand < 0) {
      throw ArgumentError('الكمية الافتتاحية يجب أن تكون صفرًا أو أكثر.');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      final values = <String, Object?>{
        'name': name,
        'purchase_price_minor': product.purchasePriceMinor,
        'sale_price_minor': product.salePriceMinor,
        'minimum_stock': product.minimumStock,
        'updated_at': now,
      };

      if (product.id == null) {
        final productId = await txn.insert('products', {
          ...values,
          'created_at': now,
        });

        if (product.stockOnHand > 0) {
          await txn.insert('stock_movements', {
            'product_id': productId,
            'quantity_delta': product.stockOnHand,
            'source_type': 'opening_balance',
            'source_id': 'product:$productId',
            'note': 'رصيد افتتاحي',
            'occurred_at': now,
          });
        }
        return;
      }

      final changed = await txn.update(
        'products',
        values,
        where: 'id = ? AND is_archived = 0',
        whereArgs: [product.id],
      );
      if (changed != 1) {
        throw StateError('المنتج غير موجود أو مؤرشف.');
      }
    });
  }

  @override
  Future<void> adjustStock(
    int productId,
    double quantityDelta, {
    required String note,
  }) async {
    if (!quantityDelta.isFinite || quantityDelta == 0) {
      throw ArgumentError('أدخل كمية صحيحة غير صفرية.');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      final activeProduct = await txn.query(
        'products',
        columns: ['id'],
        where: 'id = ? AND is_archived = 0',
        whereArgs: [productId],
        limit: 1,
      );
      if (activeProduct.isEmpty) {
        throw StateError('المنتج غير موجود أو مؤرشف.');
      }

      final rows = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(quantity_delta), 0) AS stock_on_hand
        FROM stock_movements
        WHERE product_id = ?
        ''',
        [productId],
      );
      final currentStock = (rows.single['stock_on_hand'] as num).toDouble();
      final resultingStock = currentStock + quantityDelta;
      if (resultingStock < -0.0000001) {
        throw StateError('لا يمكن أن يصبح رصيد المخزون أقل من صفر.');
      }

      await txn.insert('stock_movements', {
        'product_id': productId,
        'quantity_delta': quantityDelta,
        'source_type': 'manual_adjustment',
        'note': note.trim().isEmpty ? null : note.trim(),
        'occurred_at': now,
      });
    });
  }

  @override
  Future<void> archive(int productId) async {
    final changed = await _database.update(
      'products',
      {
        'is_archived': 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ? AND is_archived = 0',
      whereArgs: [productId],
    );
    if (changed != 1) {
      throw StateError('المنتج غير موجود أو مؤرشف بالفعل.');
    }
  }

  @override
  Future<List<StockMovement>> getMovements(int productId) async {
    final rows = await _database.query(
      'stock_movements',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'occurred_at DESC, id DESC',
    );
    return rows.map(StockMovement.fromDatabaseRow).toList(growable: false);
  }
}
