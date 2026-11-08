import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/features/products/data/products_repository.dart';
import 'package:tager2/features/products/domain/product.dart';
import 'package:tager2/features/products/presentation/products_page.dart';
import 'package:tager2/features/sales/data/sales_repository.dart';

void main() {
  testWidgets('يحمل بطاقة المنتجات عند الحاجة ويضيف الصفحة التالية بالتمرير', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _PagedProductsRepository(
      List<Product>.generate(
        120,
        (index) => Product(
          id: index + 1,
          name: 'منتج ${index + 1}',
          purchasePriceMinor: 100,
          salePriceMinor: 150,
          minimumStock: 1,
          stockOnHand: 5,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductsPage(
            refreshToken: 0,
            repository: repository,
            salesRepository: _UnusedSalesRepository(),
            onDataChanged: () {},
            onAddProduct: () {},
            onOpenMissing: () {},
            onOpenLowStock: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.requestedOffsets, [0]);
    expect(find.byKey(const ValueKey('product-card-1')), findsOneWidget);
    expect(find.text('منتج 1'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -5000));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.requestedOffsets, [0, 60]);
  });
}

class _PagedProductsRepository
    implements ProductsRepository, ProductPagingRepository {
  _PagedProductsRepository(this.products);

  final List<Product> products;
  final requestedOffsets = <int>[];

  @override
  Future<ProductResultsPage> getProductsPage({
    String search = '',
    ProductListFilter filter = ProductListFilter.available,
    int offset = 0,
    int limit = 60,
  }) async {
    requestedOffsets.add(offset);
    final page = products.skip(offset).take(limit).toList(growable: false);
    return ProductResultsPage(
      products: page,
      hasMore: offset + page.length < products.length,
    );
  }

  @override
  Future<ProductStockCounts> getStockCounts() async =>
      const ProductStockCounts(available: 120, lowStock: 120, missing: 0);

  @override
  void invalidateProductPages() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedSalesRepository implements SalesRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
