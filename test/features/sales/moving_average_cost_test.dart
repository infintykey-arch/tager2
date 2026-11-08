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
    'المتوسط الموزون وسعر التكلفة في البيع يظلان ثابتين بعد شراء لاحق',
    () async {
      await products.save(
        const Product(
          name: 'صنف تجريبي',
          purchasePriceMinor: 2000,
          salePriceMinor: 5000,
          minimumStock: 0,
          stockOnHand: 10,
        ),
      );
      final productId = (await products.getProducts()).single.id!;
      final firstPurchaseAt = DateTime.now().add(const Duration(days: 1));

      await purchases.createPurchase(
        PurchaseDraft(
          supplierName: 'مورد أول',
          lines: [
            PurchaseLineDraft(
              productId: productId,
              productName: 'صنف تجريبي',
              purchasePriceMinor: 3000,
              salePriceMinor: 5000,
              quantity: 10,
            ),
          ],
          amountPaidMinor: 30000,
          requestKey: 'weighted-average-first-purchase',
          occurredAt: firstPurchaseAt,
        ),
      );
      expect(
        (await database.select(database.products).getSingle())
            .averageCostMilliMinor,
        2500000,
      );
      final productBeforeReferenceEdit = (await products.getProducts()).single;
      await products.save(
        Product(
          id: productBeforeReferenceEdit.id,
          name: productBeforeReferenceEdit.name,
          purchasePriceMinor: 6000,
          salePriceMinor: productBeforeReferenceEdit.salePriceMinor,
          minimumStock: productBeforeReferenceEdit.minimumStock,
          stockOnHand: productBeforeReferenceEdit.stockOnHand,
        ),
      );
      expect(
        (await database.select(database.products).getSingle())
            .averageCostMilliMinor,
        2500000,
      );

      final saleAt = firstPurchaseAt.add(const Duration(days: 1));
      final firstSale = await sales.createSale(
        SaleDraft(
          lines: [SaleLineDraft(productId: productId, quantity: 1)],
          paymentKind: SalePaymentKind.cash,
          requestKey: 'weighted-average-sale-before-next-purchase',
          occurredAt: saleAt,
        ),
      );
      expect(firstSale.lines.single.unitCostMilliMinor, 2500000);
      expect(firstSale.lines.single.costTotalMinor, 2500);

      await purchases.createPurchase(
        PurchaseDraft(
          supplierName: 'مورد ثانٍ',
          lines: [
            PurchaseLineDraft(
              productId: productId,
              productName: 'صنف تجريبي',
              purchasePriceMinor: 4000,
              salePriceMinor: 5000,
              quantity: 10,
            ),
          ],
          amountPaidMinor: 40000,
          requestKey: 'weighted-average-second-purchase',
          occurredAt: saleAt.add(const Duration(days: 1)),
        ),
      );

      final currentProduct = await database
          .select(database.products)
          .getSingle();
      expect(currentProduct.averageCostMilliMinor, 3017241);
      expect(currentProduct.averageCostReliable, isTrue);

      final firstSaleAfterReRead = (await sales.getSale(firstSale.id))!;
      expect(firstSaleAfterReRead.lines.single.unitCostMilliMinor, 2500000);
      expect(firstSaleAfterReRead.lines.single.costTotalMinor, 2500);

      final report = await reports.getSummary(
        DateTime(saleAt.year, saleAt.month, saleAt.day),
        DateTime(saleAt.year, saleAt.month, saleAt.day + 1),
      );
      expect(report.costOfGoodsSoldMinor, 2500);
      expect(report.unknownCostLineCount, 0);
      expect(report.netProfitMinor, 2500);

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
