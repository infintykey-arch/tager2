import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/app/tager_app.dart';
import 'package:tager2/features/products/data/products_repository.dart';
import 'package:tager2/features/products/domain/product.dart';

void main() {
  testWidgets('يعرض واجهة عربية باتجاه RTL وحالة البداية الفارغة', (
    tester,
  ) async {
    await tester.pumpWidget(
      const TagerApp(productsRepository: _EmptyProductsRepository()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('إدارة محلك من مكان واحد'), findsOneWidget);
    expect(find.text('إضافة أول منتج'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('إدارة محلك من مكان واحد'))),
      TextDirection.rtl,
    );

    await tester.tap(find.text('المنتجات').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('لا توجد منتجات بعد'), findsOneWidget);
    expect(find.text('إضافة منتج'), findsOneWidget);
  });
}

class _EmptyProductsRepository implements ProductsRepository {
  const _EmptyProductsRepository();

  @override
  Future<List<Product>> getProducts({
    String search = '',
    bool lowStockOnly = false,
  }) async => const [];

  @override
  Future<void> save(Product product) async {}

  @override
  Future<void> adjustStock(
    int productId,
    double quantityDelta, {
    required String note,
  }) async {}

  @override
  Future<void> archive(int productId) async {}

  @override
  Future<List<StockMovement>> getMovements(int productId) async => const [];
}
