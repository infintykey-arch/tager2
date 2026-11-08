import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/formatters.dart';
import '../../pdf/data/invoice_pdf_service.dart';
import '../data/report_repository.dart';

enum _ReportPeriod { day, month, custom }

enum _ReportType { overview, sales, purchases, expenses, debts, inventory }

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key, required this.repository});

  final ReportRepository repository;

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with SingleTickerProviderStateMixin {
  late DateTimeRange _range;
  late Future<ReportSummary> _summary;
  late Future<List<ReportInvoice>> _invoices;
  late final TabController _invoiceTabController;
  _ReportPeriod _period = _ReportPeriod.day;
  _ReportType _reportType = _ReportType.overview;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _invoiceTabController = TabController(length: 3, vsync: this);
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day + 1),
    );
    _load();
  }

  @override
  void dispose() {
    _invoiceTabController.dispose();
    super.dispose();
  }

  void _load() {
    _summary = widget.repository.getSummary(_range.start, _range.end);
    _invoices = widget.repository.getInvoices(_range.start, _range.end);
  }

  void _selectPeriod(_ReportPeriod period) {
    final now = DateTime.now();
    setState(() {
      _period = period;
      if (period == _ReportPeriod.day) {
        _range = DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day + 1),
        );
      } else if (period == _ReportPeriod.month) {
        _range = DateTimeRange(
          start: DateTime(now.year, now.month),
          end: DateTime(now.year, now.month + 1),
        );
      }
      _load();
    });
  }

  Future<void> _chooseRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3660)),
      initialDateRange: DateTimeRange(
        start: _range.start,
        end: _range.end.subtract(const Duration(days: 1)),
      ),
      helpText: 'اختر فترة التقرير',
      saveText: 'عرض التقرير',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _period = _ReportPeriod.custom;
      _range = DateTimeRange(
        start: DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        ),
        end: DateTime(picked.end.year, picked.end.month, picked.end.day + 1),
      );
      _load();
    });
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  String get _rangeLabel {
    final lastDay = _range.end.subtract(const Duration(days: 1));
    if (_period == _ReportPeriod.day) return _dateLabel(_range.start);
    if (_period == _ReportPeriod.month) {
      return '${_range.start.month.toString().padLeft(2, '0')}/${_range.start.year}';
    }
    return '${_dateLabel(_range.start)} — ${_dateLabel(lastDay)}';
  }

  Future<void> _exportPdf(ReportSummary summary) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final bytes = await InvoicePdfService().report(
        start: _range.start,
        end: _range.end,
        summary: summary,
        reportCategory: ReportCategory.values.byName(_reportType.name),
      );
      if (!mounted) return;
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'tager2-report-${_range.start.year}-'
            '${_range.start.month.toString().padLeft(2, '0')}-'
            '${_range.start.day.toString().padLeft(2, '0')}.pdf',
        subject: 'تقرير تاجر ٢ للفترة $_rangeLabel',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إنشاء أو تنزيل التقرير PDF: $error')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async => setState(_load),
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 28),
        children: [
          Text(
            'إنشاء التقارير',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'اختر نوع التقرير والفترة الزمنية، ثم اعرض الأرقام أو صدّرها PDF.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<_ReportType>(
            initialValue: _reportType,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'نوع التقرير',
              prefixIcon: Icon(Icons.assessment_outlined),
            ),
            items: const [
              DropdownMenuItem(
                value: _ReportType.overview,
                child: Text('ملخص عام'),
              ),
              DropdownMenuItem(
                value: _ReportType.sales,
                child: Text('المبيعات'),
              ),
              DropdownMenuItem(
                value: _ReportType.purchases,
                child: Text('المشتريات'),
              ),
              DropdownMenuItem(
                value: _ReportType.expenses,
                child: Text('المصروفات'),
              ),
              DropdownMenuItem(
                value: _ReportType.debts,
                child: Text('الديون والتحصيلات'),
              ),
              DropdownMenuItem(
                value: _ReportType.inventory,
                child: Text('المخزون'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _reportType = value);
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('يومي'),
                selected: _period == _ReportPeriod.day,
                onSelected: (_) => _selectPeriod(_ReportPeriod.day),
              ),
              ChoiceChip(
                label: const Text('شهري'),
                selected: _period == _ReportPeriod.month,
                onSelected: (_) => _selectPeriod(_ReportPeriod.month),
              ),
              ChoiceChip(
                label: const Text('فترة مخصصة'),
                selected: _period == _ReportPeriod.custom,
                onSelected: (_) => _chooseRange(),
              ),
              ActionChip(
                avatar: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text(_rangeLabel),
                onPressed: _chooseRange,
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<ReportSummary>(
            future: _summary,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const _MessageCard(
                  icon: Icons.error_outline_rounded,
                  message: 'تعذر قراءة التقرير. حاول تحديث الصفحة.',
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final summary = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildReportCards(summary, colors),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _exporting ? null : () => _exportPdf(summary),
                    icon: _exporting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(
                      _exporting ? 'جارٍ تجهيز PDF...' : 'تصدير التقرير PDF',
                    ),
                  ),
                  if (_reportType == _ReportType.overview ||
                      _reportType == _ReportType.sales) ...[
                    const SizedBox(height: 10),
                    _MessageCard(
                      icon: Icons.info_outline_rounded,
                      message:
                          'يُحسب صافي الربح من المبيعات مطروحًا منها تكلفة البضاعة المباعة والمصروفات. '
                          'إذا كانت التكلفة مجهولة فلن نخمن الربح أو نغير البيانات التاريخية.',
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'الفواتير',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _invoiceTabController,
            isScrollable: true,
            tabs: const [
              Tab(text: 'كل الفواتير'),
              Tab(text: 'كاملة السداد'),
              Tab(text: 'آجلة'),
            ],
          ),
          SizedBox(
            height: 390,
            child: FutureBuilder<List<ReportInvoice>>(
              future: _invoices,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('تعذر تحميل الفواتير.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final invoices = snapshot.data!;
                return TabBarView(
                  controller: _invoiceTabController,
                  children: [
                    _InvoiceList(invoices: invoices),
                    _InvoiceList(
                      invoices: invoices
                          .where((invoice) => invoice.remainingMinor <= 0)
                          .toList(growable: false),
                    ),
                    _InvoiceList(
                      invoices: invoices
                          .where((invoice) => invoice.remainingMinor > 0)
                          .toList(growable: false),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCards(ReportSummary summary, ColorScheme colors) {
    final cards = <Widget>[];
    void addMetric(
      String title,
      ReportMetric metric,
      Color color, {
      String countLabel = 'فاتورة',
    }) {
      cards.add(
        _MetricCard(
          title: title,
          metric: metric,
          color: color,
          countLabel: countLabel,
        ),
      );
    }

    void addMoney(String title, String value, String subtitle, Color color) {
      cards.add(
        _MoneyCard(
          title: title,
          value: value,
          subtitle: subtitle,
          color: color,
        ),
      );
    }

    if (_reportType == _ReportType.overview ||
        _reportType == _ReportType.sales) {
      addMetric('إجمالي المبيعات', summary.sales, colors.primary);
      if (_reportType == _ReportType.overview) {
        addMoney(
          'تكلفة البضاعة المباعة',
          summary.unknownCostLineCount == 0
              ? formatMoneyMinor(summary.costOfGoodsSoldMinor)
              : 'غير متاحة',
          summary.unknownCostLineCount == 0
              ? 'بتكلفة محفوظة وقت البيع'
              : 'توجد تكلفة مجهولة لبعض السطور',
          const Color(0xFF397D72),
        );
        addMoney(
          'صافي الربح',
          summary.netProfitMinor == null
              ? 'غير متاح'
              : formatMoneyMinor(summary.netProfitMinor!),
          'المبيعات − تكلفة المباعة − المصروفات',
          summary.netProfitMinor != null && summary.netProfitMinor! < 0
              ? colors.error
              : colors.primary,
        );
      }
    }
    if (_reportType == _ReportType.overview ||
        _reportType == _ReportType.purchases) {
      addMetric('إجمالي المشتريات', summary.purchases, const Color(0xFF6D6A9F));
    }
    if (_reportType == _ReportType.overview ||
        _reportType == _ReportType.expenses) {
      addMetric(
        'إجمالي المصروفات',
        summary.expenses,
        const Color(0xFFB16B38),
        countLabel: 'مصروف مسجل',
      );
    }
    if (_reportType == _ReportType.overview ||
        _reportType == _ReportType.debts) {
      addMetric(
        'المبالغ المستحقة من العملاء',
        summary.customerDebts,
        colors.primary,
        countLabel: 'عميل مدين',
      );
      addMetric(
        'المبالغ المستحقة للموردين',
        summary.supplierDebts,
        const Color(0xFF6D6A9F),
        countLabel: 'مورد',
      );
    }
    if (_reportType == _ReportType.overview ||
        _reportType == _ReportType.inventory) {
      addMoney(
        'قيمة المخزون بسعر البيع',
        formatMoneyMinor(summary.inventory.retailValueMinor),
        '${summary.inventory.productCount} صنف · '
            '${summary.inventory.lowStockCount} على وشك النفاد · '
            '${summary.inventory.missingStockCount} ناقص',
        const Color(0xFF397D72),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards
              .map((card) => SizedBox(width: cardWidth, child: card))
              .toList(growable: false),
        );
      },
    );
  }
}

class _InvoiceList extends StatelessWidget {
  const _InvoiceList({required this.invoices});

  final List<ReportInvoice> invoices;

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return const Center(child: Text('لا توجد فواتير ضمن هذه الفترة.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: invoices.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        final paid = invoice.remainingMinor <= 0;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: Icon(
            invoice.isPurchase
                ? Icons.shopping_bag_outlined
                : Icons.point_of_sale_outlined,
          ),
          title: Text('${invoice.invoiceNumber} · ${invoice.partyName}'),
          subtitle: Text(
            '${formatDateTime(invoice.createdAt)} · '
            'مدفوع ${formatMoneyMinor(invoice.paidMinor)} · '
            '${paid ? 'كاملة السداد' : 'آجلة'}',
            maxLines: 2,
          ),
          trailing: Text(
            formatMoneyMinor(invoice.totalMinor),
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (context) => _InvoiceDetails(invoice: invoice),
          ),
        );
      },
    );
  }
}

class _InvoiceDetails extends StatelessWidget {
  const _InvoiceDetails({required this.invoice});

  final ReportInvoice invoice;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            invoice.invoiceNumber,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text('${invoice.partyName} · ${formatDateTime(invoice.createdAt)}'),
          const Divider(height: 24),
          for (final line in invoice.lines)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(line.productName),
              subtitle: Text(
                '${formatQuantity(line.quantity)} × ${formatMoneyMinor(line.unitPriceMinor)}',
              ),
              trailing: Text(formatMoneyMinor(line.totalMinor)),
            ),
          const Divider(height: 24),
          _detailLine('الإجمالي', invoice.totalMinor),
          _detailLine('المدفوع', invoice.paidMinor),
          _detailLine('المتبقي', invoice.remainingMinor),
          const SizedBox(height: 12),
          Text('سجل الدفعات', style: Theme.of(context).textTheme.titleMedium),
          if (invoice.payments.isEmpty)
            const ListTile(title: Text('لا توجد دفعات مسجلة.'))
          else
            for (final payment in invoice.payments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(formatMoneyMinor(payment.amountMinor)),
                subtitle: Text(formatDateTime(payment.occurredAt)),
              ),
          Text(
            invoice.remainingMinor <= 0
                ? 'حالة السداد: كاملة'
                : 'حالة السداد: آجلة',
          ),
        ],
      ),
    );
  }

  Widget _detailLine(String label, int amount) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          formatMoneyMinor(amount),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.metric,
    required this.color,
    required this.countLabel,
  });

  final String title;
  final ReportMetric metric;
  final Color color;
  final String countLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              formatMoneyMinor(metric.totalMinor),
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 4),
            Text('${metric.invoiceCount} $countLabel'),
          ],
        ),
      ),
    );
  }
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 4),
            Text(subtitle),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
