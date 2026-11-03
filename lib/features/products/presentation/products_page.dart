import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../data/products_repository.dart';
import '../domain/product.dart';
import 'product_form_sheet.dart';
import 'stock_adjustment_dialog.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({
    super.key,
    required this.repository,
    required this.onDataChanged,
  });

  final ProductsRepository repository;
  final VoidCallback onDataChanged;

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _searchController = TextEditingController();
  late Future<List<Product>> _productsFuture;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadProducts() {
    _productsFuture = widget.repository.getProducts(search: _search);
  }

  void _refresh() {
    if (!mounted) return;
    setState(_loadProducts);
    widget.onDataChanged();
  }

  Future<void> _addProduct() async {
    final product = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => const ProductFormSheet(),
    );
    if (product == null) return;

    try {
      await widget.repository.save(product);
      if (!mounted) return;
      _refresh();
      _showMessage('تمت إضافة المنتج.');
    } catch (error) {
      if (mounted) _showMessage('تعذر حفظ المنتج: ${_friendlyError(error)}');
    }
  }

  Future<void> _editProduct(Product product) async {
    final updated = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => ProductFormSheet(product: product),
    );
    if (updated == null) return;

    try {
      await widget.repository.save(updated);
      if (!mounted) return;
      _refresh();
      _showMessage('تم حفظ التعديلات.');
    } catch (error) {
      if (mounted) _showMessage('تعذر حفظ التعديلات: ${_friendlyError(error)}');
    }
  }

  Future<void> _adjustStock(Product product) async {
    final adjustment = await showDialog<StockAdjustment>(
      context: context,
      builder: (_) => const StockAdjustmentDialog(),
    );
    if (adjustment == null || product.id == null) return;

    try {
      await widget.repository.adjustStock(
        product.id!,
        adjustment.quantityDelta,
        note: adjustment.note,
      );
      if (!mounted) return;
      _refresh();
      _showMessage('تم تسجيل حركة المخزون.');
    } catch (error) {
      if (mounted) _showMessage(_friendlyError(error));
    }
  }

  Future<void> _archiveProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('أرشفة المنتج؟'),
        content: Text(
          'سيختفي «${product.name}» من قائمة المنتجات النشطة، مع الاحتفاظ بسجل حركاته.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('أرشفة'),
          ),
        ],
      ),
    );
    if (confirmed != true || product.id == null) return;

    try {
      await widget.repository.archive(product.id!);
      if (!mounted) return;
      _refresh();
      _showMessage('تمت أرشفة المنتج مع الاحتفاظ بسجله.');
    } catch (error) {
      if (mounted) _showMessage(_friendlyError(error));
    }
  }

  void _showDetails(Product product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (sheetContext) => ProductDetailsSheet(
        product: product,
        repository: widget.repository,
        onEdit: () {
          Navigator.of(sheetContext).pop();
          _editProduct(product);
        },
        onAdjustStock: () {
          Navigator.of(sheetContext).pop();
          _adjustStock(product);
        },
        onArchive: () {
          Navigator.of(sheetContext).pop();
          _archiveProduct(product);
        },
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyError(Object error) {
    if (error is StateError || error is ArgumentError) {
      return error.toString().replaceFirst('Bad state: ', '');
    }
    return 'حدث خطأ غير متوقع. حاول مرة أخرى.';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _search = value;
                    _loadProducts();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'ابحث عن منتج',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'مسح البحث',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _search = '';
                              _loadProducts();
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Product>>(
                future: _productsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _EmptyProducts(
                      icon: Icons.error_outline_rounded,
                      title: 'تعذر تحميل المنتجات',
                      message: 'تحقق من قاعدة البيانات ثم حاول مرة أخرى.',
                      actionLabel: 'إعادة المحاولة',
                      onPressed: () => setState(_loadProducts),
                    );
                  }

                  final products = snapshot.data ?? const <Product>[];
                  if (products.isEmpty) {
                    final isSearching = _search.trim().isNotEmpty;
                    return _EmptyProducts(
                      icon: isSearching
                          ? Icons.search_off_rounded
                          : Icons.inventory_2_outlined,
                      title: isSearching
                          ? 'لا توجد نتائج'
                          : 'لا توجد منتجات بعد',
                      message: isSearching
                          ? 'جرّب كلمة بحث مختلفة.'
                          : 'أضف منتجاتك لتبدأ متابعة الأسعار والكميات.',
                      actionLabel: isSearching ? null : 'إضافة أول منتج',
                      onPressed: isSearching ? null : _addProduct,
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      20,
                      0,
                      20,
                      96,
                    ),
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _ProductCard(
                      product: products[index],
                      onTap: () => _showDetails(products[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        PositionedDirectional(
          end: 20,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: _addProduct,
            icon: const Icon(Icons.add_rounded),
            label: const Text('إضافة منتج'),
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_left_rounded,
                    color: Color(0xFF7A8983),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  _ProductValue(
                    label: 'سعر البيع',
                    value: formatMoneyMinor(product.salePriceMinor),
                  ),
                  _ProductValue(
                    label: 'المتاح',
                    value: formatQuantity(product.stockOnHand),
                  ),
                ],
              ),
              if (product.isLowStock) ...[
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 17,
                      color: Color(0xFF9A6415),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'وصل إلى حد التنبيه أو أقل',
                      style: TextStyle(color: Color(0xFF8A5B12), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductValue extends StatelessWidget {
  const _ProductValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(color: Color(0xFF62736D), fontSize: 13),
        ),
        Text(
          value,
          textDirection: TextDirection.ltr,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ],
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFF176B5B)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.5),
            ),
            if (actionLabel != null && onPressed != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onPressed, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class ProductDetailsSheet extends StatelessWidget {
  const ProductDetailsSheet({
    super.key,
    required this.product,
    required this.repository,
    required this.onEdit,
    required this.onAdjustStock,
    required this.onArchive,
  });

  final Product product;
  final ProductsRepository repository;
  final VoidCallback onEdit;
  final VoidCallback onAdjustStock;
  final VoidCallback onArchive;

  String _movementLabel(StockMovement movement) {
    if (movement.sourceType == 'opening_balance') return 'رصيد افتتاحي';
    if (movement.sourceType == 'manual_adjustment') {
      return movement.quantityDelta > 0 ? 'إضافة للمخزون' : 'خصم من المخزون';
    }
    return movement.sourceType;
  }

  @override
  Widget build(BuildContext context) {
    final productId = product.id;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.name,
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
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _DetailRow(
                      'سعر الشراء المرجعي',
                      formatMoneyMinor(product.purchasePriceMinor),
                    ),
                    _DetailRow(
                      'سعر البيع',
                      formatMoneyMinor(product.salePriceMinor),
                    ),
                    _DetailRow(
                      'الرصيد الحالي',
                      formatQuantity(product.stockOnHand),
                    ),
                    _DetailRow(
                      'حد التنبيه',
                      formatQuantity(product.minimumStock),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('تعديل'),
                ),
                OutlinedButton.icon(
                  onPressed: onAdjustStock,
                  icon: const Icon(Icons.swap_vert_rounded),
                  label: const Text('حركة مخزون'),
                ),
                TextButton.icon(
                  onPressed: onArchive,
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('أرشفة'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'سجل حركات المخزون',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (productId == null)
              const Text('لا يوجد سجل بعد.')
            else
              FutureBuilder<List<StockMovement>>(
                future: repository.getMovements(productId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Text('تعذر تحميل سجل الحركات.');
                  }
                  final movements = snapshot.data ?? const <StockMovement>[];
                  if (movements.isEmpty) {
                    return const Text('لا توجد حركات مسجلة.');
                  }
                  return Column(
                    children: movements.map((movement) {
                      final isAddition = movement.quantityDelta > 0;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          isAddition
                              ? Icons.add_circle_outline
                              : Icons.remove_circle_outline,
                          color: isAddition
                              ? const Color(0xFF176B5B)
                              : const Color(0xFF9A6415),
                        ),
                        title: Text(_movementLabel(movement)),
                        subtitle: Text(
                          [
                            formatDateTime(movement.occurredAt),
                            if (movement.note != null &&
                                movement.note!.isNotEmpty)
                              movement.note!,
                          ].join(' · '),
                        ),
                        trailing: Text(
                          '${isAddition ? '+' : ''}${formatQuantity(movement.quantityDelta)}',
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF62736D)),
            ),
          ),
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
