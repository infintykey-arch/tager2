import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../data/sales_repository.dart';
import '../domain/sale_cart_line.dart';

class SalesInvoiceSheet extends StatefulWidget {
  const SalesInvoiceSheet({
    super.key,
    required this.initialLines,
    required this.salesRepository,
    required this.onCartChanged,
  });

  final List<SaleCartLine> initialLines;
  final SalesRepository salesRepository;
  final ValueChanged<List<SaleCartLine>> onCartChanged;

  @override
  State<SalesInvoiceSheet> createState() => _SalesInvoiceSheetState();
}

class _SalesInvoiceSheetState extends State<SalesInvoiceSheet> {
  final _customerNameController = TextEditingController();
  final _amountPaidController = TextEditingController();
  late final String _requestKey;
  late final Map<int, SaleCartLine> _lines;
  SalePaymentKind _paymentKind = SalePaymentKind.cash;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _requestKey = 'sale-${DateTime.now().microsecondsSinceEpoch}';
    _lines = {
      for (final line in widget.initialLines)
        if (line.product.id != null) line.product.id!: line,
    };
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _amountPaidController.dispose();
    super.dispose();
  }

  int get _totalMinor => _lines.values.fold<int>(
    0,
    (total, line) =>
        total + (line.product.salePriceMinor * line.quantity).round(),
  );

  int? get _enteredPaidMinor {
    if (_amountPaidController.text.trim().isEmpty) return 0;
    return parseMoneyMinor(_amountPaidController.text);
  }

  void _emitCart() {
    widget.onCartChanged(_lines.values.toList(growable: false));
  }

  void _addOne(int productId) {
    final line = _lines[productId];
    if (line == null) return;
    final next = line.quantity + 1;
    if (next > line.product.stockOnHand + 0.0000001) {
      setState(() {
        _error =
            'الكمية المتاحة من «${line.product.name}» هي '
            '${formatQuantity(line.product.stockOnHand)} فقط.';
      });
      return;
    }
    setState(() {
      _lines[productId] = line.withQuantity(next);
      _error = null;
    });
    _emitCart();
  }

  void _removeOne(int productId) {
    final line = _lines[productId];
    if (line == null) return;
    if (line.quantity <= 1) {
      _removeLine(productId);
      return;
    }
    setState(() {
      _lines[productId] = line.withQuantity(line.quantity - 1);
      _error = null;
    });
    _emitCart();
  }

  void _removeLine(int productId) {
    setState(() {
      _lines.remove(productId);
      _error = null;
    });
    _emitCart();
  }

  Future<void> _editQuantity(SaleCartLine line) async {
    final controller = TextEditingController(
      text: formatQuantity(line.quantity),
    );
    final quantity = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('كمية ${line.product.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'الكمية',
            helperText: 'يمكن إدخال حتى ثلاث خانات عشرية.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(parseQuantity(controller.text)),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (quantity == null) return;
    if (!quantity.isFinite || quantity <= 0) {
      setState(() => _error = 'أدخل كمية أكبر من صفر.');
      return;
    }
    if (quantity > line.product.stockOnHand + 0.0000001) {
      setState(
        () => _error =
            'المتاح من «${line.product.name}» هو '
            '${formatQuantity(line.product.stockOnHand)} فقط.',
      );
      return;
    }
    final productId = line.product.id;
    if (productId == null) return;
    setState(() {
      _lines[productId] = line.withQuantity(quantity);
      _error = null;
    });
    _emitCart();
  }

  Future<void> _confirmSale() async {
    if (_lines.isEmpty) {
      setState(() => _error = 'أضف صنفًا واحدًا على الأقل.');
      return;
    }
    final customerName = _customerNameController.text.trim();
    final paidMinor = _enteredPaidMinor;
    if (_paymentKind == SalePaymentKind.credit && customerName.isEmpty) {
      setState(() => _error = 'اكتب اسم العميل للبيع الآجل.');
      return;
    }
    if (_paymentKind == SalePaymentKind.credit && paidMinor == null) {
      setState(() => _error = 'أدخل مبلغًا صحيحًا بالجنيه المصري.');
      return;
    }
    if (_paymentKind == SalePaymentKind.credit && paidMinor! > _totalMinor) {
      setState(() => _error = 'المبلغ المدفوع أكبر من إجمالي الفاتورة.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final receipt = await widget.salesRepository.createSale(
        SaleDraft(
          lines: _lines.entries
              .map(
                (entry) => SaleLineDraft(
                  productId: entry.key,
                  quantity: entry.value.quantity,
                ),
              )
              .toList(growable: false),
          paymentKind: _paymentKind,
          customerName: _paymentKind == SalePaymentKind.credit
              ? customerName
              : null,
          amountPaidMinor: _paymentKind == SalePaymentKind.credit
              ? paidMinor!
              : 0,
          requestKey: _requestKey,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(receipt);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(error);
        _saving = false;
      });
    }
  }

  String _friendlyError(Object error) {
    if (error is StateError || error is ArgumentError) {
      return error.toString().replaceFirst('Bad state: ', '');
    }
    return 'تعذر حفظ الفاتورة. لم يتم تغيير المخزون؛ حاول مرة أخرى.';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'فاتورة بيع جديدة',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _lines.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shopping_cart_outlined, size: 42),
                            const SizedBox(height: 12),
                            const Text('لا توجد أصناف في الفاتورة.'),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('إضافة أصناف'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        20,
                        4,
                        20,
                        16,
                      ),
                      children: [
                        for (final entry in _lines.entries)
                          _SaleLineCard(
                            key: ValueKey(entry.key),
                            line: entry.value,
                            onIncrease: () => _addOne(entry.key),
                            onDecrease: () => _removeOne(entry.key),
                            onEditQuantity: () => _editQuantity(entry.value),
                            onRemove: () => _removeLine(entry.key),
                          ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('إضافة أصناف أخرى'),
                        ),
                      ],
                    ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 18),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.outlineVariant)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<SalePaymentKind>(
                    segments: const [
                      ButtonSegment(
                        value: SalePaymentKind.cash,
                        label: Text('نقدي'),
                        icon: Icon(Icons.payments_outlined),
                      ),
                      ButtonSegment(
                        value: SalePaymentKind.credit,
                        label: Text('آجل'),
                        icon: Icon(Icons.account_balance_wallet_outlined),
                      ),
                    ],
                    selected: {_paymentKind},
                    onSelectionChanged: _saving
                        ? null
                        : (selection) => setState(() {
                            _paymentKind = selection.first;
                            _error = null;
                          }),
                  ),
                  if (_paymentKind == SalePaymentKind.credit) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _customerNameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'اسم العميل',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountPaidController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() => _error = null),
                      decoration: const InputDecoration(
                        labelText: 'كم دفع العميل؟',
                        suffixText: 'ج.م',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _SummaryLine(
                    label: 'إجمالي الفاتورة',
                    value: formatMoneyMinor(_totalMinor),
                    isStrong: true,
                  ),
                  if (_paymentKind == SalePaymentKind.cash)
                    _SummaryLine(
                      label: 'المدفوع',
                      value: formatMoneyMinor(_totalMinor),
                    )
                  else if (_enteredPaidMinor != null)
                    _SummaryLine(
                      label: 'المتبقي على العميل',
                      value: formatMoneyMinor(_totalMinor - _enteredPaidMinor!),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(color: colors.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _saving || _lines.isEmpty ? null : _confirmSale,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      _saving
                          ? 'جارٍ الحفظ'
                          : _paymentKind == SalePaymentKind.cash
                          ? 'تأكيد البيع النقدي'
                          : 'تأكيد البيع الآجل',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleLineCard extends StatelessWidget {
  const _SaleLineCard({
    super.key,
    required this.line,
    required this.onIncrease,
    required this.onDecrease,
    required this.onEditQuantity,
    required this.onRemove,
  });

  final SaleCartLine line;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onEditQuantity;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final product = line.product;
    final lineTotal = (product.salePriceMinor * line.quantity).round();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'حذف من الفاتورة',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            Text(
              '${formatMoneyMinor(product.salePriceMinor)} × '
              '${formatQuantity(line.quantity)} = ${formatMoneyMinor(lineTotal)}',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                IconButton(
                  tooltip: 'تقليل الكمية',
                  onPressed: onDecrease,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
                InkWell(
                  onTap: onEditQuantity,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      formatQuantity(line.quantity),
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'زيادة الكمية',
                  onPressed: onIncrease,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
                const Spacer(),
                Text(
                  'المتاح: ${formatQuantity(product.stockOnHand)}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.isStrong = false,
  });

  final String label;
  final String value;
  final bool isStrong;

  @override
  Widget build(BuildContext context) {
    final style = isStrong
        ? Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
