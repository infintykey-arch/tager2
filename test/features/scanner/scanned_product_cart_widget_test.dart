import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/data/local/app_database.dart';
import 'package:tager2/features/products/data/products_repository.dart';
import 'package:tager2/features/products/domain/product.dart';
import 'package:tager2/features/products/presentation/products_page.dart';
import 'package:tager2/features/sales/data/sales_repository.dart';

void main() {
  late AppDatabase database;
  late DriftProductsRepository products;
  late DriftSalesRepository sales;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    products = DriftProductsRepository(database);
    sales = DriftSalesRepository(database);
  });

  tearDown(() => database.close());

  testWidgets('يضيف نتيجة المسح إلى سطر واحد ويمنع تجاوز الرصيد', (
    tester,
  ) async {
    await products.save(
      const Product(
        name: 'أرز',
        purchasePriceMinor: 12000,
        salePriceMinor: 15000,
        minimumStock: 2,
        stockOnHand: 5,
      ),
    );
    final product = (await products.getProducts()).single;
    final key = GlobalKey<ProductsPageState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductsPage(
            key: key,
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

    key.currentState!.addScannedProduct(product, quantity: 2);
    key.currentState!.addScannedProduct(product, quantity: 3);
    key.currentState!.addScannedProduct(product, quantity: 1);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('مراجعة الفاتورة (1)'));
    await tester.pumpAndSettle();

    expect(find.text('فاتورة بيع جديدة'), findsOneWidget);
    expect(find.text('أرز'), findsNWidgets(2));
    expect(find.text('5'), findsNWidgets(3));
    expect(find.textContaining('المتاح من «أرز» هو 5 فقط.'), findsOneWidget);
  });
}
