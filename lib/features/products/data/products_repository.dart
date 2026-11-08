import 'package:drift/drift.dart';

import '../../../data/local/app_database.dart';
import '../domain/product.dart';
import '../domain/product_search.dart';

class ProductResultsPage {
  const ProductResultsPage({required this.products, required this.hasMore});

  final List<Product> products;
  final bool hasMore;
}

class ProductStockCounts {
  const ProductStockCounts({
    required this.available,
    required this.lowStock,
    required this.missing,
  });

  final int available;
  final int lowStock;
  final int missing;
}

class _ProductSearchCursor {
  _ProductSearchCursor({required this.useGramIndex});

  bool useGramIndex;
  final List<int> matchingIds = <int>[];
  int candidateOffset = 0;
  bool exhausted = false;
}

abstract interface class ProductPagingRepository {
  Future<ProductResultsPage> getProductsPage({
    String search = '',
    ProductListFilter filter = ProductListFilter.available,
    int offset = 0,
    int limit = 60,
  });

  Future<ProductStockCounts> getStockCounts();

  void invalidateProductPages();
}

abstract interface class ProductsRepository {
  Future<List<Product>> getProducts({
    String search = '',
    ProductListFilter filter = ProductListFilter.available,
  });

  Future<ProductCodeMatch?> findProductByCode(String code);

  Future<List<Product>> findUncodedActiveProducts({String search = ''});

  Future<void> assignCode(
    int productId,
    String code, {
    required String codeType,
  });

  Future<void> save(Product product);

  Future<void> adjustStock(
    int productId,
    double quantityDelta, {
    required String note,
  });

  Future<void> archive(int productId);

  Future<void> restore(int productId);

  Future<void> deletePermanently(int productId);

  Future<List<StockMovement>> getMovements(int productId);
}

class DriftProductsRepository
    implements ProductsRepository, ProductPagingRepository {
  DriftProductsRepository(this._database);

  final AppDatabase _database;
  final Map<String, _ProductSearchCursor> _searchResultIds =
      <String, _ProductSearchCursor>{};

  @override
  Future<List<Product>> getProducts({
    String search = '',
    ProductListFilter filter = ProductListFilter.available,
  }) async {
    final products = _mapProducts(await _queryProductRows(filter: filter));

    final normalizedSearch = search.trim();
    if (normalizedSearch.isEmpty) return products;
    return products
        .where(
          (product) => matchesProductSearch(normalizedSearch, product.name),
        )
        .toList(growable: false);
  }

  @override
  Future<ProductResultsPage> getProductsPage({
    String search = '',
    ProductListFilter filter = ProductListFilter.available,
    int offset = 0,
    int limit = 60,
  }) async {
    if (offset < 0 || limit <= 0 || limit > 200) {
      throw ArgumentError('حدود صفحة المنتجات غير صالحة.');
    }

    final normalizedSearch = normalizeProductSearch(search);
    if (normalizedSearch.isEmpty) {
      final rows = await _queryProductRows(
        filter: filter,
        limit: limit + 1,
        offset: offset,
      );
      final hasMore = rows.length > limit;
      return ProductResultsPage(
        products: _mapProducts(rows.take(limit).toList(growable: false)),
        hasMore: hasMore,
      );
    }

    final wordGrams = productSearchQueryGrams(normalizedSearch);
    if (wordGrams.isEmpty) {
      return const ProductResultsPage(products: <Product>[], hasMore: false);
    }
    final indexReady = await _database.isProductSearchIndexReady();
    final cacheKey = '${filter.index}:$normalizedSearch';
    final cursor = _searchResultIds.putIfAbsent(
      cacheKey,
      () => _ProductSearchCursor(useGramIndex: indexReady),
    );
    if (cursor.useGramIndex != indexReady) {
      cursor
        ..useGramIndex = indexReady
        ..matchingIds.clear()
        ..candidateOffset = 0
        ..exhausted = false;
    }
    while (_searchResultIds.length > 4) {
      _searchResultIds.remove(_searchResultIds.keys.first);
    }

    await _ensureSearchResults(
      cursor,
      normalizedSearch,
      filter,
      wordGrams,
      cursor.useGramIndex,
      offset + limit + 1,
    );
    final pageIds = cursor.matchingIds
        .skip(offset)
        .take(limit)
        .toList(growable: false);
    if (pageIds.isEmpty) {
      if (!cursor.useGramIndex) {
        _database.startProductSearchIndexBuild();
      }
      return ProductResultsPage(
        products: const <Product>[],
        hasMore: !cursor.exhausted,
      );
    }
    final rows = await _queryProductRows(filter: filter, productIds: pageIds);
    if (!cursor.useGramIndex) {
      _database.startProductSearchIndexBuild();
    }
    return ProductResultsPage(
      products: _mapProducts(rows),
      hasMore:
          offset + pageIds.length < cursor.matchingIds.length ||
          !cursor.exhausted,
    );
  }

  @override
  Future<ProductStockCounts> getStockCounts() async {
    final rows = await _database.customSelect('''
      SELECT
        COALESCE(SUM(CASE WHEN COALESCE(stock_summary.quantity_on_hand, 0) > 0
          THEN 1 ELSE 0 END), 0)
          AS available_count,
        COALESCE(SUM(CASE WHEN COALESCE(stock_summary.quantity_on_hand, 0) > 0
          AND stock_summary.quantity_on_hand <= 10
          THEN 1 ELSE 0 END), 0) AS low_stock_count,
        COALESCE(SUM(CASE WHEN COALESCE(stock_summary.quantity_on_hand, 0) <= 0
          THEN 1 ELSE 0 END), 0)
          AS missing_count
      FROM products AS p
      LEFT JOIN product_stock_summary AS stock_summary
        ON stock_summary.product_id = p.id
      WHERE p.is_archived = 0
      LIMIT 1
    ''').get();
    final row = rows.single;
    return ProductStockCounts(
      available: row.read<int>('available_count'),
      lowStock: row.read<int>('low_stock_count'),
      missing: row.read<int>('missing_count'),
    );
  }

  Future<void> _ensureSearchResults(
    _ProductSearchCursor cursor,
    String search,
    ProductListFilter filter,
    List<Set<String>> wordGrams,
    bool useGramIndex,
    int requiredMatches,
  ) async {
    const candidateBatchSize = 240;
    while (!cursor.exhausted && cursor.matchingIds.length < requiredMatches) {
      final candidates = await _querySearchCandidates(
        wordGrams: wordGrams,
        filter: filter,
        useGramIndex: useGramIndex,
        limit: candidateBatchSize,
        offset: cursor.candidateOffset,
      );
      cursor.candidateOffset += candidates.length;
      for (final candidate in candidates) {
        if (matchesProductSearch(search, candidate.read<String>('name'))) {
          cursor.matchingIds.add(candidate.read<int>('id'));
        }
      }
      if (candidates.length < candidateBatchSize) cursor.exhausted = true;
    }
  }

  Future<List<QueryRow>> _querySearchCandidates({
    required List<Set<String>> wordGrams,
    required ProductListFilter filter,
    required bool useGramIndex,
    required int limit,
    required int offset,
  }) async {
    if (!useGramIndex) {
      return _database
          .customSelect(
            '''
        SELECT p.id, p.name
        FROM products AS p
        LEFT JOIN product_sales_summary AS sales_summary
          ON sales_summary.product_id = p.id
        LEFT JOIN product_stock_summary AS stock_summary
          ON stock_summary.product_id = p.id
        WHERE ${_productWhere(filter)} ${_productStockCondition(filter)}
        ORDER BY COALESCE(sales_summary.quantity_sold, 0) DESC,
                 p.name COLLATE NOCASE ASC, p.id ASC
        LIMIT ? OFFSET ?
        ''',
            variables: [Variable.withInt(limit), Variable.withInt(offset)],
          )
          .get();
    }

    final gramPairs = <(int, String)>[
      for (var wordIndex = 0; wordIndex < wordGrams.length; wordIndex++)
        for (final gram in wordGrams[wordIndex]) (wordIndex, gram),
    ];
    if (gramPairs.isEmpty) return const <QueryRow>[];
    final values = List<String>.filled(gramPairs.length, '(?, ?)').join(', ');
    final variables = <Variable>[
      for (final (wordIndex, gram) in gramPairs) ...[
        Variable.withInt(wordIndex),
        Variable.withString(gram),
      ],
      Variable.withInt(wordGrams.length),
      Variable.withInt(limit),
      Variable.withInt(offset),
    ];
    return _database.customSelect('''
          WITH query_grams(word_index, gram) AS (VALUES $values),
          matching_products AS (
            SELECT search_grams.product_id
            FROM product_search_grams AS search_grams
            INNER JOIN query_grams ON query_grams.gram = search_grams.gram
            GROUP BY search_grams.product_id
            HAVING COUNT(DISTINCT query_grams.word_index) = ?
          )
          SELECT p.id, p.name
          FROM matching_products AS candidates
          INNER JOIN products AS p ON p.id = candidates.product_id
          LEFT JOIN product_sales_summary AS sales_summary
            ON sales_summary.product_id = p.id
          LEFT JOIN product_stock_summary AS stock_summary
            ON stock_summary.product_id = p.id
          WHERE ${_productWhere(filter)} ${_productStockCondition(filter)}
          ORDER BY COALESCE(sales_summary.quantity_sold, 0) DESC,
                   p.name COLLATE NOCASE ASC, p.id ASC
          LIMIT ? OFFSET ?
          ''', variables: variables).get();
  }

  Future<List<QueryRow>> _queryProductRows({
    required ProductListFilter filter,
    int? limit,
    int offset = 0,
    List<int>? productIds,
  }) async {
    final variables = <Variable>[];
    final idCondition = productIds == null
        ? ''
        : ' AND p.id IN (${List<String>.filled(productIds.length, '?').join(', ')})';
    if (productIds != null) {
      variables.addAll(productIds.map(Variable.withInt));
    }
    final pagingClause = limit == null ? '' : 'LIMIT ? OFFSET ?';
    if (limit != null) {
      variables
        ..add(Variable.withInt(limit))
        ..add(Variable.withInt(offset));
    }
    return _database.customSelect('''
          SELECT
            p.id,
            p.name,
            p.purchase_price_minor,
            p.sale_price_minor,
            CAST(p.minimum_stock AS REAL) AS minimum_stock,
            p.code_value,
            p.code_type,
            p.created_at,
            p.updated_at,
            CAST(COALESCE(stock_summary.quantity_on_hand, 0) AS REAL)
              AS stock_on_hand
          FROM products AS p
          LEFT JOIN product_sales_summary AS sales_summary
            ON sales_summary.product_id = p.id
          LEFT JOIN product_stock_summary AS stock_summary
            ON stock_summary.product_id = p.id
          WHERE ${_productWhere(filter)}$idCondition
            ${_productStockCondition(filter)}
          ORDER BY COALESCE(sales_summary.quantity_sold, 0) DESC,
                   p.name COLLATE NOCASE ASC, p.id ASC
          $pagingClause
          ''', variables: variables).get();
  }

  List<Product> _mapProducts(List<QueryRow> rows) => rows
      .map(
        (row) => Product.fromDatabaseRow({
          'id': row.read<int>('id'),
          'name': row.read<String>('name'),
          'purchase_price_minor': row.read<int>('purchase_price_minor'),
          'sale_price_minor': row.read<int>('sale_price_minor'),
          'minimum_stock': row.read<double>('minimum_stock'),
          'code_value': row.readNullable<String>('code_value'),
          'code_type': row.readNullable<String>('code_type'),
          'created_at': row.read<String>('created_at'),
          'updated_at': row.read<String>('updated_at'),
          'stock_on_hand': row.read<double>('stock_on_hand'),
        }),
      )
      .toList(growable: false);

  String _productWhere(ProductListFilter filter) {
    final archivedOnly = filter == ProductListFilter.deleted;
    final conditions = <String>['p.is_archived = ${archivedOnly ? 1 : 0}'];
    const hasCode = "p.code_value IS NOT NULL AND TRIM(p.code_value) <> ''";
    switch (filter) {
      case ProductListFilter.withCode:
        conditions.add(hasCode);
      case ProductListFilter.withoutCode:
        conditions.add('NOT ($hasCode)');
      case ProductListFilter.available:
      case ProductListFilter.lowStock:
      case ProductListFilter.missing:
      case ProductListFilter.allActive:
      case ProductListFilter.deleted:
        break;
    }
    return conditions.join(' AND ');
  }

  String _productStockCondition(ProductListFilter filter) => switch (filter) {
    ProductListFilter.available ||
    ProductListFilter.withCode ||
    ProductListFilter.withoutCode =>
      'AND COALESCE(stock_summary.quantity_on_hand, 0) > 0',
    ProductListFilter.lowStock =>
      'AND COALESCE(stock_summary.quantity_on_hand, 0) > 0 '
          'AND stock_summary.quantity_on_hand <= 10',
    ProductListFilter.missing =>
      'AND COALESCE(stock_summary.quantity_on_hand, 0) <= 0',
    ProductListFilter.allActive || ProductListFilter.deleted => '',
  };

  @override
  void invalidateProductPages() => _searchResultIds.clear();

  void _invalidateSearchResults() => invalidateProductPages();

  @override
  Future<ProductCodeMatch?> findProductByCode(String code) async {
    final normalizedCode = code.trim();
    if (normalizedCode.isEmpty) return null;
    final rows = await _database
        .customSelect(
          '''
          SELECT
            p.id,
            p.name,
            p.purchase_price_minor,
            p.sale_price_minor,
            CAST(p.minimum_stock AS REAL) AS minimum_stock,
            p.code_value,
            p.code_type,
            p.created_at,
            p.updated_at,
            CAST(COALESCE(stock_summary.quantity_on_hand, 0) AS REAL)
              AS stock_on_hand,
            CAST(p.is_archived AS INTEGER) AS is_archived
          FROM products AS p
          LEFT JOIN product_stock_summary AS stock_summary
            ON stock_summary.product_id = p.id
          WHERE p.code_value = ?
          LIMIT 1
          ''',
          variables: [Variable.withString(normalizedCode)],
        )
        .get();
    if (rows.isEmpty) return null;
    final row = rows.single;
    return ProductCodeMatch(
      product: Product.fromDatabaseRow({
        'id': row.read<int>('id'),
        'name': row.read<String>('name'),
        'purchase_price_minor': row.read<int>('purchase_price_minor'),
        'sale_price_minor': row.read<int>('sale_price_minor'),
        'minimum_stock': row.read<double>('minimum_stock'),
        'code_value': row.readNullable<String>('code_value'),
        'code_type': row.readNullable<String>('code_type'),
        'created_at': row.read<String>('created_at'),
        'updated_at': row.read<String>('updated_at'),
        'stock_on_hand': row.read<double>('stock_on_hand'),
      }),
      isDeleted: row.read<int>('is_archived') != 0,
    );
  }

  @override
  Future<List<Product>> findUncodedActiveProducts({String search = ''}) async {
    final products = await getProducts(
      search: search,
      filter: ProductListFilter.allActive,
    );
    return products
        .where((product) => !product.hasCode)
        .toList(growable: false);
  }

  @override
  Future<void> assignCode(
    int productId,
    String code, {
    required String codeType,
  }) async {
    final normalizedCode = code.trim();
    if (normalizedCode.isEmpty) {
      throw ArgumentError('الكود لا يمكن أن يكون فارغًا.');
    }
    if (codeType != 'barcode' && codeType != 'qr') {
      throw ArgumentError('نوع الكود يجب أن يكون باركود أو QR.');
    }
    await _database.transaction(() async {
      final existing =
          await (_database.select(_database.products)
                ..where((table) => table.codeValue.equals(normalizedCode))
                ..limit(1))
              .get();
      if (existing.isNotEmpty) {
        throw StateError('هذا الباركود أو QR مرتبط بصنف آخر بالفعل.');
      }
      final changed =
          await (_database.update(_database.products)..where(
                (table) =>
                    table.id.equals(productId) &
                    table.isArchived.equals(false) &
                    (table.codeValue.isNull() | table.codeValue.equals('')),
              ))
              .write(
                ProductsCompanion(
                  codeValue: Value(normalizedCode),
                  codeType: Value(codeType),
                  updatedAt: Value(DateTime.now().toUtc().toIso8601String()),
                ),
              );
      if (changed != 1) {
        throw StateError('الصنف غير موجود أو أصبح مرتبطًا بكود آخر.');
      }
    });
    _invalidateSearchResults();
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

    final codeValue = product.codeValue?.trim();
    final codeType = codeValue == null || codeValue.isEmpty
        ? null
        : product.codeType;
    if (codeValue != null &&
        codeValue.isNotEmpty &&
        codeType != 'barcode' &&
        codeType != 'qr') {
      throw ArgumentError('نوع الكود يجب أن يكون باركود أو QR.');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction(() async {
      if (codeValue != null && codeValue.isNotEmpty) {
        final productsWithCode = await (_database.select(
          _database.products,
        )..where((table) => table.codeValue.equals(codeValue))).get();
        if (productsWithCode.any((row) => row.id != product.id)) {
          throw StateError('هذا الباركود أو QR مرتبط بصنف آخر بالفعل.');
        }
      }

      if (product.id == null) {
        final productId = await _database
            .into(_database.products)
            .insert(
              ProductsCompanion.insert(
                name: name,
                purchasePriceMinor: Value(product.purchasePriceMinor),
                averageCostMilliMinor: Value(product.purchasePriceMinor * 1000),
                averageCostReliable: const Value(true),
                salePriceMinor: Value(product.salePriceMinor),
                minimumStock: Value(product.minimumStock),
                codeValue: Value(
                  codeValue == null || codeValue.isEmpty ? null : codeValue,
                ),
                codeType: Value(codeType),
                createdAt: now,
                updatedAt: now,
              ),
            );

        if (product.stockOnHand > 0) {
          await _database
              .into(_database.stockMovements)
              .insert(
                StockMovementsCompanion.insert(
                  productId: productId,
                  quantityDelta: product.stockOnHand,
                  sourceType: 'opening_balance',
                  sourceId: Value('product:$productId'),
                  note: const Value('رصيد افتتاحي'),
                  occurredAt: now,
                ),
              );
        }
        await _replaceProductSearchGrams(productId, name);
        return;
      }

      final changed =
          await (_database.update(_database.products)..where(
                (table) =>
                    table.id.equals(product.id!) &
                    table.isArchived.equals(false),
              ))
              .write(
                ProductsCompanion(
                  name: Value(name),
                  purchasePriceMinor: Value(product.purchasePriceMinor),
                  salePriceMinor: Value(product.salePriceMinor),
                  minimumStock: Value(product.minimumStock),
                  codeValue: Value(
                    codeValue == null || codeValue.isEmpty ? null : codeValue,
                  ),
                  codeType: Value(codeType),
                  updatedAt: Value(now),
                ),
              );
      if (changed != 1) {
        throw StateError('المنتج غير موجود أو مؤرشف.');
      }
      await _replaceProductSearchGrams(product.id!, name);
    });
    _invalidateSearchResults();
  }

  Future<void> _replaceProductSearchGrams(int productId, String name) async {
    await (_database.delete(
      _database.productSearchGrams,
    )..where((table) => table.productId.equals(productId))).go();
    final grams = productSearchIndexGrams(name)
        .map(
          (gram) => ProductSearchGramsCompanion.insert(
            productId: productId,
            gram: gram,
          ),
        )
        .toList(growable: false);
    if (grams.isNotEmpty) {
      await _database.batch(
        (batch) => batch.insertAll(_database.productSearchGrams, grams),
      );
    }
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
    await _database.transaction(() async {
      final activeProduct =
          await (_database.select(_database.products)
                ..where(
                  (table) =>
                      table.id.equals(productId) &
                      table.isArchived.equals(false),
                )
                ..limit(1))
              .get();
      if (activeProduct.isEmpty) {
        throw StateError('المنتج غير موجود أو مؤرشف.');
      }

      final stockRows = await _database
          .customSelect(
            '''
        SELECT CAST(COALESCE(quantity_on_hand, 0) AS REAL) AS stock_on_hand
        FROM product_stock_summary
        WHERE product_id = ?
        LIMIT 1
        ''',
            variables: [Variable.withInt(productId)],
          )
          .get();
      final currentStock = stockRows.single.read<double>('stock_on_hand');
      final resultingStock = currentStock + quantityDelta;
      if (resultingStock < -0.0000001) {
        throw StateError('لا يمكن أن يصبح رصيد المخزون أقل من صفر.');
      }

      await _database
          .into(_database.stockMovements)
          .insert(
            StockMovementsCompanion.insert(
              productId: productId,
              quantityDelta: quantityDelta,
              sourceType: 'manual_adjustment',
              note: Value(note.trim().isEmpty ? null : note.trim()),
              occurredAt: now,
            ),
          );
    });
    _invalidateSearchResults();
  }

  @override
  Future<void> archive(int productId) async {
    final changed =
        await (_database.update(_database.products)..where(
              (table) =>
                  table.id.equals(productId) & table.isArchived.equals(false),
            ))
            .write(
              ProductsCompanion(
                isArchived: const Value(true),
                updatedAt: Value(DateTime.now().toUtc().toIso8601String()),
              ),
            );
    if (changed != 1) {
      throw StateError('المنتج غير موجود أو مؤرشف بالفعل.');
    }
    _invalidateSearchResults();
  }

  @override
  Future<void> restore(int productId) async {
    final changed =
        await (_database.update(_database.products)..where(
              (table) =>
                  table.id.equals(productId) & table.isArchived.equals(true),
            ))
            .write(
              ProductsCompanion(
                isArchived: const Value(false),
                updatedAt: Value(DateTime.now().toUtc().toIso8601String()),
              ),
            );
    if (changed != 1) {
      throw StateError('المنتج غير موجود في الأصناف المحذوفة.');
    }
    _invalidateSearchResults();
  }

  @override
  Future<void> deletePermanently(int productId) async {
    await _database.transaction(() async {
      final archivedProduct =
          await (_database.select(_database.products)
                ..where(
                  (table) =>
                      table.id.equals(productId) &
                      table.isArchived.equals(true),
                )
                ..limit(1))
              .get();
      if (archivedProduct.isEmpty) {
        throw StateError('لا يمكن الحذف النهائي إلا من الأصناف المحذوفة.');
      }

      await (_database.delete(
        _database.stockMovements,
      )..where((table) => table.productId.equals(productId))).go();
      final deleted = await (_database.delete(
        _database.products,
      )..where((table) => table.id.equals(productId))).go();
      if (deleted != 1) {
        throw StateError('تعذر حذف المنتج نهائيًا.');
      }
    });
    _invalidateSearchResults();
  }

  @override
  Future<List<StockMovement>> getMovements(int productId) async {
    final rows = await _database
        .customSelect(
          '''
      SELECT id, product_id, quantity_delta, source_type, note, occurred_at
      FROM stock_movements
      WHERE product_id = ?
      ORDER BY occurred_at DESC, id DESC
      ''',
          variables: [Variable.withInt(productId)],
        )
        .get();

    return rows
        .map(
          (row) => StockMovement.fromDatabaseRow({
            'id': row.read<int>('id'),
            'product_id': row.read<int>('product_id'),
            'quantity_delta': row.read<double>('quantity_delta'),
            'source_type': row.read<String>('source_type'),
            'note': row.readNullable<String>('note'),
            'occurred_at': row.read<String>('occurred_at'),
          }),
        )
        .toList(growable: false);
  }
}
