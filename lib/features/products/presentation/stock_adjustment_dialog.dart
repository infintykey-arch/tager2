import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/formatters.dart';

class StockAdjustment {
  const StockAdjustment({required this.quantityDelta, required this.note});

  final double quantityDelta;
  final String note;
}

class StockAdjustmentDialog extends StatefulWidget {
  const StockAdjustmentDialog({super.key});

  @override
  State<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<StockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();
  int _direction = 1;

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final quantity = parseQuantity(_quantityController.text)!;
    Navigator.of(context).pop(
      StockAdjustment(
        quantityDelta: quantity * _direction,
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تسوية المخزون'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.add_rounded),
                  label: Text('إضافة'),
                ),
                ButtonSegment(
                  value: -1,
                  icon: Icon(Icons.remove_rounded),
                  label: Text('خصم'),
                ),
              ],
              selected: {_direction},
              onSelectionChanged: (selection) =>
                  setState(() => _direction = selection.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹.,٬٫]')),
              ],
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'الكمية'),
              validator: (value) {
                final quantity = parseQuantity(value ?? '');
                return quantity == null || quantity <= 0
                    ? 'أدخل كمية أكبر من صفر.'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'سبب الحركة'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'اكتب سببًا لتوثيق الحركة.'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const Text('تسجيل الحركة')),
      ],
    );
  }
}
