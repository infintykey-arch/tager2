import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../data/products_repository.dart';
import '../domain/product.dart';

class DeletedProductsPage extends StatefulWidget {
  const DeletedProductsPage({super.key, required this.repository});

  final ProductsRepository repository;

  @override
  State<DeletedProductsPage> createState() => _DeletedProductsPageState();
}

class _DeletedProductsPageState extends State<DeletedProductsPage> {
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
    _productsFuture = widget.repository.getProducts(
      search: _search,
      filter: ProductListFilter.deleted,
    );
  }

  Future<void> _restore(Product product) async {
    final productId = product.id;
    if (productId == null) return;
    try {
      await widget.repository.restore(productId);
      if (!mounted) return;
      setState(_loadProducts);
      _showMessage('تم استرجاع المنتج إلى قائمة الأصناف.');
    } catch (error) {
      if (mounted) _showMessage(_friendlyError(error));
    }
  }

  Future<void> _deletePermanently(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف نهائي؟'),
        content: Text(
          'سيُحذف «${product.name}» وسجل حركات مخزونه نهائيًا. لا يمكن التراجع عن هذه الخطوة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (confirmed != true || product.id == null) return;

    try {
      await widget.repository.deletePermanently(product.id!);
      if (!mounted) return;
      setState(_loadProducts);
      _showMessage('تم الحذف النهائي.');
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
      builder: (sheetContext) => _DeletedProductDetails(
        product: product,
        repository: widget.repository,
        onRestore: () {
          Navigator.of(sheetContext).pop();
          _restore(product);
        },
        onDeletePermanently: () {
          Navigator.of(sheetContext).pop();
          _deletePermanently(product);
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 12),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() {
              _search = value;
              _loadProducts();
            }),
            decoration: InputDecoration(
              hintText: 'ابحث في الأصناف المحذوفة',
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
                return const _DeletedProductsMessage(
                  icon: Icons.error_outline_rounded,
                  title: 'تعذر تحميل الأصناف المحذوفة',
                  message: 'أعد فتح القسم أو حاول مرة أخرى.',
                );
              }

              final products = snapshot.data ?? const <Product>[];
              if (products.isEmpty) {
                return _DeletedProductsMessage(
                  icon: Icons.delete_outline_rounded,
                  title: _search.isEmpty
                      ? 'لا توجد أصناف محذوفة'
                      : 'لا توجد نتائج',
                  message: _search.isEmpty
                      ? 'الأصناف التي تنقلها من الصفحة الرئيسية ستظهر هنا ويمكنك استرجاعها.'
                      : 'جرّب كلمة بحث مختلفة.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 24),
                itemCount: products.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return Card(
                    child: ListTile(
                      onTap: () => _showDetails(product),
                      leading: const CircleAvatar(
                        child: Icon(Icons.inventory_2_outlined),
                      ),
                      title: Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'الرصيد وقت النقل: ${formatQuantity(product.stockOnHand)} · '
                        'سعر البيع: ${formatMoneyMinor(product.salePriceMinor)}',
                      ),
                      trailing: const Icon(Icons.chevron_left_rounded),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DeletedProductDetails extends StatelessWidget {
  const _DeletedProductDetails({
    required this.product,
    required this.repository,
    required this.onRestore,
    required this.onDeletePermanently,
  });

  final Product product;
  final ProductsRepository repository;
  final VoidCallback onRestore;
  final VoidCallback onDeletePermanently;

  String _date(DateTime? value) =>
      value == null ? 'غير متاح' : formatDateTime(value);

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
            Text(
              product.name,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _InfoLine(
              'سعر الشراء',
              formatMoneyMinor(product.purchasePriceMinor),
            ),
            _InfoLine('سعر البيع', formatMoneyMinor(product.salePriceMinor)),
            _InfoLine('الرصيد الحالي', formatQuantity(product.stockOnHand)),
            if (product.hasCode)
              _InfoLine('الكود', '${product.codeType}: ${product.codeValue}'),
            _InfoLine('تاريخ الإضافة', _date(product.createdAt)),
            _InfoLine('تاريخ النقل للمحذوفة', _date(product.updatedAt)),
            const SizedBox(height: 12),
            Text(
              'سجل حركات المخزون',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            if (productId == null)
              const Text('لا يوجد سجل محفوظ.')
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
                    children: movements
                        .map(
                          (movement) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              movement.sourceType == 'cost_transition'
                                  ? 'تحديد تكلفة انتقالية'
                                  : movement.sourceType,
                            ),
                            subtitle: Text(
                              '${formatDateTime(movement.occurredAt)}'
                              '${movement.note == null ? '' : ' · ${movement.note}'}',
                            ),
                            trailing: Text(
                              movement.sourceType == 'cost_transition'
                                  ? '—'
                                  : formatQuantity(movement.quantityDelta),
                              textDirection: TextDirection.ltr,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRestore,
              icon: const Icon(Icons.restore_rounded),
              label: const Text('استرجاع الصنف'),
            ),
            TextButton.icon(
              onPressed: onDeletePermanently,
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('حذف نهائي'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeletedProductsMessage extends StatelessWidget {
  const _DeletedProductsMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
