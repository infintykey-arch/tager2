import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../products/data/products_repository.dart';
import '../../products/domain/product.dart';
import '../../purchases/data/purchases_repository.dart';
import '../../sales/data/sales_repository.dart';
import '../data/report_repository.dart';

class AnalysisOverviewPage extends StatefulWidget {
  const AnalysisOverviewPage({
    super.key,
    required this.reportRepository,
    required this.productsRepository,
    required this.salesRepository,
    required this.purchasesRepository,
  });

  final ReportRepository reportRepository;
  final ProductsRepository productsRepository;
  final SalesRepository salesRepository;
  final PurchasesRepository purchasesRepository;

  @override
  State<AnalysisOverviewPage> createState() => _AnalysisOverviewPageState();
}

class _AnalysisOverviewPageState extends State<AnalysisOverviewPage> {
  late DateTimeRange _range;
  late Future<_AnalysisSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day + 1),
    );
    _snapshot = _loadSnapshot();
  }

  Future<_AnalysisSnapshot> _loadSnapshot() async {
    final results = await Future.wait([
      widget.reportRepository.getSummary(_range.start, _range.end),
      widget.productsRepository.getProducts(),
      widget.salesRepository.getOpenCreditSales(),
      widget.purchasesRepository.getOpenPurchases(),
    ]);
    final summary = results[0] as ReportSummary;
    final products = results[1] as List<Product>;
    final customerInvoices = results[2] as List<SaleReceipt>;
    final supplierInvoices = results[3] as List<PurchaseReceipt>;
    return _AnalysisSnapshot(
      summary: summary,
      totalProducts: products.length,
      missingProducts: products
          .where((product) => product.stockOnHand <= 0)
          .length,
      lowStockProducts: products
          .where(
            (product) => product.stockOnHand > 0 && product.stockOnHand <= 10,
          )
          .length,
      customerDebtMinor: customerInvoices.fold<int>(
        0,
        (sum, invoice) => sum + invoice.remainingMinor,
      ),
      supplierDebtMinor: supplierInvoices.fold<int>(
        0,
        (sum, invoice) => sum + invoice.remainingMinor,
      ),
      customerCount: customerInvoices
          .map((invoice) => invoice.customerName)
          .toSet()
          .length,
      supplierCount: supplierInvoices
          .map((invoice) => invoice.supplierName)
          .toSet()
          .length,
    );
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _snapshot = _loadSnapshot());
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _chooseRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3660)),
      initialDateRange: DateTimeRange(
        start: _range.start,
        end: _range.end.subtract(const Duration(days: 1)),
      ),
      helpText: 'اختر فترة التحليل',
      saveText: 'عرض الفترة',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _range = DateTimeRange(
        start: DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        ),
        end: DateTime(picked.end.year, picked.end.month, picked.end.day + 1),
      );
      _snapshot = _loadSnapshot();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 30),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نظرة على النشاط',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_dateLabel(_range.start)} – '
                      '${_dateLabel(_range.end.subtract(const Duration(days: 1)))}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _chooseRange,
                icon: const Icon(Icons.date_range_outlined),
                label: const Text('الفترة'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FutureBuilder<_AnalysisSnapshot>(
            future: _snapshot,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return _AnalysisNotice(
                  message: 'تعذر تحميل بيانات التحليل.',
                  action: OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                  ),
                );
              }
              final data = snapshot.data!;
              final summary = data.summary;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AnalysisLeadMetric(
                    title: 'صافي الربح للفترة',
                    amount: summary.netProfitMinor == null
                        ? 'غير متاح'
                        : formatMoneyMinor(summary.netProfitMinor!),
                    note: summary.netProfitMinor == null
                        ? 'توجد تكلفة غير معروفة لبعض المبيعات القديمة.'
                        : 'المبيعات − تكلفة البضاعة المباعة − المصروفات',
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 760 ? 3 : 2;
                      final gap = 10.0;
                      final width =
                          (constraints.maxWidth - gap * (columns - 1)) /
                          columns;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          SizedBox(
                            width: width,
                            child: _AnalysisMetric(
                              title: 'المبيعات',
                              value: formatMoneyMinor(summary.sales.totalMinor),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _AnalysisMetric(
                              title: 'المشتريات',
                              value: formatMoneyMinor(
                                summary.purchases.totalMinor,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _AnalysisMetric(
                              title: 'المصروفات',
                              value: formatMoneyMinor(
                                summary.expenses.totalMinor,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'المخزون والديون المستحقة',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _AnalysisMetric(
                    title: 'حالة المخزون',
                    value: '${data.totalProducts} صنف',
                    detail:
                        '${data.missingProducts} ناقص · ${data.lowStockProducts} على وشك النفاد',
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final gap = 10.0;
                      final width = constraints.maxWidth >= 640
                          ? (constraints.maxWidth - gap) / 2
                          : constraints.maxWidth;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          SizedBox(
                            width: width,
                            child: _AnalysisMetric(
                              title: 'ديون العملاء',
                              value: formatMoneyMinor(data.customerDebtMinor),
                              detail: '${data.customerCount} عميل',
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _AnalysisMetric(
                              title: 'ديون الموردين',
                              value: formatMoneyMinor(data.supplierDebtMinor),
                              detail: '${data.supplierCount} مورد',
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'تعرض الأرقام المالية حركة الفترة المحددة، بينما تعرض بطاقة المخزون والديون الرصيد الحالي.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant, height: 1.4),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AnalysisSnapshot {
  const _AnalysisSnapshot({
    required this.summary,
    required this.totalProducts,
    required this.missingProducts,
    required this.lowStockProducts,
    required this.customerDebtMinor,
    required this.supplierDebtMinor,
    required this.customerCount,
    required this.supplierCount,
  });

  final ReportSummary summary;
  final int totalProducts;
  final int missingProducts;
  final int lowStockProducts;
  final int customerDebtMinor;
  final int supplierDebtMinor;
  final int customerCount;
  final int supplierCount;
}

class _AnalysisLeadMetric extends StatelessWidget {
  const _AnalysisLeadMetric({
    required this.title,
    required this.amount,
    required this.note,
  });

  final String title;
  final String amount;
  final String note;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              amount,
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(note, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _AnalysisMetric extends StatelessWidget {
  const _AnalysisMetric({
    required this.title,
    required this.value,
    this.detail,
  });

  final String title;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 5),
            Text(
              value,
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (detail != null) ...[
              const SizedBox(height: 3),
              Text(detail!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnalysisNotice extends StatelessWidget {
  const _AnalysisNotice({required this.message, required this.action});

  final String message;
  final Widget action;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [Text(message), const SizedBox(height: 10), action],
    ),
  );
}
