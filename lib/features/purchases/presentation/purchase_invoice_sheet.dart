import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/formatters.dart';
import '../../ocr/data/invoice_ocr_service.dart';
import '../../products/data/products_repository.dart';
import '../../products/domain/product.dart';
import '../../products/domain/product_search.dart';
import '../data/purchases_repository.dart';
import 'invoice_import_review_sheet.dart';

class PurchaseInvoiceSheet extends StatefulWidget {
  const PurchaseInvoiceSheet({
    super.key,
    required this.productsRepository,
    required this.purchasesRepository,
    this.initialImportText,
  });

  final ProductsRepository productsRepository;
  final PurchasesRepository purchasesRepository;
  final String? initialImportText;

  @override
  State<PurchaseInvoiceSheet> createState() => _PurchaseInvoiceSheetState();
}

class _PurchaseInvoiceSheetState extends State<PurchaseInvoiceSheet> {
  final _supplierController = TextEditingController();
  final _paidController = TextEditingController();
  final List<PurchaseLineDraft> _lines = [];
  late final String _requestKey;
  String? _error;
  bool _saving = false;
  bool _ocrBusy = false;

  @override
  void initState() {
    super.initState();
    _requestKey = 'purchase-${DateTime.now().microsecondsSinceEpoch}';
    final initialImportText = widget.initialImportText;
    if (initialImportText != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _reviewImportedText(initialImportText, sourceLabel: 'النص المستخرج');
        }
      });
    }
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _paidController.dispose();
    super.dispose();
  }

  int get _totalMinor => _lines.fold<int>(
    0,
    (total, line) => total + (line.purchasePriceMinor * line.quantity).round(),
  );

  int? get _paidMinor {
    if (_paidController.text.trim().isEmpty) return 0;
    return parseMoneyMinor(_paidController.text);
  }

  Future<void> _addLine({int? editIndex}) async {
    final line = await showModalBottomSheet<PurchaseLineDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: PurchaseLineEditor(
          productsRepository: widget.productsRepository,
          initialLine: editIndex == null ? null : _lines[editIndex],
        ),
      ),
    );
    if (line == null || !mounted) return;
    setState(() {
      if (editIndex == null) {
        _lines.add(line);
      } else {
        _lines[editIndex] = line;
      }
      _error = null;
    });
  }

  Future<void> _readInvoiceFile() async {
    if (_saving || _ocrBusy) return;
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'bmp',
          'tif',
          'tiff',
          'pdf',
        ],
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        setState(() => _error = 'تعذر قراءة ملف الصورة من الجهاز.');
        return;
      }

      setState(() {
        _ocrBusy = true;
        _error = null;
      });
      final ocrService = const LocalInvoiceOcrService();
      final text = file.extension?.toLowerCase() == 'pdf'
          ? await ocrService.recognizePdf(bytes: bytes, localPath: file.path)
          : await ocrService.recognizeImage(
              bytes: bytes,
              localPath: file.path,
              mimeType: _mimeTypeFor(file.extension),
            );
      if (!mounted) return;
      await _reviewImportedText(text, sourceLabel: 'الصورة أو ملف PDF');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyOcrError(error));
    } finally {
      if (mounted) setState(() => _ocrBusy = false);
    }
  }

  String _mimeTypeFor(String? extension) => switch (extension?.toLowerCase()) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'bmp' => 'image/bmp',
    'tif' || 'tiff' => 'image/tiff',
    _ => 'image/jpeg',
  };

  String _friendlyOcrError(Object error) {
    if (error is StateError ||
        error is ArgumentError ||
        error is UnsupportedError) {
      return error.toString().replaceFirst('Bad state: ', '');
    }
    return 'تعذرت قراءة الملف محليًا. جرّب صورة أو PDF أوضح.';
  }

  Future<void> _readProductFile() async {
    if (_saving || _ocrBusy) return;
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'tsv', 'txt'],
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        setState(() => _error = 'الملف فارغ. اختر ملفًا يحتوي على أصناف.');
        return;
      }
      final text = utf8.decode(bytes, allowMalformed: true);
      await _reviewImportedText(text, sourceLabel: 'ملف المنتجات');
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'تعذر قراءة الملف. استخدم ملف CSV أو TSV أو TXT.',
        );
      }
    }
  }

  Future<void> _reviewImportedText(
    String text, {
    required String sourceLabel,
  }) async {
    final parsedRows = InvoiceImportParser.parse(text);
    if (parsedRows.isEmpty) {
      if (mounted) {
        setState(
          () => _error =
              'لم نعثر على صفوف أصناف واضحة. يمكنك إدخال الصنف يدويًا أدناه.',
        );
      }
      return;
    }
    final reviewedLines = await showInvoiceImportReview(
      context,
      rows: parsedRows,
      sourceLabel: sourceLabel,
    );
    if (reviewedLines == null || !mounted) return;

    final existingProducts = await widget.productsRepository.getProducts(
      filter: ProductListFilter.allActive,
    );
    if (!mounted) return;
    final lines = reviewedLines
        .map((line) {
          final normalizedName = line.productName.trim().toLowerCase();
          final exactMatch = existingProducts.where(
            (product) => product.name.trim().toLowerCase() == normalizedName,
          );
          return PurchaseLineDraft(
            productId: exactMatch.isEmpty ? null : exactMatch.first.id,
            productName: line.productName,
            purchasePriceMinor: line.purchasePriceMinor,
            salePriceMinor: line.salePriceMinor,
            quantity: line.quantity,
          );
        })
        .toList(growable: false);
    setState(() {
      _lines.addAll(lines);
      _error = null;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('أُضيف ${lines.length} صنفًا للمراجعة في الفاتورة.'),
        ),
      );
  }

  Future<void> _confirmPurchase() async {
    final supplierName = _supplierController.text.trim();
    final paidMinor = _paidMinor;
    if (supplierName.isEmpty) {
      setState(() => _error = 'اكتب اسم المورد أولًا.');
      return;
    }
    if (_lines.isEmpty) {
      setState(() => _error = 'أضف صنفًا واحدًا على الأقل.');
      return;
    }
    if (paidMinor == null) {
      setState(() => _error = 'أدخل مبلغًا صحيحًا بالجنيه المصري.');
      return;
    }
    if (paidMinor > _totalMinor) {
      setState(() => _error = 'المبلغ المدفوع أكبر من إجمالي الفاتورة.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final receipt = await widget.purchasesRepository.createPurchase(
        PurchaseDraft(
          supplierName: supplierName,
          lines: List.unmodifiable(_lines),
          amountPaidMinor: paidMinor,
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
    return 'تعذر حفظ فاتورة الشراء. لم يتم تغيير المخزون؛ حاول مرة أخرى.';
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
                      'إضافة المنتجات',
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
                padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 16),
                children: [
                  Text(
                    'استيراد البيانات',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) => Row(
                      children: [
                        Expanded(
                          child: _ImportActionCard(
                            icon: Icons.upload_file_outlined,
                            title: 'رفع ملف المنتجات',
                            subtitle: 'CSV أو TSV أو TXT',
                            onTap: _saving || _ocrBusy
                                ? null
                                : _readProductFile,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ImportActionCard(
                            icon: _ocrBusy
                                ? Icons.hourglass_top_rounded
                                : Icons.document_scanner_outlined,
                            title: 'قراءة فاتورة',
                            subtitle: 'صورة أو PDF',
                            onTap: _saving || _ocrBusy
                                ? null
                                : _readInvoiceFile,
                            isBusy: _ocrBusy,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _supplierController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'اسم المورد أو شركة التوريدات',
                      prefixIcon: Icon(Icons.storefront_outlined),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'حدد فاتورة جديدة',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'أضف الأصناف يدويًا أو راجع البيانات المستوردة قبل الحفظ.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  if (_lines.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        'لا توجد أصناف في الفاتورة بعد.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  else
                    for (var index = 0; index < _lines.length; index++)
                      _PurchaseLineCard(
                        line: _lines[index],
                        onEdit: () => _addLine(editIndex: index),
                        onRemove: () => setState(() {
                          _lines.removeAt(index);
                          _error = null;
                        }),
                      ),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : () => _addLine(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('إضافة منتج جديد'),
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
                  TextField(
                    controller: _paidController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() => _error = null),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ المدفوع للمورد الآن',
                      helperText: 'اتركه فارغًا إذا لم تدفع شيئًا الآن.',
                      suffixText: 'ج.م',
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PurchaseSummaryLine(
                    label: 'إجمالي الشراء',
                    value: formatMoneyMinor(_totalMinor),
                    strong: true,
                  ),
                  if (_paidMinor != null)
                    _PurchaseSummaryLine(
                      label: 'المتبقي للمورد',
                      value: formatMoneyMinor(_totalMinor - _paidMinor!),
                    ),
                  _PurchaseSummaryLine(
                    label: 'تاريخ ووقت الفاتورة',
                    value: formatDateTime(DateTime.now()),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.error),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _saving || _lines.isEmpty
                        ? null
                        : _confirmPurchase,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(_saving ? 'جارٍ الحفظ' : 'حفظ فاتورة الشراء'),
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

class PurchaseLineEditor extends StatefulWidget {
  const PurchaseLineEditor({
    super.key,
    required this.productsRepository,
    this.initialLine,
  });

  final ProductsRepository productsRepository;
  final PurchaseLineDraft? initialLine;

  @override
  State<PurchaseLineEditor> createState() => _PurchaseLineEditorState();
}

class _PurchaseLineEditorState extends State<PurchaseLineEditor> {
  final _nameController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _quantityController = TextEditingController();
  late Future<List<Product>> _productsFuture;
  int? _selectedProductId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _productsFuture = widget.productsRepository.getProducts(
      filter: ProductListFilter.allActive,
    );
    final initial = widget.initialLine;
    if (initial != null) {
      _selectedProductId = initial.productId;
      _nameController.text = initial.productName;
      _purchasePriceController.text = _moneyInput(initial.purchasePriceMinor);
      _salePriceController.text = _moneyInput(initial.salePriceMinor);
      _quantityController.text = formatQuantity(initial.quantity);
    } else {
      _purchasePriceController.text = '0.00';
      _salePriceController.text = '0.00';
      _quantityController.text = '1';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  String _moneyInput(int minor) =>
      '${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}';

  void _selectProduct(Product? product) {
    setState(() {
      _selectedProductId = product?.id;
      if (product == null) {
        _nameController.clear();
        _purchasePriceController.text = '0.00';
        _salePriceController.text = '0.00';
      } else {
        _nameController.text = product.name;
        _purchasePriceController.text = _moneyInput(product.purchasePriceMinor);
        _salePriceController.text = _moneyInput(product.salePriceMinor);
      }
      _error = null;
    });
  }

  Future<void> _saveLine(List<Product> products) async {
    final name = _nameController.text.trim();
    final purchasePrice = parseMoneyMinor(_purchasePriceController.text);
    final salePrice = parseMoneyMinor(_salePriceController.text);
    final quantity = parseQuantity(_quantityController.text);
    if (_selectedProductId == null && name.isEmpty) {
      setState(() => _error = 'اكتب اسم المنتج الجديد.');
      return;
    }
    if (purchasePrice == null || salePrice == null) {
      setState(() => _error = 'أدخل أسعارًا صحيحة حتى منزلتين عشريتين.');
      return;
    }
    if (quantity == null || quantity <= 0) {
      setState(() => _error = 'أدخل كمية أكبر من صفر.');
      return;
    }

    if (_selectedProductId == null) {
      final possibleDuplicates = products
          .where((product) => matchesProductSearch(name, product.name))
          .take(3)
          .toList(growable: false);
      if (possibleDuplicates.isNotEmpty) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('تأكد أن المنتج غير موجود'),
            content: Text(
              'وجدت أصنافًا قد تكون مطابقة: '
              '${possibleDuplicates.map((product) => product.name).join('، ')}. '
              'هل تريد إضافة «$name» كمنتج جديد رغم ذلك؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('رجوع واختيار الموجود'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('إضافة كمنتج جديد'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
    }

    final selectedProduct = _selectedProductId == null
        ? null
        : products.where((item) => item.id == _selectedProductId).firstOrNull;
    final effectiveName = selectedProduct?.name ?? name;
    if (!mounted) return;
    Navigator.of(context).pop(
      PurchaseLineDraft(
        productId: _selectedProductId,
        productName: effectiveName,
        purchasePriceMinor: purchasePrice,
        salePriceMinor: salePrice,
        quantity: quantity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'إضافة صنف للمشتريات',
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
          child: FutureBuilder<List<Product>>(
            future: _productsFuture,
            builder: (context, snapshot) {
              final products = snapshot.data ?? const <Product>[];
              final selectedProduct = _selectedProductId == null
                  ? null
                  : products
                        .where((item) => item.id == _selectedProductId)
                        .firstOrNull;
              return ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 24),
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _selectedProductId ?? -1,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'هل المنتج موجود بالفعل؟',
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: -1,
                        child: Text('منتج جديد'),
                      ),
                      for (final product in products)
                        DropdownMenuItem<int>(
                          value: product.id,
                          child: Text(
                            '${product.name} — المتاح ${formatQuantity(product.stockOnHand)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged:
                        snapshot.connectionState == ConnectionState.waiting
                        ? null
                        : (value) {
                            if (value == -1) {
                              _selectProduct(null);
                            } else {
                              final selected = products
                                  .where((product) => product.id == value)
                                  .firstOrNull;
                              _selectProduct(selected);
                            }
                          },
                  ),
                  if (snapshot.hasError) ...[
                    const SizedBox(height: 8),
                    Text(
                      'تعذر تحميل الأصناف الموجودة.',
                      style: TextStyle(color: colors.error),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    readOnly: selectedProduct != null,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: selectedProduct == null
                          ? 'اسم المنتج الجديد'
                          : 'الصنف المختار',
                      helperText: selectedProduct == null
                          ? 'سيتم فحص الأسماء المتشابهة قبل الإنشاء.'
                          : 'اختيار الصنف الموجود يمنع إنشاء نسخة مكررة.',
                      prefixIcon: const Icon(Icons.inventory_2_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _purchasePriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'سعر الشراء للوحدة',
                      suffixText: 'ج.م',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _salePriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'سعر البيع الحالي للوحدة',
                      suffixText: 'ج.م',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'الكمية المشتراة',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: TextStyle(color: colors.error)),
                  ],
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 18),
          child: FilledButton.icon(
            onPressed: () async {
              final products = await _productsFuture;
              if (mounted) await _saveLine(products);
            },
            icon: const Icon(Icons.check_rounded),
            label: const Text('إضافة إلى الفاتورة'),
          ),
        ),
      ],
    );
  }
}

class _PurchaseLineCard extends StatelessWidget {
  const _PurchaseLineCard({
    required this.line,
    required this.onEdit,
    required this.onRemove,
  });

  final PurchaseLineDraft line;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
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
                    line.productName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'تعديل الصنف',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'حذف من الفاتورة',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                Text('سعر البيع: ${formatMoneyMinor(line.salePriceMinor)}'),
                Text(
                  'سعر الشراء: ${formatMoneyMinor(line.purchasePriceMinor)}',
                ),
                Text('الكمية: ${formatQuantity(line.quantity)}'),
                Text(
                  'الإجمالي: ${formatMoneyMinor((line.purchasePriceMinor * line.quantity).round())}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportActionCard extends StatelessWidget {
  const _ImportActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isBusy = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: colors.primary, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isBusy ? 'جارٍ الاستخراج...' : subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchaseSummaryLine extends StatelessWidget {
  const _PurchaseSummaryLine({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong
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
