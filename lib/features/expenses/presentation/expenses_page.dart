import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../data/expenses_repository.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key, required this.repository});

  final ExpensesRepository repository;

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  late Future<_ExpenseSnapshot> _snapshotFuture;
  DateTimeRange? _selectedRange;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _loadSnapshot();
  }

  Future<_ExpenseSnapshot> _loadSnapshot() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month);
    final nextMonthStart = DateTime(now.year, now.month + 1);
    final todayTotal = await widget.repository.getTotalBetween(
      todayStart,
      todayStart.add(const Duration(days: 1)),
    );
    final monthTotal = await widget.repository.getTotalBetween(
      monthStart,
      nextMonthStart,
    );
    final range = _selectedRange;
    final rangeStart = range == null
        ? null
        : DateTime(range.start.year, range.start.month, range.start.day);
    final rangeEnd = range == null
        ? null
        : DateTime(
            range.end.year,
            range.end.month,
            range.end.day,
          ).add(const Duration(days: 1));
    final recent = rangeStart == null || rangeEnd == null
        ? await widget.repository.getRecent()
        : await widget.repository.getBetween(rangeStart, rangeEnd);
    final rangeTotal = rangeStart == null || rangeEnd == null
        ? null
        : await widget.repository.getTotalBetween(rangeStart, rangeEnd);
    return _ExpenseSnapshot(
      recent: recent,
      todayTotalMinor: todayTotal,
      monthTotalMinor: monthTotal,
      rangeTotalMinor: rangeTotal,
    );
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
  }

  Future<void> _chooseRange() async {
    final now = DateTime.now();
    final initial =
        _selectedRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day),
        );
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: initial,
      helpText: 'اختر فترة المصروفات',
      saveText: 'عرض الفترة',
    );
    if (range == null || !mounted) return;
    setState(() => _selectedRange = range);
    _refresh();
  }

  Future<void> _createExpense() async {
    final draft = await showModalBottomSheet<ExpenseDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.82,
        child: const ExpenseEditorSheet(),
      ),
    );
    if (draft == null || !mounted) return;

    try {
      await widget.repository.createExpense(draft);
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('تم تسجيل المصروف.')));
    } catch (error) {
      if (!mounted) return;
      final message = error is ArgumentError
          ? error.toString().replaceFirst('Invalid argument(s): ', '')
          : 'تعذر حفظ المصروف. حاول مرة أخرى.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ExpenseSnapshot>(
      future: _snapshotFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('تعذر تحميل المصروفات.'),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          );
        }

        final data = snapshot.data!;
        return ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 100),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ExpenseTotalCard(
                    title: 'مصروفات اليوم',
                    amountMinor: data.todayTotalMinor,
                  ),
                  _ExpenseTotalCard(
                    title: 'مصروفات هذا الشهر',
                    amountMinor: data.monthTotalMinor,
                  ),
                  if (data.rangeTotalMinor != null)
                    _ExpenseTotalCard(
                      title: 'مصروفات الفترة المحددة',
                      amountMinor: data.rangeTotalMinor!,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _createExpense,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('تسجيل مصروف'),
                ),
                OutlinedButton.icon(
                  onPressed: _chooseRange,
                  icon: const Icon(Icons.date_range_rounded),
                  label: Text(
                    _selectedRange == null ? 'تحديد فترة' : 'تغيير الفترة',
                  ),
                ),
                if (_selectedRange != null)
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _selectedRange = null);
                      _refresh();
                    },
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('مسح الفترة'),
                  ),
              ],
            ),
            if (_selectedRange != null) ...[
              const SizedBox(height: 8),
              Text(
                'الفترة: ${_formatDate(_selectedRange!.start)} – '
                '${_formatDate(_selectedRange!.end)} · ${data.recent.length} سجل',
              ),
            ],
            const SizedBox(height: 14),
            Text(
              data.rangeTotalMinor == null
                  ? 'أحدث المصروفات'
                  : 'مصروفات الفترة المحددة',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (data.recent.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Center(
                    child: Text(
                      data.rangeTotalMinor == null
                          ? 'لا توجد مصروفات مسجلة بعد.'
                          : 'لا توجد مصروفات في هذه الفترة.',
                    ),
                  ),
                ),
              )
            else
              for (final expense in data.recent)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.receipt_long_outlined),
                    ),
                    title: Text(expense.category),
                    subtitle: Text(
                      [
                        if (expense.description != null &&
                            expense.description!.isNotEmpty)
                          expense.description!,
                        if (expense.location != null &&
                            expense.location!.isNotEmpty)
                          'المكان: ${expense.location}',
                        formatDateTime(expense.occurredAt),
                      ].join(' · '),
                    ),
                    trailing: Text(
                      formatMoneyMinor(expense.amountMinor),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _ExpenseTotalCard extends StatelessWidget {
  const _ExpenseTotalCard({required this.title, required this.amountMinor});

  final String title;
  final int amountMinor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              const SizedBox(height: 4),
              Text(
                formatMoneyMinor(amountMinor),
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseSnapshot {
  const _ExpenseSnapshot({
    required this.recent,
    required this.todayTotalMinor,
    required this.monthTotalMinor,
    required this.rangeTotalMinor,
  });

  final List<ExpenseEntry> recent;
  final int todayTotalMinor;
  final int monthTotalMinor;
  final int? rangeTotalMinor;
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

class ExpenseEditorSheet extends StatefulWidget {
  const ExpenseEditorSheet({super.key});

  @override
  State<ExpenseEditorSheet> createState() => _ExpenseEditorSheetState();
}

class _ExpenseEditorSheetState extends State<ExpenseEditorSheet> {
  static const _categories = [
    'إيجار',
    'مرتبات',
    'كهرباء',
    'مياه',
    'نقل',
    'صيانة',
    'أخرى',
  ];

  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _amountController = TextEditingController();
  String _category = _categories.first;
  DateTime _occurredAt = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'اختر تاريخ المصروف',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
      helpText: 'اختر وقت المصروف',
    );
    if (time == null || !mounted) return;
    setState(() {
      _occurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _save() {
    final amountMinor = parseMoneyMinor(_amountController.text);
    if (amountMinor == null || amountMinor <= 0) {
      setState(
        () => _error = 'أدخل مبلغًا أكبر من صفر وبحد أقصى منزلتين عشريتين.',
      );
      return;
    }
    Navigator.of(context).pop(
      ExpenseDraft(
        category: _category,
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        amountMinor: amountMinor,
        requestKey: 'expense-${DateTime.now().microsecondsSinceEpoch}',
        occurredAt: _occurredAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'تسجيل مصروف',
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
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 24),
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'نوع المصروف'),
                    items: [
                      for (final category in _categories)
                        DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _category = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.calendar_month_rounded),
                      title: const Text('تاريخ ووقت العملية'),
                      subtitle: Text(formatDateTime(_occurredAt)),
                      trailing: const Icon(Icons.edit_calendar_rounded),
                      onTap: _selectDateTime,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ',
                      suffixText: 'ج.م',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'ماذا صُرف؟ (تفاصيل اختيارية)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'أين صُرف؟ (اختياري)',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: TextStyle(color: colors.error)),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 18),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('حفظ المصروف'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
