import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/core/formatters.dart';
import 'package:tager2/data/local/app_database.dart';
import 'package:tager2/features/products/data/products_repository.dart';
import 'package:tager2/features/products/domain/product.dart';
import 'package:tager2/features/products/presentation/products_page.dart';
import 'package:tager2/features/sales/data/sales_repository.dart';

void main() {
  testWidgets('يعرض أسماء الأصناف الطويلة كاملة مع السعر والكمية على الهاتف', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final products = DriftProductsRepository(database);
    final sales = DriftSalesRepository(database);

    const sunflowerOil =
        'زيت نباتي بكر ممتاز معصور على البارد عبوة عائلية سعة لتر ونصف';
    const egyptianRice =
        'أرز مصري فاخر حبة متوسطة درجة أولى عبوة خمسة كيلوغرامات';
    await products.save(
      const Product(
        name: sunflowerOil,
        purchasePriceMinor: 9800,
        salePriceMinor: 12500,
        minimumStock: 5,
        stockOnHand: 27.5,
      ),
    );
    await products.save(
      const Product(
        name: egyptianRice,
        purchasePriceMinor: 14500,
        salePriceMinor: 18250,
        minimumStock: 4,
        stockOnHand: 18,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductsPage(
            refreshToken: 0,
            repository: products,
            salesRepository: sales,
            onDataChanged: () {},
            onAddProduct: () {},
            onOpenMissing: () {},
            onOpenLowStock: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final name in [sunflowerOil, egyptianRice]) {
      final nameText = tester.widget<Text>(find.text(name));
      expect(nameText.maxLines, isNull);
      expect(nameText.overflow, isNull);
      expect(nameText.softWrap, isTrue);
    }
    expect(find.text(formatMoneyMinor(12500)), findsOneWidget);
    expect(find.text(formatMoneyMinor(18250)), findsOneWidget);
    expect(find.text('27.5'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('سعر البيع'), findsNWidgets(2));
    expect(find.text('المتاح'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
