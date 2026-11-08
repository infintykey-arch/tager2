import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/formatters.dart';
import '../domain/product.dart';

class ProductFormSheet extends StatefulWidget {
  const ProductFormSheet({super.key, this.product});

  final Product? product;

  @override
  State<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _salePriceController;
  late final TextEditingController _codeController;
  late final TextEditingController _openingStockController;
  String _codeType = 'barcode';

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _purchasePriceController = TextEditingController(
      text: product == null
          ? ''
          : (product.purchasePriceMinor / 100).toStringAsFixed(2),
    );
    _salePriceController = TextEditingController(
      text: product == null
          ? ''
          : (product.salePriceMinor / 100).toStringAsFixed(2),
    );
    _codeController = TextEditingController(text: product?.codeValue ?? '');
    _codeType = product?.codeType ?? 'barcode';
    _openingStockController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    _codeController.dispose();
    _openingStockController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final product = widget.product;
    final result = Product(
      id: product?.id,
      name: _nameController.text.trim(),
      purchasePriceMinor: parseMoneyMinor(_purchasePriceController.text)!,
      salePriceMinor: parseMoneyMinor(_salePriceController.text)!,
      minimumStock: product?.minimumStock ?? 10,
      stockOnHand: _isEditing
          ? product!.stockOnHand
          : parseQuantity(_openingStockController.text)!,
      codeValue: _codeController.text.trim().isEmpty
          ? null
          : _codeController.text.trim(),
      codeType: _codeController.text.trim().isEmpty ? null : _codeType,
      createdAt: product?.createdAt,
      updatedAt: product?.updatedAt,
    );
    Navigator.of(context).pop(result);
  }

  String? _validateMoney(String? value) {
    if (parseMoneyMinor(value ?? '') == null) {
      return 'أدخل مبلغًا صحيحًا حتى قرشين عشريين.';
    }
    return null;
  }

  String? _validateQuantity(String? value, {required bool allowZero}) {
    final quantity = parseQuantity(value ?? '');
    if (quantity == null || (!allowZero && quantity <= 0)) {
      return allowZero
          ? 'أدخل كمية صحيحة حتى ٣ منازل عشرية.'
          : 'أدخل كمية أكبر من صفر وحتى ٣ منازل عشرية.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(20, 8, 20, bottomInset + 20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4DEDA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _isEditing ? 'تعديل بيانات المنتج' : 'إضافة منتج جديد',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  autofocus: !_isEditing,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'اسم المنتج',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'اكتب اسم المنتج.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _purchasePriceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9٠-٩۰-۹.,٬٫]'),
                    ),
                  ],
                  textDirection: TextDirection.ltr,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'سعر الشراء المرجعي (جنيه)',
                    prefixIcon: Icon(Icons.shopping_bag_outlined),
                  ),
                  validator: _validateMoney,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _salePriceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9٠-٩۰-۹.,٬٫]'),
                    ),
                  ],
                  textDirection: TextDirection.ltr,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'سعر البيع (جنيه)',
                    prefixIcon: Icon(Icons.sell_outlined),
                  ),
                  validator: _validateMoney,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _codeController,
                  textDirection: TextDirection.ltr,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'قيمة الباركود أو QR (اختياري)',
                    prefixIcon: Icon(Icons.qr_code_2_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _codeType,
                  decoration: const InputDecoration(labelText: 'نوع الكود'),
                  items: const [
                    DropdownMenuItem(value: 'barcode', child: Text('باركود')),
                    DropdownMenuItem(value: 'qr', child: Text('QR')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _codeType = value);
                  },
                ),
                if (!_isEditing) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _openingStockController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9٠-٩۰-۹.,٬٫]'),
                      ),
                    ],
                    textDirection: TextDirection.ltr,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'الكمية الحالية عند الإضافة',
                      prefixIcon: Icon(Icons.warehouse_outlined),
                    ),
                    validator: (value) =>
                        _validateQuantity(value, allowZero: true),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2F8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _isEditing
                        ? 'تغيير الكمية يتم من حركة مخزون مستقلة. تعديل سعر الشراء المرجعي لا يغيّر متوسط تكلفة المخزون السابق.'
                        : 'يُقيَّم الرصيد الافتتاحي بهذا السعر المرجعي. بعد ذلك يحسب التطبيق متوسط تكلفة متحركًا عند كل فاتورة شراء.',
                    style: const TextStyle(
                      height: 1.45,
                      color: Color(0xFF38576B),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _submit,
                  child: Text(_isEditing ? 'حفظ التعديلات' : 'إضافة المنتج'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إلغاء'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
