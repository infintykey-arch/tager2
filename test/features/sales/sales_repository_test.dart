import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/data/local/app_database.dart';
import 'package:tager2/features/products/data/products_repository.dart';
import 'package:tager2/features/products/domain/product.dart';
import 'package:tager2/features/sales/data/sales_repository.dart';

void main() {
  late AppDatabase database;
  late DriftProductsRepository products;
  late DriftSalesRepository sales;
  late int milkId;

  Product product({
    required String name,
    required double stock,
    int salePriceMinor = 1250,
  }) {
    return Product(
      name: name,
      purchasePriceMinor: 800,
      salePriceMinor: salePriceMinor,
      minimumStock: 2,
      stockOnHand: stock,
    );
  }

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    products = DriftProductsRepository(database);
    sales = DriftSalesRepository(database);
    await products.save(product(name: 'لبن', stock: 5));
    milkId = (await products.getProducts()).single.id!;
  });

  tearDown(() => database.close());

  test('البيع النقدي يسجل الفاتورة والدفعة ويخصم المخزون', () async {
    final receipt = await sales.createSale(
      SaleDraft(
        lines: [SaleLineDraft(productId: milkId, quantity: 2)],
        paymentKind: SalePaymentKind.cash,
        requestKey: 'cash-sale-1',
        occurredAt: DateTime.utc(2026, 11, 5, 8),
      ),
    );

    expect(receipt.invoiceNumber, startsWith('S-20261105-'));
    expect(receipt.lines, hasLength(1));
    expect(receipt.totalMinor, 2500);
    expect(receipt.paidMinor, 2500);
    expect(receipt.remainingMinor, 0);
    expect((await products.getProducts()).single.stockOnHand, 3);
    final movements = await products.getMovements(milkId);
    expect(movements, hasLength(2));
    final saleMovement = movements.singleWhere(
      (movement) => movement.sourceType == 'sale',
    );
    expect(saleMovement.quantityDelta, -2);
  });

  test('تجميع السطر المكرر ومفتاح التأكيد يمنعان تكرار البيع', () async {
    final draft = SaleDraft(
      lines: [
        SaleLineDraft(productId: milkId, quantity: 1),
        SaleLineDraft(productId: milkId, quantity: 2),
      ],
      paymentKind: SalePaymentKind.cash,
      requestKey: 'cash-sale-repeat',
    );

    final first = await sales.createSale(draft);
    final second = await sales.createSale(draft);

    expect(first.id, second.id);
    expect(first.lines, hasLength(1));
    expect(first.lines.single.quantity, 3);
    expect(first.totalMinor, 3750);
    expect((await products.getProducts()).single.stockOnHand, 2);
  });

  test('البيع الآجل يسجل اسم العميل والدفعات والمتبقي', () async {
    final receipt = await sales.createSale(
      SaleDraft(
        lines: [SaleLineDraft(productId: milkId, quantity: 2)],
        paymentKind: SalePaymentKind.credit,
        customerName: '  أحمد علي  ',
        amountPaidMinor: 500,
        requestKey: 'credit-sale-1',
      ),
    );

    expect(receipt.customerName, 'أحمد علي');
    expect(receipt.totalMinor, 2500);
    expect(receipt.paidMinor, 500);
    expect(receipt.remainingMinor, 2000);
    expect(receipt.payments, hasLength(1));
    expect(receipt.payments.single.amountMinor, 500);
    expect(await sales.getOpenCreditSales(), hasLength(1));

    final updated = await sales.addPayment(
      saleId: receipt.id,
      amountMinor: 800,
      requestKey: 'credit-payment-1',
    );
    expect(updated.paidMinor, 1300);
    expect(updated.remainingMinor, 1200);
    expect(updated.payments, hasLength(2));
    expect(updated.payments.map((payment) => payment.amountMinor), [500, 800]);

    final repeated = await sales.addPayment(
      saleId: receipt.id,
      amountMinor: 800,
      requestKey: 'credit-payment-1',
    );
    expect(repeated.paidMinor, 1300);
    expect(repeated.remainingMinor, 1200);

    await expectLater(
      sales.addPayment(
        saleId: receipt.id,
        amountMinor: 1300,
        requestKey: 'credit-payment-too-much',
      ),
      throwsA(isA<StateError>()),
    );
    expect((await sales.getSale(receipt.id))!.paidMinor, 1300);

    await sales.addPayment(
      saleId: receipt.id,
      amountMinor: 1200,
      requestKey: 'credit-payment-complete',
    );
    expect(await sales.getOpenCreditSales(), isEmpty);
  });

  test(
    'يرفض البيع بأكثر من المتاح دون حفظ الفاتورة أو تغيير المخزون',
    () async {
      await products.save(product(name: 'أرز', stock: 1));
      final rice = (await products.getProducts(search: 'أرز')).single;

      await expectLater(
        sales.createSale(
          SaleDraft(
            lines: [
              SaleLineDraft(productId: milkId, quantity: 1),
              SaleLineDraft(productId: rice.id!, quantity: 2),
            ],
            paymentKind: SalePaymentKind.cash,
            requestKey: 'oversell',
          ),
        ),
        throwsA(isA<StateError>()),
      );

      expect((await products.getProducts(search: 'لبن')).single.stockOnHand, 5);
      expect((await products.getProducts(search: 'أرز')).single.stockOnHand, 1);
      expect(await products.getMovements(milkId), hasLength(1));
    },
  );

  test('يتطلب اسم العميل للبيع الآجل ويرفض دفعة أعلى من الإجمالي', () async {
    final missingCustomer = SaleDraft(
      lines: [SaleLineDraft(productId: milkId, quantity: 1)],
      paymentKind: SalePaymentKind.credit,
      requestKey: 'credit-no-customer',
    );
    await expectLater(
      sales.createSale(missingCustomer),
      throwsA(isA<ArgumentError>()),
    );

    final overpayment = SaleDraft(
      lines: [SaleLineDraft(productId: milkId, quantity: 1)],
      paymentKind: SalePaymentKind.credit,
      customerName: 'عميل',
      amountPaidMinor: 1251,
      requestKey: 'credit-overpayment',
    );
    await expectLater(
      sales.createSale(overpayment),
      throwsA(isA<ArgumentError>()),
    );
    expect((await products.getProducts()).single.stockOnHand, 5);
  });

  test('حذف المنتج نهائيًا يبقي اسم الصنف وسطر الفاتورة التاريخية', () async {
    final receipt = await sales.createSale(
      SaleDraft(
        lines: [SaleLineDraft(productId: milkId, quantity: 1)],
        paymentKind: SalePaymentKind.cash,
        requestKey: 'sale-before-delete',
      ),
    );

    await products.archive(milkId);
    await products.deletePermanently(milkId);

    final historical = await sales.getSale(receipt.id);
    expect(historical, isNotNull);
    expect(historical!.lines.single.productName, 'لبن');
    expect(historical.lines.single.productId, isNull);
    expect(historical.totalMinor, 1250);
  });
}
