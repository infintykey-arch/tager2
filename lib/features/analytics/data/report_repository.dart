import 'package:drift/drift.dart';

import '../../../core/payment_snapshot.dart';
import '../../../data/local/app_database.dart';
import '../../purchases/data/purchases_repository.dart';
import '../../sales/data/sales_repository.dart';

class ReportMetric {
  const ReportMetric({required this.totalMinor, required this.invoiceCount});

  final int totalMinor;
  final int invoiceCount;
}

enum ReportCategory { overview, sales, purchases, expenses, debts, inventory }

class ReportInventorySummary {
  const ReportInventorySummary({
    this.productCount = 0,
    this.lowStockCount = 0,
    this.missingStockCount = 0,
    this.retailValueMinor = 0,
  });

  final int productCount;
  final int lowStockCount;
  final int missingStockCount;
  final int retailValueMinor;
}

class ReportSummary {
  const ReportSummary({
    required this.sales,
    required this.purchases,
    required this.expenses,
    this.costOfGoodsSoldMinor = 0,
    this.unknownCostLineCount = 0,
    this.customerDebts = const ReportMetric(totalMinor: 0, invoiceCount: 0),
    this.supplierDebts = const ReportMetric(totalMinor: 0, invoiceCount: 0),
    this.inventory = const ReportInventorySummary(),
  });

  final ReportMetric sales;
  final ReportMetric purchases;
  final ReportMetric expenses;
  final int costOfGoodsSoldMinor;
  final int unknownCostLineCount;
  final ReportMetric customerDebts;
  final ReportMetric supplierDebts;
  final ReportInventorySummary inventory;

  int? get grossProfitMinor => unknownCostLineCount == 0
      ? sales.totalMinor - costOfGoodsSoldMinor
      : null;

  int? get netProfitMinor =>
      grossProfitMinor == null ? null : grossProfitMinor! - expenses.totalMinor;
}

class ReportInvoiceLine {
  const ReportInvoiceLine({
    required this.productName,
    required this.quantity,
    required this.unitPriceMinor,
    required this.totalMinor,
  });

  final String productName;
  final double quantity;
  final int unitPriceMinor;
  final int totalMinor;
}

class ReportInvoice {
  const ReportInvoice({
    required this.invoiceNumber,
    required this.partyName,
    required this.createdAt,
    required this.totalMinor,
    required this.paidMinor,
    required this.lines,
    required this.payments,
    required this.isPurchase,
  });

  final String invoiceNumber;
  final String partyName;
  final DateTime createdAt;
  final int totalMinor;
  final int paidMinor;
  final List<ReportInvoiceLine> lines;
  final List<PaymentSnapshot> payments;
  final bool isPurchase;

  int get remainingMinor => totalMinor - paidMinor;
}

abstract interface class ReportRepository {
  Future<ReportSummary> getSummary(DateTime start, DateTime end);

  Future<List<ReportInvoice>> getInvoices(
    DateTime start,
    DateTime end, {
    int limit = 500,
  });
}

class LocalReportRepository implements ReportRepository {
  LocalReportRepository(this._database);

  final AppDatabase _database;

  @override
  Future<ReportSummary> getSummary(DateTime start, DateTime end) async {
    if (!end.isAfter(start)) {
      return const ReportSummary(
        sales: ReportMetric(totalMinor: 0, invoiceCount: 0),
        purchases: ReportMetric(totalMinor: 0, invoiceCount: 0),
        expenses: ReportMetric(totalMinor: 0, invoiceCount: 0),
      );
    }

    final startText = start.toUtc().toIso8601String();
    final endText = end.toUtc().toIso8601String();
    final results = await Future.wait([
      _aggregate(
        table: 'sales',
        amountColumn: 'total_minor',
        dateColumn: 'created_at',
        start: startText,
        end: endText,
      ),
      _aggregate(
        table: 'purchases',
        amountColumn: 'total_minor',
        dateColumn: 'created_at',
        start: startText,
        end: endText,
      ),
      _aggregate(
        table: 'expenses',
        amountColumn: 'amount_minor',
        dateColumn: 'occurred_at',
        start: startText,
        end: endText,
      ),
    ]);
    final costRows = await _database
        .customSelect(
          '''
          SELECT
            COALESCE(SUM(sl.cost_total_minor), 0) AS cost_total_minor,
            COALESCE(SUM(
              CASE WHEN sl.id IS NOT NULL AND sl.cost_total_minor IS NULL
                THEN 1 ELSE 0 END
            ), 0) AS unknown_cost_lines
          FROM sales AS s
          LEFT JOIN sale_lines AS sl ON sl.sale_id = s.id
          WHERE s.created_at >= ? AND s.created_at < ?
          LIMIT 1
          ''',
          variables: [
            Variable.withString(startText),
            Variable.withString(endText),
          ],
        )
        .get();
    final debtRows = await _database.customSelect('''
          SELECT
            COALESCE((
              SELECT SUM(s.total_minor - COALESCE(pay.paid_minor, 0))
              FROM sales AS s
              LEFT JOIN (
                SELECT sale_id, SUM(amount_minor) AS paid_minor
                FROM sale_payments GROUP BY sale_id
              ) AS pay ON pay.sale_id = s.id
              WHERE s.payment_type = 'credit'
                AND s.total_minor - COALESCE(pay.paid_minor, 0) > 0
            ), 0) AS customer_debt_minor,
            (SELECT COUNT(DISTINCT COALESCE(s.customer_id, s.customer_name_snapshot))
              FROM sales AS s
              LEFT JOIN (
                SELECT sale_id, SUM(amount_minor) AS paid_minor
                FROM sale_payments GROUP BY sale_id
              ) AS pay ON pay.sale_id = s.id
              WHERE s.payment_type = 'credit'
                AND s.total_minor - COALESCE(pay.paid_minor, 0) > 0
            ) AS customer_count,
            COALESCE((
              SELECT SUM(p.total_minor - COALESCE(pay.paid_minor, 0))
              FROM purchases AS p
              LEFT JOIN (
                SELECT purchase_id, SUM(amount_minor) AS paid_minor
                FROM purchase_payments GROUP BY purchase_id
              ) AS pay ON pay.purchase_id = p.id
              WHERE p.total_minor - COALESCE(pay.paid_minor, 0) > 0
            ), 0) AS supplier_debt_minor,
            (SELECT COUNT(DISTINCT p.supplier_id)
              FROM purchases AS p
              LEFT JOIN (
                SELECT purchase_id, SUM(amount_minor) AS paid_minor
                FROM purchase_payments GROUP BY purchase_id
              ) AS pay ON pay.purchase_id = p.id
              WHERE p.total_minor - COALESCE(pay.paid_minor, 0) > 0
            ) AS supplier_count
          LIMIT 1
          ''').get();
    final inventoryRows = await _database.customSelect('''
          SELECT
            COUNT(*) AS product_count,
            COALESCE(SUM(CASE WHEN COALESCE(stock.quantity_on_hand, 0) > 0
              AND stock.quantity_on_hand <= p.minimum_stock
              THEN 1 ELSE 0 END), 0) AS low_stock_count,
            COALESCE(SUM(CASE WHEN COALESCE(stock.quantity_on_hand, 0) <= 0
              THEN 1 ELSE 0 END), 0) AS missing_stock_count,
            COALESCE(SUM(MAX(COALESCE(stock.quantity_on_hand, 0), 0)
              * p.sale_price_minor), 0) AS retail_value_minor
          FROM products AS p
          LEFT JOIN product_stock_summary AS stock
            ON stock.product_id = p.id
          WHERE p.is_archived = 0
          LIMIT 1
          ''').get();

    final costRow = costRows.single;
    final debtRow = debtRows.single;
    final inventoryRow = inventoryRows.single;
    return ReportSummary(
      sales: results[0],
      purchases: results[1],
      expenses: results[2],
      costOfGoodsSoldMinor: costRow.read<int>('cost_total_minor'),
      unknownCostLineCount: costRow.read<int>('unknown_cost_lines'),
      customerDebts: ReportMetric(
        totalMinor: debtRow.read<int>('customer_debt_minor'),
        invoiceCount: debtRow.read<int>('customer_count'),
      ),
      supplierDebts: ReportMetric(
        totalMinor: debtRow.read<int>('supplier_debt_minor'),
        invoiceCount: debtRow.read<int>('supplier_count'),
      ),
      inventory: ReportInventorySummary(
        productCount: inventoryRow.read<int>('product_count'),
        lowStockCount: inventoryRow.read<int>('low_stock_count'),
        missingStockCount: inventoryRow.read<int>('missing_stock_count'),
        retailValueMinor: inventoryRow.read<int>('retail_value_minor'),
      ),
    );
  }

  @override
  Future<List<ReportInvoice>> getInvoices(
    DateTime start,
    DateTime end, {
    int limit = 500,
  }) async {
    if (!end.isAfter(start) || limit <= 0) return const [];
    final boundedLimit = limit.clamp(1, 1000);
    final startText = start.toUtc().toIso8601String();
    final endText = end.toUtc().toIso8601String();
    final salesIds = await _database
        .customSelect(
          '''SELECT id FROM sales WHERE created_at >= ? AND created_at < ?
         ORDER BY created_at DESC, id DESC LIMIT ?''',
          variables: [
            Variable.withString(startText),
            Variable.withString(endText),
            Variable.withInt(boundedLimit),
          ],
        )
        .get();
    final purchaseIds = await _database
        .customSelect(
          '''SELECT id FROM purchases WHERE created_at >= ? AND created_at < ?
         ORDER BY created_at DESC, id DESC LIMIT ?''',
          variables: [
            Variable.withString(startText),
            Variable.withString(endText),
            Variable.withInt(boundedLimit),
          ],
        )
        .get();
    final salesRepository = DriftSalesRepository(_database);
    final purchasesRepository = DriftPurchasesRepository(_database);
    final invoices = <ReportInvoice>[];
    for (final row in salesIds) {
      final receipt = await salesRepository.getSale(row.read<int>('id'));
      if (receipt == null) continue;
      invoices.add(
        ReportInvoice(
          invoiceNumber: receipt.invoiceNumber,
          partyName: receipt.customerName ?? 'بيع نقدي',
          createdAt: receipt.createdAt,
          totalMinor: receipt.totalMinor,
          paidMinor: receipt.paidMinor,
          lines: receipt.lines
              .map(
                (line) => ReportInvoiceLine(
                  productName: line.productName,
                  quantity: line.quantity,
                  unitPriceMinor: line.unitPriceMinor,
                  totalMinor: line.lineTotalMinor,
                ),
              )
              .toList(growable: false),
          payments: receipt.payments,
          isPurchase: false,
        ),
      );
    }
    for (final row in purchaseIds) {
      final receipt = await purchasesRepository.getPurchase(
        row.read<int>('id'),
      );
      if (receipt == null) continue;
      invoices.add(
        ReportInvoice(
          invoiceNumber: receipt.invoiceNumber,
          partyName: receipt.supplierName,
          createdAt: receipt.createdAt,
          totalMinor: receipt.totalMinor,
          paidMinor: receipt.paidMinor,
          lines: receipt.lines
              .map(
                (line) => ReportInvoiceLine(
                  productName: line.productName,
                  quantity: line.quantity,
                  unitPriceMinor: line.purchasePriceMinor,
                  totalMinor: line.lineTotalMinor,
                ),
              )
              .toList(growable: false),
          payments: receipt.payments,
          isPurchase: true,
        ),
      );
    }
    invoices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (invoices.length > boundedLimit) {
      return invoices.take(boundedLimit).toList(growable: false);
    }
    return invoices;
  }

  Future<ReportMetric> _aggregate({
    required String table,
    required String amountColumn,
    required String dateColumn,
    required String start,
    required String end,
  }) async {
    final rows = await _database
        .customSelect(
          'SELECT COALESCE(SUM($amountColumn), 0) AS total_minor, '
          'COUNT(*) AS entry_count FROM $table '
          'WHERE $dateColumn >= ? AND $dateColumn < ? LIMIT 1',
          variables: [Variable.withString(start), Variable.withString(end)],
        )
        .get();
    final row = rows.single;
    return ReportMetric(
      totalMinor: row.read<int>('total_minor'),
      invoiceCount: row.read<int>('entry_count'),
    );
  }
}
