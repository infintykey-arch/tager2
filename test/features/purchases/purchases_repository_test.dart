import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/data/local/app_database.dart';
import 'package:tager2/features/products/data/products_repository.dart';
import 'package:tager2/features/products/domain/product.dart';
import 'package:tager2/features/purchases/data/purchases_repository.dart';

void main() {
  late AppDatabase database;
  late DriftProductsRepository products;
  late DriftPurchasesRepository purchases;
  late int milkId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    products = DriftProductsRepository(database);
    purchases = DriftPurchasesRepository(database);
    await products.save(
      const Product(
        name: 'لبن',
        purchasePriceMinor: 800,
        salePriceMinor: 1250,
        minimumStock: 2,
        stockOnHand: 5,
      ),
    );
    milkId = (await products.getProducts()).single.id!;
  });

  tearDown(() => database.close());

  test('فاتورة المورد تنشئ منتجًا وتضيف المخزون وتسجل المتبقي', () async {
    final receipt = await purchases.createPurchase(
      PurchaseDraft(
        supplierName: 'مخزن النور',
        lines: const [
          PurchaseLineDraft(
            productName: 'أرز',
            purchasePriceMinor: 900,
            salePriceMinor: 1500,
            quantity: 2,
          ),
        ],
        amountPaidMinor: 500,
        requestKey: 'purchase-new-product-1',
        occurredAt: DateTime.utc(2026, 11, 4, 8),
      ),
    );

    expect(receipt.invoiceNumber, startsWith('P-20261104-'));
    expect(receipt.supplierName, 'مخزن النور');
    expect(receipt.totalMinor, 1800);
    expect(receipt.paidMinor, 500);
    expect(receipt.remainingMinor, 1300);
    expect(receipt.lines, hasLength(1));
    expect(receipt.lines.single.productName, 'أرز');
    expect(receipt.payments, hasLength(1));
    expect(receipt.payments.single.amountMinor, 500);

    final rice = (await products.getProducts(search: 'أرز')).single;
    expect(rice.stockOnHand, 2);
    expect(rice.purchasePriceMinor, 900);
    expect(rice.salePriceMinor, 1500);
    expect(
      (await products.getMovements(rice.id!)).single.sourceType,
      'purchase',
    );
    expect(await database.select(database.suppliers).get(), hasLength(1));
  });

  test('شراء صنف موجود يضيف الكمية ويحدث سعر الشراء والبيع الحالي', () async {
    final receipt = await purchases.createPurchase(
      PurchaseDraft(
        supplierName: 'شركة التوزيع',
        lines: [
          PurchaseLineDraft(
            productId: milkId,
            productName: 'لبن',
            purchasePriceMinor: 1000,
            salePriceMinor: 1500,
            quantity: 2,
          ),
        ],
        amountPaidMinor: 0,
        requestKey: 'purchase-existing-1',
      ),
    );

    final milk = (await products.getProducts()).single;
    expect(milk.stockOnHand, 7);
    expect(milk.purchasePriceMinor, 1000);
    expect(milk.salePriceMinor, 1500);
    expect(receipt.totalMinor, 2000);
    expect(receipt.remainingMinor, 2000);
    expect((await products.getMovements(milkId)).first.sourceType, 'purchase');
  });

  test(
    'يرفض الشراء بتاريخ أسبق من آخر حركة مخزون بدل إعادة تقييم الماضي',
    () async {
      final lastMovement = (await products.getMovements(milkId)).first;

      await expectLater(
        purchases.createPurchase(
          PurchaseDraft(
            supplierName: 'مورد بتاريخ سابق',
            lines: [
              PurchaseLineDraft(
                productId: milkId,
                productName: 'لبن',
                purchasePriceMinor: 1000,
                salePriceMinor: 1500,
                quantity: 1,
              ),
            ],
            amountPaidMinor: 0,
            requestKey: 'backdated-purchase-rejected',
            occurredAt: lastMovement.occurredAt.subtract(
              const Duration(seconds: 1),
            ),
          ),
        ),
        throwsA(isA<StateError>()),
      );

      expect((await products.getProducts()).single.stockOnHand, 5);
      expect(await database.select(database.purchaseLines).get(), isEmpty);
    },
  );

  test(
    'تكرار إرسال الفاتورة لا يكرر المخزون والدفعة قابلة للتكرار بأمان',
    () async {
      final draft = PurchaseDraft(
        supplierName: 'مورد واحد',
        lines: [
          PurchaseLineDraft(
            productId: milkId,
            productName: 'لبن',
            purchasePriceMinor: 900,
            salePriceMinor: 1400,
            quantity: 2,
          ),
        ],
        amountPaidMinor: 500,
        requestKey: 'purchase-repeat',
      );
      final first = await purchases.createPurchase(draft);
      final repeated = await purchases.createPurchase(draft);
      expect(repeated.id, first.id);
      expect((await products.getProducts()).single.stockOnHand, 7);
      expect(await purchases.getOpenPurchases(), hasLength(1));

      final paid = await purchases.addPayment(
        purchaseId: first.id,
        amountMinor: 700,
        requestKey: 'supplier-payment-1',
      );
      expect(paid.paidMinor, 1200);
      expect(paid.remainingMinor, 1800 - 1200);

      final duplicatePayment = await purchases.addPayment(
        purchaseId: first.id,
        amountMinor: 700,
        requestKey: 'supplier-payment-1',
      );
      expect(duplicatePayment.paidMinor, 1200);
      expect(await purchases.getOpenPurchases(), hasLength(1));

      await expectLater(
        purchases.addPayment(
          purchaseId: first.id,
          amountMinor: 700,
          requestKey: 'supplier-overpayment',
        ),
        throwsA(isA<StateError>()),
      );
      expect((await purchases.getPurchase(first.id))!.paidMinor, 1200);

      await purchases.addPayment(
        purchaseId: first.id,
        amountMinor: 600,
        requestKey: 'supplier-payment-complete',
      );
      expect(await purchases.getOpenPurchases(), isEmpty);
    },
  );

  test('رفض المبلغ الزائد يتراجع عن المنتج والمورد والحركة كلها', () async {
    await expectLater(
      purchases.createPurchase(
        const PurchaseDraft(
          supplierName: 'مورد غير محفوظ',
          lines: [
            PurchaseLineDraft(
              productName: 'سلعة تجريبية',
              purchasePriceMinor: 100,
              salePriceMinor: 200,
              quantity: 1,
            ),
          ],
          amountPaidMinor: 101,
          requestKey: 'invalid-purchase',
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );

    expect(await products.getProducts(search: 'سلعة تجريبية'), isEmpty);
    expect(await database.select(database.suppliers).get(), isEmpty);
    expect((await products.getProducts()).single.stockOnHand, 5);
  });

  test('حذف المنتج لا يحذف سطر فاتورة الشراء التاريخية', () async {
    final receipt = await purchases.createPurchase(
      PurchaseDraft(
        supplierName: 'مورد الحليب',
        lines: [
          PurchaseLineDraft(
            productId: milkId,
            productName: 'لبن',
            purchasePriceMinor: 900,
            salePriceMinor: 1300,
            quantity: 1,
          ),
        ],
        amountPaidMinor: 0,
        requestKey: 'purchase-before-delete',
      ),
    );

    await products.archive(milkId);
    await products.deletePermanently(milkId);

    final historical = await purchases.getPurchase(receipt.id);
    expect(historical, isNotNull);
    expect(historical!.lines.single.productName, 'لبن');
    expect(historical.lines.single.productId, isNull);
    expect(historical.lines.single.lineTotalMinor, 900);
  });
}
