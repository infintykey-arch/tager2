import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/data/local/app_database.dart';
import 'package:tager2/features/analytics/data/report_repository.dart';
import 'package:tager2/features/expenses/data/expenses_repository.dart';
import 'package:tager2/features/products/data/products_repository.dart';
import 'package:tager2/features/products/domain/product.dart';
import 'package:tager2/features/purchases/data/purchases_repository.dart';
import 'package:tager2/features/sales/data/sales_repository.dart';

void main() {
  late AppDatabase database;
  late DriftProductsRepository products;
  late DriftSalesRepository sales;
  late DriftPurchasesRepository purchases;
  late DriftExpensesRepository expenses;
  late LocalReportRepository reports;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    products = DriftProductsRepository(database);
    sales = DriftSalesRepository(database);
    purchases = DriftPurchasesRepository(database);
    expenses = DriftExpensesRepository(database);
    reports = LocalReportRepository(database);
  });

  tearDown(() => database.close());

  test(
    'يجمع المبيعات والمشتريات والمصروفات ويستبعد بداية اليوم التالي',
    () async {
      await products.save(
        const Product(
          name: 'سلعة',
          purchasePriceMinor: 400,
          salePriceMinor: 1000,
          minimumStock: 0,
          stockOnHand: 5,
        ),
      );
      final productId = (await products.getProducts()).single.id!;
      final now = DateTime.now();
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 1));

      await purchases.createPurchase(
        PurchaseDraft(
          supplierName: 'مورد',
          lines: [
            PurchaseLineDraft(
              productId: productId,
              productName: 'سلعة',
              purchasePriceMinor: 400,
              salePriceMinor: 1000,
              quantity: 3,
            ),
          ],
          amountPaidMinor: 1200,
          requestKey: 'report-purchase-in-range',
          occurredAt: day.add(const Duration(hours: 10)),
        ),
      );
      await sales.createSale(
        SaleDraft(
          lines: [SaleLineDraft(productId: productId, quantity: 2)],
          paymentKind: SalePaymentKind.cash,
          requestKey: 'report-sale-in-range',
          occurredAt: day.add(const Duration(hours: 12)),
        ),
      );
      await expenses.createExpense(
        ExpenseDraft(
          category: 'نقل',
          amountMinor: 500,
          requestKey: 'report-expense-in-range',
          occurredAt: day.add(const Duration(hours: 14)),
        ),
      );
      await sales.createSale(
        SaleDraft(
          lines: [SaleLineDraft(productId: productId, quantity: 1)],
          paymentKind: SalePaymentKind.cash,
          requestKey: 'report-sale-next-day',
          occurredAt: day.add(const Duration(days: 1)),
        ),
      );

      final report = await reports.getSummary(
        day,
        day.add(const Duration(days: 1)),
      );

      expect(report.sales.totalMinor, 2000);
      expect(report.sales.invoiceCount, 1);
      expect(report.purchases.totalMinor, 1200);
      expect(report.purchases.invoiceCount, 1);
      expect(report.expenses.totalMinor, 500);
      expect(report.expenses.invoiceCount, 1);
      expect(report.costOfGoodsSoldMinor, 800);
      expect(report.unknownCostLineCount, 0);
      expect(report.netProfitMinor, 700);
      final invoices = await reports.getInvoices(
        day,
        day.add(const Duration(days: 1)),
      );
      expect(invoices, hasLength(2));
      expect(invoices.any((invoice) => invoice.isPurchase), isTrue);
      expect(invoices.any((invoice) => !invoice.isPurchase), isTrue);
    },
  );

  test('يعيد أصفارًا عندما تكون الفترة غير صالحة', () async {
    final day = DateTime(2026, 11, 4);
    final report = await reports.getSummary(day, day);

    expect(report.sales.totalMinor, 0);
    expect(report.purchases.invoiceCount, 0);
    expect(report.expenses.totalMinor, 0);
  });
}
