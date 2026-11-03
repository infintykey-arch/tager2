import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tager2/data/local/app_database.dart';
import 'package:tager2/features/products/data/products_repository.dart';
import 'package:tager2/features/products/domain/product.dart';

void main() {
  late AppDatabase appDatabase;
  late SqliteProductsRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    appDatabase = await AppDatabase.open(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    repository = SqliteProductsRepository(appDatabase.database);
  });

  tearDown(() => appDatabase.close());

  Product draft({
    String name = 'لبن',
    double stock = 5,
    double minimumStock = 2,
  }) {
    return Product(
      name: name,
      purchasePriceMinor: 12345,
      salePriceMinor: 1575,
      minimumStock: minimumStock,
      stockOnHand: stock,
    );
  }

  test('يحفظ المنتج والرصيد الافتتاحي في سجل الحركة', () async {
    await repository.save(draft());

    final products = await repository.getProducts();
    expect(products, hasLength(1));
    expect(products.single.name, 'لبن');
    expect(products.single.purchasePriceMinor, 12345);
    expect(products.single.salePriceMinor, 1575);
    expect(products.single.stockOnHand, 5);

    final movements = await repository.getMovements(products.single.id!);
    expect(movements, hasLength(1));
    expect(movements.single.sourceType, 'opening_balance');
    expect(movements.single.quantityDelta, 5);
  });

  test('يدعم البحث والتنبيه عند بلوغ الحد الأدنى', () async {
    await repository.save(draft(name: 'لبن', stock: 2, minimumStock: 2));
    await repository.save(draft(name: 'أرز', stock: 8, minimumStock: 2));

    final search = await repository.getProducts(search: 'لبن');
    expect(search.map((product) => product.name), ['لبن']);

    final lowStock = await repository.getProducts(lowStockOnly: true);
    expect(lowStock.map((product) => product.name), ['لبن']);
  });

  test('تسوية المخزون ذرية وترفض إنشاء رصيد سالب', () async {
    await repository.save(draft(stock: 5));
    final product = (await repository.getProducts()).single;

    await repository.adjustStock(product.id!, -2, note: 'تالف');
    expect((await repository.getProducts()).single.stockOnHand, 3);

    await expectLater(
      repository.adjustStock(product.id!, -4, note: 'تالف'),
      throwsA(isA<StateError>()),
    );

    expect((await repository.getProducts()).single.stockOnHand, 3);
    expect(await repository.getMovements(product.id!), hasLength(2));
  });

  test('الأرشفة تخفي المنتج النشط ولا تحذف سجل حركاته', () async {
    await repository.save(draft());
    final product = (await repository.getProducts()).single;

    await repository.archive(product.id!);

    expect(await repository.getProducts(), isEmpty);
    expect(await repository.getMovements(product.id!), hasLength(1));
  });
}
