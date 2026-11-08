import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../products/data/products_repository.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/stock_adjustment_dialog.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({
    super.key,
    required this.repository,
    this.filter = ProductListFilter.lowStock,
  });

  final ProductsRepository repository;
  final ProductListFilter filter;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  static const _pageSize = 60;
  final _scrollController = ScrollController();
  final _products = <Product>[];
  int _nextOffset = 0;
  int _loadGeneration = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  Object? _loadError;

  bool get _showsMissing => widget.filter == ProductListFilter.missing;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
    _loadProducts();
  }

  @override
  void didUpdateWidget(covariant InventoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter ||
        oldWidget.repository != widget.repository) {
      _loadProducts();
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_maybeLoadMore)
      ..dispose();
    super.dispose();
  }

  void _loadProducts() {
    final generation = ++_loadGeneration;
    setState(() {
      _products.clear();
      _nextOffset = 0;
      _loading = true;
      _loadingMore = false;
      _hasMore = true;
      _loadError = null;
    });
    unawaited(_loadPage(generation, 0));
  }

  Future<ProductResultsPage> _readPage(int offset) async {
    final repository = widget.repository;
    if (repository is ProductPagingRepository) {
      return (repository as ProductPagingRepository).getProductsPage(
        filter: widget.filter,
        offset: offset,
        limit: _pageSize,
      );
    }
    final allProducts = await repository.getProducts(filter: widget.filter);
    final page = allProducts.skip(offset).take(_pageSize).toList();
    return ProductResultsPage(
      products: page,
      hasMore: offset + page.length < allProducts.length,
    );
  }

  Future<void> _loadPage(int generation, int offset) async {
    try {
      final page = await _readPage(offset);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _products.addAll(page.products);
        _nextOffset = offset + page.products.length;
        _hasMore = page.hasMore;
        _loading = false;
        _loadingMore = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _loadError = error;
      });
    }
  }

  void _loadMore() {
    if (_loading || _loadingMore || !_hasMore) return;
    final generation = _loadGeneration;
    final offset = _nextOffset;
    setState(() => _loadingMore = true);
    unawaited(_loadPage(generation, offset));
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients || !_hasMore) return;
    if (_scrollController.position.maxScrollExtent -
            _scrollController.position.pixels <
        420) {
      _loadMore();
    }
  }

  Future<void> _adjustStock(Product product) async {
    final productId = product.id;
    if (productId == null) return;

    final adjustment = await showDialog<StockAdjustment>(
      context: context,
      builder: (_) => const StockAdjustmentDialog(),
    );
    if (adjustment == null) return;

    try {
      await widget.repository.adjustStock(
        productId,
        adjustment.quantityDelta,
        note: adjustment.note,
      );
      if (!mounted) return;
      _loadProducts();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('تم تسجيل حركة المخزون.')));
    } catch (error) {
      if (!mounted) return;
      final message = error is StateError || error is ArgumentError
          ? error.toString().replaceFirst('Bad state: ', '')
          : 'تعذر تسجيل الحركة. حاول مرة أخرى.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _showsMissing ? 'الأصناف الناقصة' : 'على وشك النفاد';
    if (_loading && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null && _products.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _InventoryMessage(
            icon: Icons.error_outline_rounded,
            title: 'تعذر تحميل المخزون',
            message: 'تحقق من قاعدة البيانات ثم حاول مرة أخرى.',
          ),
          TextButton.icon(
            onPressed: _loadProducts,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      );
    }
    if (_products.isEmpty) {
      return _InventoryMessage(
        icon: _showsMissing
            ? Icons.check_circle_outline_rounded
            : Icons.inventory_2_outlined,
        title: _showsMissing
            ? 'لا توجد أصناف ناقصة'
            : 'لا توجد أصناف على وشك النفاد',
        message: _showsMissing
            ? 'سيظهر هنا كل صنف نفد رصيده بالكامل.'
            : 'سيظهر هنا الصنف الذي يتوفر منه من 1 إلى 10 وحدات.',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _showsMissing
                    ? 'الرصيد صفر. أضف كمية عند استلام مشتريات.'
                    : 'الرصيد الحالي من 1 إلى 10 وحدات.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 24),
            itemCount: _products.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _products.length) {
                if (_loadingMore) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (_loadError != null) {
                  return TextButton.icon(
                    onPressed: _loadMore,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('تعذر تحميل المزيد؛ أعد المحاولة'),
                  );
                }
                return TextButton.icon(
                  onPressed: _loadMore,
                  icon: const Icon(Icons.expand_more_rounded),
                  label: const Text('تحميل المزيد'),
                );
              }

              final product = _products[index];
              return TweenAnimationBuilder<double>(
                key: ValueKey('inventory-product-${product.id}'),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                builder: (context, progress, child) => Opacity(
                  opacity: progress,
                  child: Transform.translate(
                    offset: Offset(0, 6 * (1 - progress)),
                    child: child,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsetsDirectional.fromSTEB(
                            16,
                            8,
                            16,
                            4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: _showsMissing
                                ? Theme.of(context).colorScheme.errorContainer
                                : const Color(0xFFFFF1D9),
                            child: Icon(
                              _showsMissing
                                  ? Icons.remove_shopping_cart_outlined
                                  : Icons.warning_amber_rounded,
                              color: _showsMissing
                                  ? Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer
                                  : const Color(0xFF9A6415),
                            ),
                          ),
                          title: Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            'سعر البيع: ${formatMoneyMinor(product.salePriceMinor)}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'المتاح',
                                style: TextStyle(fontSize: 12),
                              ),
                              Text(
                                formatQuantity(product.stockOnHand),
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              8,
                              0,
                              12,
                              10,
                            ),
                            child: OutlinedButton.icon(
                              onPressed: () => _adjustStock(product),
                              icon: const Icon(Icons.swap_vert_rounded),
                              label: const Text('تسجيل حركة مخزون'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InventoryMessage extends StatelessWidget {
  const _InventoryMessage({
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
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
