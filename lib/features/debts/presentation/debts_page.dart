import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/formatters.dart';
import '../../../core/payment_snapshot.dart';
import '../../pdf/data/invoice_pdf_service.dart';
import '../../purchases/data/purchases_repository.dart';
import '../../sales/data/sales_repository.dart';

class DebtsPage extends StatefulWidget {
  const DebtsPage({
    super.key,
    required this.kind,
    required this.salesRepository,
    required this.purchasesRepository,
  });

  final DebtKind kind;
  final SalesRepository salesRepository;
  final PurchasesRepository purchasesRepository;

  @override
  State<DebtsPage> createState() => _DebtsPageState();
}

enum DebtKind { customers, suppliers }

class _DebtsPageState extends State<DebtsPage> {
  final _searchController = TextEditingController();
  late Future<List<_DebtRecord>> _recordsFuture;
  late Future<int> _supplierCountFuture;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _recordsFuture = _loadRecords();
    _supplierCountFuture = widget.purchasesRepository.getSupplierCount();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<_DebtRecord>> _loadRecords() async {
    if (widget.kind == DebtKind.customers) {
      final invoices = await widget.salesRepository.getOpenCreditSales();
      return invoices
          .map(
            (receipt) => _CustomerDebtRecord(receipt, widget.salesRepository),
          )
          .toList(growable: false);
    }
    final invoices = await widget.purchasesRepository.getOpenPurchases();
    return invoices
        .map(
          (receipt) => _SupplierDebtRecord(receipt, widget.purchasesRepository),
        )
        .toList(growable: false);
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _recordsFuture = _loadRecords();
    });
  }

  Future<void> _recordPayment(_DebtRecord record) async {
    final amount = await showDialog<int>(
      context: context,
      builder: (_) => _PaymentAmountDialog(
        partyName: record.partyName,
        remainingMinor: record.remainingMinor,
      ),
    );
    if (amount == null || !mounted) return;
    try {
      final requestKey =
          'debt-payment-${record.id}-${DateTime.now().microsecondsSinceEpoch}';
      await record.addPayment(amount, requestKey);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ الدفعة: ${_friendlyError(error)}')),
      );
      return;
    }
    if (!mounted) return;
    _refresh();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('تم تسجيل الدفعة.')));
  }

  Future<void> _exportPdf(_DebtRecord record) async {
    try {
      final bytes = await record.pdfBytes(InvoicePdfService());
      if (!mounted) return;
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${record.invoiceNumber}.pdf',
        subject: 'فاتورة ${record.invoiceNumber}',
        body: 'فاتورة من برنامج تاجر ٢ المحلي.',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إنشاء أو مشاركة PDF: $error')),
      );
    }
  }

  String _friendlyError(Object error) {
    if (error is StateError || error is ArgumentError) {
      return error.toString().replaceFirst('Bad state: ', '');
    }
    return 'حدث خطأ غير متوقع.';
  }

  @override
  Widget build(BuildContext context) {
    final isCustomer = widget.kind == DebtKind.customers;
    final partyLabel = isCustomer ? 'عميل لديه مديونية' : 'مورد مسجل';
    return FutureBuilder<List<_DebtRecord>>(
      future: _recordsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 42),
                  const SizedBox(height: 10),
                  const Text('تعذر تحميل سجل الديون.'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          );
        }

        final records = snapshot.data ?? const <_DebtRecord>[];
        final filteredRecords = records
            .where((record) {
              final query = _search.trim().toLowerCase();
              return query.isEmpty ||
                  record.partyName.toLowerCase().contains(query) ||
                  record.invoiceNumber.toLowerCase().contains(query);
            })
            .toList(growable: false);
        final groups = <String, List<_DebtRecord>>{};
        for (final record in filteredRecords) {
          final key = record.partyName.trim().toLowerCase();
          groups.putIfAbsent(key, () => <_DebtRecord>[]).add(record);
        }
        final grandTotal = records.fold<int>(
          0,
          (total, record) => total + record.remainingMinor,
        );
        final debtorCount = records
            .map((record) => record.partyName.trim().toLowerCase())
            .toSet()
            .length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _search = value),
                decoration: InputDecoration(
                  hintText: isCustomer
                      ? 'ابحث باسم العميل أو رقم الفاتورة'
                      : 'ابحث باسم المورد أو رقم الفاتورة',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'مسح البحث',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final gap = 10.0;
                  final width = (constraints.maxWidth - gap) / 2;
                  return Row(
                    children: [
                      SizedBox(
                        width: width,
                        child: _SummaryCard(
                          title: isCustomer
                              ? 'مستحق لدى العملاء'
                              : 'مستحق للموردين',
                          value: formatMoneyMinor(grandTotal),
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                      ),
                      SizedBox(width: gap),
                      SizedBox(
                        width: width,
                        child: isCustomer
                            ? _SummaryCard(
                                title: 'عدد العملاء المدينين',
                                value: '$debtorCount',
                                icon: Icons.people_outline,
                                subtitle: partyLabel,
                              )
                            : FutureBuilder<int>(
                                future: _supplierCountFuture,
                                builder: (context, countSnapshot) =>
                                    _SummaryCard(
                                      title: 'عدد الموردين',
                                      value:
                                          countSnapshot.data?.toString() ?? '—',
                                      icon: Icons.storefront_outlined,
                                      subtitle: partyLabel,
                                    ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: records.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isCustomer
                                  ? 'لا توجد ديون عملاء مفتوحة'
                                  : 'لا توجد مبالغ مستحقة للموردين',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'ستظهر هنا الفواتير التي لم يُسدَّد رصيدها بالكامل.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : filteredRecords.isEmpty
                  ? const Center(child: Text('لا توجد نتائج مطابقة للبحث.'))
                  : ListView(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        2,
                        16,
                        24,
                      ),
                      children: [
                        for (final group in groups.values)
                          Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ExpansionTile(
                              initiallyExpanded: groups.length == 1,
                              title: Text(
                                group.first.partyName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                'متبقي ${formatMoneyMinor(group.fold<int>(0, (sum, item) => sum + item.remainingMinor))} · ${group.length} فاتورة',
                              ),
                              children: [
                                for (final record in group)
                                  _DebtInvoiceTile(
                                    record: record,
                                    onRecordPayment: () =>
                                        _recordPayment(record),
                                    onExportPdf: () => _exportPdf(record),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
  });

  final String title;
  final String value;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (subtitle != null)
              Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

abstract interface class _DebtRecord {
  int get id;
  String get partyName;
  String get invoiceNumber;
  DateTime get createdAt;
  int get totalMinor;
  int get paidMinor;
  int get remainingMinor;
  List<_DebtLine> get lines;
  List<PaymentSnapshot> get payments;
  Future<Uint8List> pdfBytes(InvoicePdfService service);
  Future<void> addPayment(int amountMinor, String requestKey);
}

class _DebtLine {
  const _DebtLine({
    required this.name,
    required this.quantity,
    required this.unitPriceMinor,
    required this.totalMinor,
  });

  final String name;
  final double quantity;
  final int unitPriceMinor;
  final int totalMinor;
}

class _CustomerDebtRecord implements _DebtRecord {
  _CustomerDebtRecord(this.receipt, this.receiptRepository);

  final SaleReceipt receipt;
  final SalesRepository receiptRepository;

  @override
  int get id => receipt.id;
  @override
  String get partyName => receipt.customerName ?? 'عميل غير مسجل';
  @override
  String get invoiceNumber => receipt.invoiceNumber;
  @override
  DateTime get createdAt => receipt.createdAt;
  @override
  int get totalMinor => receipt.totalMinor;
  @override
  int get paidMinor => receipt.paidMinor;
  @override
  int get remainingMinor => receipt.remainingMinor;
  @override
  List<PaymentSnapshot> get payments => receipt.payments;
  @override
  List<_DebtLine> get lines => receipt.lines
      .map(
        (line) => _DebtLine(
          name: line.productName,
          quantity: line.quantity,
          unitPriceMinor: line.unitPriceMinor,
          totalMinor: line.lineTotalMinor,
        ),
      )
      .toList(growable: false);

  @override
  Future<Uint8List> pdfBytes(InvoicePdfService service) =>
      service.saleInvoice(receipt);

  @override
  Future<void> addPayment(int amountMinor, String requestKey) async {
    await receiptRepository.addPayment(
      saleId: receipt.id,
      amountMinor: amountMinor,
      requestKey: requestKey,
    );
  }
}

class _SupplierDebtRecord implements _DebtRecord {
  _SupplierDebtRecord(this.receipt, this.receiptRepository);

  final PurchaseReceipt receipt;
  final PurchasesRepository receiptRepository;

  @override
  int get id => receipt.id;
  @override
  String get partyName => receipt.supplierName;
  @override
  String get invoiceNumber => receipt.invoiceNumber;
  @override
  DateTime get createdAt => receipt.createdAt;
  @override
  int get totalMinor => receipt.totalMinor;
  @override
  int get paidMinor => receipt.paidMinor;
  @override
  int get remainingMinor => receipt.remainingMinor;
  @override
  List<PaymentSnapshot> get payments => receipt.payments;
  @override
  List<_DebtLine> get lines => receipt.lines
      .map(
        (line) => _DebtLine(
          name: line.productName,
          quantity: line.quantity,
          unitPriceMinor: line.purchasePriceMinor,
          totalMinor: line.lineTotalMinor,
        ),
      )
      .toList(growable: false);

  @override
  Future<Uint8List> pdfBytes(InvoicePdfService service) =>
      service.purchaseInvoice(receipt);

  @override
  Future<void> addPayment(int amountMinor, String requestKey) async {
    await receiptRepository.addPayment(
      purchaseId: receipt.id,
      amountMinor: amountMinor,
      requestKey: requestKey,
    );
  }
}

class _PaymentAmountDialog extends StatefulWidget {
  const _PaymentAmountDialog({
    required this.partyName,
    required this.remainingMinor,
  });

  final String partyName;
  final int remainingMinor;

  @override
  State<_PaymentAmountDialog> createState() => _PaymentAmountDialogState();
}

class _PaymentAmountDialogState extends State<_PaymentAmountDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parsed = parseMoneyMinor(_controller.text);
    final canSave =
        parsed != null && parsed > 0 && parsed <= widget.remainingMinor;
    return AlertDialog(
      title: const Text('تسجيل دفعة'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'المتبقي على ${widget.partyName}: ${formatMoneyMinor(widget.remainingMinor)}',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'قيمة الدفعة',
              suffixText: 'ج.م',
            ),
          ),
          if (parsed != null && parsed > widget.remainingMinor) ...[
            const SizedBox(height: 6),
            const Text('المبلغ أكبر من المتبقي.'),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: canSave ? () => Navigator.of(context).pop(parsed) : null,
          child: const Text('حفظ الدفعة'),
        ),
      ],
    );
  }
}

class _DebtInvoiceTile extends StatelessWidget {
  const _DebtInvoiceTile({
    required this.record,
    required this.onRecordPayment,
    required this.onExportPdf,
  });

  final _DebtRecord record;
  final VoidCallback onRecordPayment;
  final VoidCallback onExportPdf;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            title: Text(record.invoiceNumber),
            subtitle: Text(
              '${formatDateTime(record.createdAt)}\n'
              'الإجمالي ${formatMoneyMinor(record.totalMinor)} · مدفوع ${formatMoneyMinor(record.paidMinor)} · '
              'المتبقي ${formatMoneyMinor(record.remainingMinor)}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (context) => _DebtInvoiceDetails(record: record),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 10,
              end: 10,
              bottom: 4,
            ),
            child: Wrap(
              alignment: WrapAlignment.start,
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: onRecordPayment,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('تسجيل دفعة'),
                ),
                IconButton(
                  tooltip: 'تصدير الفاتورة PDF',
                  onPressed: onExportPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                ),
                Text(
                  record.remainingMinor > 0 ? 'آجلة' : 'كاملة السداد',
                  style: TextStyle(
                    color: colors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 14),
        ],
      ),
    );
  }
}

class _DebtInvoiceDetails extends StatelessWidget {
  const _DebtInvoiceDetails({required this.record});

  final _DebtRecord record;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            record.invoiceNumber,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  record.partyName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'إغلاق تفاصيل الفاتورة',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Text(formatDateTime(record.createdAt)),
          const Divider(height: 24),
          for (final line in record.lines)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(line.name),
              subtitle: Text(
                '${formatQuantity(line.quantity)} × ${formatMoneyMinor(line.unitPriceMinor)}',
              ),
              trailing: Text(formatMoneyMinor(line.totalMinor)),
            ),
          const Divider(height: 24),
          _amountLine('الإجمالي', record.totalMinor),
          _amountLine('المدفوع', record.paidMinor),
          _amountLine('المتبقي', record.remainingMinor),
          const SizedBox(height: 14),
          Text(
            'سجل الدفعات',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (record.payments.isEmpty)
            const ListTile(title: Text('لا توجد دفعات مسجلة.'))
          else
            for (final payment in record.payments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(formatMoneyMinor(payment.amountMinor)),
                subtitle: Text(formatDateTime(payment.occurredAt)),
              ),
          Text(
            record.remainingMinor <= 0
                ? 'حالة السداد: كاملة'
                : 'حالة السداد: آجلة',
          ),
        ],
      ),
    );
  }

  Widget _amountLine(String label, int value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          formatMoneyMinor(value),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
