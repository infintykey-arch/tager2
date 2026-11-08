import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/data/local/app_database.dart';
import 'package:tager2/features/products/data/products_repository.dart';
import 'package:tager2/features/products/domain/product.dart';

void main() {
  late AppDatabase appDatabase;
  late DriftProductsRepository repository;

  setUp(() {
    appDatabase = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftProductsRepository(appDatabase);
  });

  tearDown(() => appDatabase.close());

  Product draft({
    String name = 'لبن',
    double stock = 5,
    double minimumStock = 2,
    String? codeValue,
    String? codeType,
  }) {
    return Product(
      name: name,
      purchasePriceMinor: 12345,
      salePriceMinor: 1575,
      minimumStock: minimumStock,
      stockOnHand: stock,
      codeValue: codeValue,
      codeType: codeType,
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

  test('يدعم البحث وتصنيفات المخزون وحدود الكود', () async {
    await repository.save(draft(name: 'لبن', stock: 1));
    await repository.save(
      draft(name: 'أرز', stock: 10, codeValue: '12345', codeType: 'barcode'),
    );
    await repository.save(draft(name: 'دقيق', stock: 0));
    await repository.save(draft(name: 'زيت', stock: 11));

    final search = await repository.getProducts(search: 'لبن');
    expect(search.map((product) => product.name), ['لبن']);

    final lowStock = await repository.getProducts(
      filter: ProductListFilter.lowStock,
    );
    expect(
      lowStock.map((product) => product.name),
      unorderedEquals(['لبن', 'أرز']),
    );

    final missing = await repository.getProducts(
      filter: ProductListFilter.missing,
    );
    expect(missing.map((product) => product.name), ['دقيق']);

    final available = await repository.getProducts();
    expect(
      available.map((product) => product.name),
      unorderedEquals(['لبن', 'أرز', 'زيت']),
    );

    final coded = await repository.getProducts(
      filter: ProductListFilter.withCode,
    );
    expect(coded.map((product) => product.name), ['أرز']);

    final uncoded = await repository.getProducts(
      filter: ProductListFilter.withoutCode,
    );
    expect(
      uncoded.map((product) => product.name),
      unorderedEquals(['لبن', 'زيت']),
    );
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

  test('النقل إلى المحذوفة قابل للاسترجاع ويحافظ على سجل الحركات', () async {
    await repository.save(draft());
    final product = (await repository.getProducts()).single;

    await repository.archive(product.id!);

    expect(await repository.getProducts(), isEmpty);
    expect(
      (await repository.getProducts(filter: ProductListFilter.deleted))
          .single
          .id,
      product.id,
    );
    expect(await repository.getMovements(product.id!), hasLength(1));

    await repository.restore(product.id!);
    expect((await repository.getProducts()).single.id, product.id);
    expect(await repository.getMovements(product.id!), hasLength(1));
  });

  test('الحذف النهائي متاح فقط من قائمة المحذوفة ويزيل سجل الحركة', () async {
    await repository.save(draft());
    final product = (await repository.getProducts()).single;

    await expectLater(
      repository.deletePermanently(product.id!),
      throwsA(isA<StateError>()),
    );
    expect(await repository.getMovements(product.id!), hasLength(1));

    await repository.archive(product.id!);
    await repository.deletePermanently(product.id!);

    expect(
      await repository.getProducts(filter: ProductListFilter.deleted),
      isEmpty,
    );
    expect(await repository.getMovements(product.id!), isEmpty);
  });

  test('يرفض ربط كود واحد بأكثر من صنف ويسمح بحفظ تحديث الصنف نفسه', () async {
    await repository.save(
      draft(name: 'منتج له كود', codeValue: 'ABC-123', codeType: 'barcode'),
    );
    final original = (await repository.getProducts()).single;
    await repository.save(
      Product(
        id: original.id,
        name: original.name,
        purchasePriceMinor: original.purchasePriceMinor,
        salePriceMinor: original.salePriceMinor + 100,
        minimumStock: original.minimumStock,
        stockOnHand: original.stockOnHand,
        codeValue: original.codeValue,
        codeType: original.codeType,
      ),
    );

    await expectLater(
      repository.save(
        draft(name: 'محاولة تكرار', codeValue: 'ABC-123', codeType: 'qr'),
      ),
      throwsA(isA<StateError>()),
    );
    expect(await repository.getProducts(), hasLength(1));
    expect((await repository.getProducts()).single.salePriceMinor, 1675);
  });

  test('يربط كودًا ممسوحًا ويكتشف المنتج المحذوف ويمنع تكرار الربط', () async {
    await repository.save(draft(name: 'صنف بلا مخزون', stock: 0));
    final first = (await repository.getProducts(
      filter: ProductListFilter.allActive,
    )).single;
    await repository.assignCode(first.id!, 'QR-456', codeType: 'qr');

    final match = await repository.findProductByCode(' QR-456 ');
    expect(match?.product.name, 'صنف بلا مخزون');
    expect(match?.isDeleted, isFalse);
    expect(await repository.findUncodedActiveProducts(), isEmpty);

    await repository.save(draft(name: 'صنف آخر بلا كود', stock: 1));
    final uncoded = await repository.findUncodedActiveProducts();
    expect(uncoded.map((product) => product.name), ['صنف آخر بلا كود']);
    await expectLater(
      repository.assignCode(uncoded.single.id!, 'QR-456', codeType: 'barcode'),
      throwsA(isA<StateError>()),
    );

    await repository.archive(first.id!);
    final deletedMatch = await repository.findProductByCode('QR-456');
    expect(deletedMatch?.isDeleted, isTrue);
    expect(deletedMatch?.product.salePriceMinor, 1575);
  });
}
