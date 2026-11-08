import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/data/local/app_database.dart';
import 'package:tager2/features/products/data/products_repository.dart';
import 'package:tager2/features/products/domain/product.dart';
import 'package:tager2/features/scanner/presentation/product_code_binding_sheet.dart';

void main() {
  late AppDatabase database;
  late DriftProductsRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftProductsRepository(database);
  });

  tearDown(() => database.close());

  testWidgets('يربط الكود الممسوح بصنف غير مرتبط ثم يعثر عليه', (tester) async {
    await repository.save(
      const Product(
        name: 'قهوة',
        purchasePriceMinor: 12000,
        salePriceMinor: 15000,
        minimumStock: 2,
        stockOnHand: 5,
      ),
    );
    final product = (await repository.findUncodedActiveProducts()).single;
    Product? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () {
                  showModalBottomSheet<Product>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => FractionallySizedBox(
                      heightFactor: 0.85,
                      child: ProductCodeBindingSheet(
                        repository: repository,
                        code: 'QR-TEST-789',
                        codeType: 'qr',
                      ),
                    ),
                  ).then((value) => selected = value);
                },
                child: const Text('افتح الربط'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('افتح الربط'));
    await tester.pumpAndSettle();
    expect(find.text('هذا الـ QR أو الباركود غير معرّف'), findsOneWidget);
    await tester.tap(find.text('قهوة'));
    await tester.pumpAndSettle();

    expect(selected?.id, product.id);
    final match = await repository.findProductByCode('QR-TEST-789');
    expect(match?.product.name, 'قهوة');
    expect(match?.product.codeType, 'qr');
  });
}
