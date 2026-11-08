import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../data/purchases_repository.dart';

class ImportedInvoiceRow {
  const ImportedInvoiceRow({
    required this.productName,
    required this.purchasePrice,
    required this.salePrice,
    required this.quantity,
    required this.sourceLine,
  });

  final String productName;
  final String purchasePrice;
  final String salePrice;
  final String quantity;
  final String sourceLine;
}

class InvoiceImportParser {
  static final _numberPattern = RegExp(r'[-+]?\d+(?:[.,٫٬]\d+)?');
  static const _arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  static const _persianDigits = '۰۱۲۳۴۵۶۷۸۹';
  static const _westernDigits = '0123456789';

  static List<ImportedInvoiceRow> parse(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) return const [];

    var headerIndex = -1;
    List<String>? headers;
    for (var index = 0; index < lines.length; index++) {
      final fields = _splitColumns(lines[index]);
      if (_looksLikeHeader(lines[index], fields)) {
        headerIndex = index;
        headers = fields;
        break;
      }
    }

    final rows = <ImportedInvoiceRow>[];
    for (var index = 0; index < lines.length; index++) {
      if (index == headerIndex) continue;
      final line = lines[index];
      final fields = _splitColumns(line);
      ImportedInvoiceRow? parsed;
      if (headers != null && fields.length >= headers.length) {
        parsed = _parseWithHeaders(line, fields, headers);
      }
      parsed ??= _parseByNumbers(line);
      if (parsed != null && parsed.productName.isNotEmpty) rows.add(parsed);
    }
    return rows;
  }

  static ImportedInvoiceRow? _parseWithHeaders(
    String line,
    List<String> values,
    List<String> headers,
  ) {
    final nameIndex = _columnIndex(headers, const [
      'اسم',
      'الصنف',
      'المنتج',
      'product',
      'item',
      'name',
    ]);
    final purchaseIndex = _columnIndex(headers, const [
      'سعر الشراء',
      'شراء',
      'التكلفة',
      'purchase',
      'cost',
      'buy',
    ]);
    final saleIndex = _columnIndex(headers, const [
      'سعر البيع',
      'بيع',
      'sale',
      'retail',
    ]);
    final quantityIndex = _columnIndex(headers, const [
      'الكمية',
      'كمية',
      'العدد',
      'quantity',
      'qty',
    ]);
    if (nameIndex < 0 || purchaseIndex < 0 || quantityIndex < 0) return null;

    String valueAt(int column) => column < 0 || column >= values.length
        ? ''
        : _normalizeNumber(values[column]);

    return ImportedInvoiceRow(
      productName: values[nameIndex].trim(),
      purchasePrice: valueAt(purchaseIndex),
      salePrice: valueAt(saleIndex),
      quantity: valueAt(quantityIndex),
      sourceLine: line,
    );
  }

  static ImportedInvoiceRow? _parseByNumbers(String line) {
    final normalized = _normalizeDigits(line);
    final matches = _numberPattern.allMatches(normalized).toList();
    if (matches.isEmpty) return null;
    final first = matches.first;
    final name = normalized
        .substring(0, first.start)
        .replaceAll(RegExp(r'[|;,:،\-–—]+\s*$'), '')
        .trim();
    if (name.isEmpty) return null;

    final numbers = matches.map((match) => match.group(0) ?? '').toList();
    final purchasePrice = numbers.first;
    final salePrice = numbers.length >= 3 ? numbers[1] : '';
    final quantity = numbers.length >= 3 ? numbers.last : numbers.last;
    return ImportedInvoiceRow(
      productName: name,
      purchasePrice: purchasePrice,
      salePrice: salePrice,
      quantity: quantity,
      sourceLine: line,
    );
  }

  static List<String> _splitColumns(String line) {
    final normalized = _normalizeDigits(line);
    if (normalized.contains('\t')) {
      return normalized.split('\t').map((x) => x.trim()).toList();
    }
    if (normalized.contains('|')) {
      return normalized.split('|').map((x) => x.trim()).toList();
    }
    if (normalized.contains(';')) {
      return normalized.split(';').map((x) => x.trim()).toList();
    }
    if (normalized.contains(',')) {
      return normalized.split(',').map((x) => x.trim()).toList();
    }
    final spaced = normalized.split(RegExp(r'\s{2,}'));
    return spaced.length > 1
        ? spaced.map((x) => x.trim()).toList()
        : [normalized];
  }

  static bool _looksLikeHeader(String line, List<String> fields) {
    final value = line.toLowerCase();
    final mentionsProduct =
        value.contains('الصنف') ||
        value.contains('المنتج') ||
        value.contains('اسم') ||
        value.contains('product') ||
        value.contains('item');
    final mentionsMeasure =
        value.contains('سعر') ||
        value.contains('شراء') ||
        value.contains('بيع') ||
        value.contains('كمية') ||
        value.contains('quantity') ||
        value.contains('price');
    return fields.length > 1 && mentionsProduct && mentionsMeasure;
  }

  static int _columnIndex(List<String> columns, List<String> terms) {
    for (var index = 0; index < columns.length; index++) {
      final value = columns[index].toLowerCase();
      if (terms.any(value.contains)) return index;
    }
    return -1;
  }

  static String _normalizeDigits(String value) {
    final result = StringBuffer();
    for (var index = 0; index < value.length; index++) {
      final char = value[index];
      final arabicIndex = _arabicDigits.indexOf(char);
      final persianIndex = _persianDigits.indexOf(char);
      if (arabicIndex >= 0) {
        result.write(_westernDigits[arabicIndex]);
      } else if (persianIndex >= 0) {
        result.write(_westernDigits[persianIndex]);
      } else {
        result.write(char);
      }
    }
    return result.toString();
  }

  static String _normalizeNumber(String value) =>
      _normalizeDigits(value)
          .replaceAll('٫', '.')
          .replaceAll('٬', '')
          .replaceAll(',', '.')
          .trim();
}

Future<List<PurchaseLineDraft>?> showInvoiceImportReview(
  BuildContext context, {
  required List<ImportedInvoiceRow> rows,
  required String sourceLabel,
}) => showModalBottomSheet<List<PurchaseLineDraft>>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  builder: (_) => FractionallySizedBox(
    heightFactor: 0.94,
    child: InvoiceImportReviewSheet(rows: rows, sourceLabel: sourceLabel),
  ),
);

class InvoiceImportReviewSheet extends StatefulWidget {
  const InvoiceImportReviewSheet({
    super.key,
    required this.rows,
    required this.sourceLabel,
  });

  final List<ImportedInvoiceRow> rows;
  final String sourceLabel;

  @override
  State<InvoiceImportReviewSheet> createState() =>
      _InvoiceImportReviewSheetState();
}

class _InvoiceImportReviewSheetState extends State<InvoiceImportReviewSheet> {
  late final List<_EditableImportRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.rows.map(_EditableImportRow.fromImported).toList();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  bool _isValid(_EditableImportRow row) {
    final purchase = parseMoneyMinor(row.purchasePrice.text);
    final sale = parseMoneyMinor(row.salePrice.text);
    final quantity = parseQuantity(row.quantity.text);
    return row.name.text.trim().isNotEmpty &&
        purchase != null &&
        purchase >= 0 &&
        sale != null &&
        sale >= 0 &&
        quantity != null &&
        quantity > 0;
  }

  void _addToInvoice() {
    if (_rows.isEmpty || _rows.any((row) => !_isValid(row))) {
      setState(() {});
      return;
    }
    Navigator.of(context).pop(
      _rows
          .map(
            (row) => PurchaseLineDraft(
              productName: row.name.text.trim(),
              purchasePriceMinor: parseMoneyMinor(row.purchasePrice.text)!,
              salePriceMinor: parseMoneyMinor(row.salePrice.text)!,
              quantity: parseQuantity(row.quantity.text)!,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final allValid = _rows.isNotEmpty && _rows.every(_isValid);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'مراجعة البيانات المستخرجة',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
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
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'من ${widget.sourceLabel}. راجع الاسم والأسعار والكمية قبل إضافة الأصناف إلى الفاتورة؛ قد يخطئ الاستخراج في قراءة الأرقام.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _rows.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'لم نستخرج صفوفًا يمكن مراجعتها. أضف الصنف يدويًا من فاتورة الشراء.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        20,
                        0,
                        20,
                        20,
                      ),
                      itemCount: _rows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final row = _rows[index];
                        final valid = _isValid(row);
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'الصنف ${index + 1}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: valid
                                            ? colors.secondaryContainer
                                            : colors.errorContainer,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        valid
                                            ? 'راجع قبل الإضافة'
                                            : 'بيانات ناقصة',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: valid
                                                  ? colors.onSecondaryContainer
                                                  : colors.onErrorContainer,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'حذف هذا الصف',
                                      onPressed: () => setState(() {
                                        _rows.removeAt(index).dispose();
                                      }),
                                      icon: const Icon(Icons.close_rounded),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: row.name,
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                    labelText: 'اسم الصنف',
                                    isDense: true,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final purchaseField = _ReviewNumberField(
                                      label: 'سعر الشراء',
                                      controller: row.purchasePrice,
                                      onChanged: () => setState(() {}),
                                    );
                                    final saleField = _ReviewNumberField(
                                      label: 'سعر البيع',
                                      controller: row.salePrice,
                                      onChanged: () => setState(() {}),
                                    );
                                    if (constraints.maxWidth < 420) {
                                      return Column(
                                        children: [
                                          purchaseField,
                                          const SizedBox(height: 8),
                                          saleField,
                                          const SizedBox(height: 8),
                                          _ReviewNumberField(
                                            label: 'الكمية',
                                            controller: row.quantity,
                                            onChanged: () => setState(() {}),
                                          ),
                                        ],
                                      );
                                    }
                                    return Row(
                                      children: [
                                        Expanded(child: purchaseField),
                                        const SizedBox(width: 8),
                                        Expanded(child: saleField),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _ReviewNumberField(
                                            label: 'الكمية',
                                            controller: row.quantity,
                                            onChanged: () => setState(() {}),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                if (!valid) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'أكمل الحقول المظللة قبل إضافة هذا الصنف.',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: colors.error),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 18),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('إلغاء'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: allValid ? _addToInvoice : null,
                      icon: const Icon(Icons.playlist_add_rounded),
                      label: const Text('إضافة الأصناف إلى الفاتورة'),
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

class _EditableImportRow {
  _EditableImportRow({
    required this.name,
    required this.purchasePrice,
    required this.salePrice,
    required this.quantity,
  });

  factory _EditableImportRow.fromImported(ImportedInvoiceRow row) =>
      _EditableImportRow(
        name: TextEditingController(text: row.productName),
        purchasePrice: TextEditingController(text: row.purchasePrice),
        salePrice: TextEditingController(text: row.salePrice),
        quantity: TextEditingController(text: row.quantity),
      );

  final TextEditingController name;
  final TextEditingController purchasePrice;
  final TextEditingController salePrice;
  final TextEditingController quantity;

  void dispose() {
    name.dispose();
    purchasePrice.dispose();
    salePrice.dispose();
    quantity.dispose();
  }
}

class _ReviewNumberField extends StatelessWidget {
  const _ReviewNumberField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: (_) => onChanged(),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    textDirection: TextDirection.ltr,
    decoration: InputDecoration(
      labelText: label,
      suffixText: 'ج.م',
      isDense: true,
    ),
  );
}
