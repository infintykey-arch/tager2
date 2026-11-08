import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/data/local/app_database.dart';
import 'package:tager2/features/analytics/data/report_repository.dart';
import 'package:tager2/features/products/data/products_repository.dart';
import 'package:tager2/features/products/domain/product.dart';
import 'package:tager2/features/purchases/data/purchases_repository.dart';
import 'package:tager2/features/sales/data/sales_repository.dart';

void main() {
  late AppDatabase database;
  late DriftProductsRepository products;
  late DriftPurchasesRepository purchases;
  late DriftSalesRepository sales;
  late LocalReportRepository reports;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    products = DriftProductsRepository(database);
    purchases = DriftPurchasesRepository(database);
    sales = DriftSalesRepository(database);
    reports = LocalReportRepository(database);
  });

  tearDown(() => database.close());

  test(
    'أول شراء يحدد تكلفة انتقالية للقديم ويحفظ المبيعات السابقة كما هي',
    () async {
      await products.save(
        const Product(
          name: 'صنف قديم',
          purchasePriceMinor: 2000,
          salePriceMinor: 5000,
          minimumStock: 0,
          stockOnHand: 10,
        ),
      );
      final productId = (await products.getProducts()).single.id!;
      await (database.update(database.products)
            ..where((row) => row.id.equals(productId)))
          .write(const ProductsCompanion(averageCostReliable: Value(false)));

      final baseTime = DateTime.now().toUtc().add(const Duration(minutes: 1));
      final oldSale = await sales.createSale(
        SaleDraft(
          lines: [SaleLineDraft(productId: productId, quantity: 1)],
          paymentKind: SalePaymentKind.cash,
          requestKey: 'legacy-before-transition',
          occurredAt: baseTime,
        ),
      );
      expect(oldSale.lines.single.unitCostMilliMinor, isNull);
      expect(oldSale.lines.single.costTotalMinor, isNull);

      final purchaseTime = baseTime.add(const Duration(days: 1));
      await purchases.createPurchase(
        PurchaseDraft(
          supplierName: 'المورد الجديد',
          lines: [
            PurchaseLineDraft(
              productId: productId,
              productName: 'صنف قديم',
              purchasePriceMinor: 3000,
              salePriceMinor: 5000,
              quantity: 2,
            ),
            PurchaseLineDraft(
              productId: productId,
              productName: 'صنف قديم',
              purchasePriceMinor: 4000,
              salePriceMinor: 5000,
              quantity: 3,
            ),
          ],
          amountPaidMinor: 18000,
          requestKey: 'legacy-transition-purchase',
          occurredAt: purchaseTime,
        ),
      );

      final currentProduct = await database
          .select(database.products)
          .getSingle();
      expect(currentProduct.averageCostReliable, isTrue);
      expect(currentProduct.averageCostMilliMinor, 3600000);

      final transition = (await products.getMovements(productId))
          .singleWhere((movement) => movement.sourceType == 'cost_transition');
      expect(transition.quantityDelta, 0);
      expect(transition.note, contains('P-'));
      expect(transition.note, contains('لم تتغير تكاليف المبيعات السابقة'));

      final nextSale = await sales.createSale(
        SaleDraft(
          lines: [SaleLineDraft(productId: productId, quantity: 1)],
          paymentKind: SalePaymentKind.cash,
          requestKey: 'sale-after-transition',
          occurredAt: purchaseTime.add(const Duration(days: 1)),
        ),
      );
      expect(nextSale.lines.single.unitCostMilliMinor, 3600000);
      expect(nextSale.lines.single.costTotalMinor, 3600);

      final rereadOldSale = (await sales.getSale(oldSale.id))!;
      expect(rereadOldSale.lines.single.unitCostMilliMinor, isNull);
      expect(rereadOldSale.lines.single.costTotalMinor, isNull);

      final oldSaleTime = oldSale.createdAt;
      final oldReport = await reports.getSummary(
        DateTime(oldSaleTime.year, oldSaleTime.month, oldSaleTime.day),
        DateTime(oldSaleTime.year, oldSaleTime.month, oldSaleTime.day + 1),
      );
      expect(oldReport.unknownCostLineCount, 1);
      expect(oldReport.netProfitMinor, isNull);

      final newSaleTime = nextSale.createdAt;
      final newReport = await reports.getSummary(
        DateTime(newSaleTime.year, newSaleTime.month, newSaleTime.day),
        DateTime(newSaleTime.year, newSaleTime.month, newSaleTime.day + 1),
      );
      expect(newReport.unknownCostLineCount, 0);
      expect(newReport.netProfitMinor, 1400);

      final purchaseHistory = await database
          .select(database.purchaseLines)
          .get();
      expect(purchaseHistory.map((line) => line.purchasePriceMinor), [
        3000,
        4000,
      ]);
    },
  );
}
