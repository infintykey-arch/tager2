import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../data/products_repository.dart';
import '../domain/product.dart';
import 'product_form_sheet.dart';
import 'stock_adjustment_dialog.dart';
import '../../sales/data/sales_repository.dart';
import '../../sales/domain/sale_cart_line.dart';
import '../../sales/presentation/sales_invoice_sheet.dart';

enum _ProductAction { details, edit, stock, archive, code, removeCode }

class ProductsPage extends StatefulWidget {
  const ProductsPage({
    super.key,
    required this.refreshToken,
    required this.repository,
    required this.salesRepository,
    required this.onDataChanged,
    required this.onAddProduct,
    required this.onOpenMissing,
    required this.onOpenLowStock,
  });

  final int refreshToken;
  final ProductsRepository repository;
  final VoidCallback onDataChanged;
  final VoidCallback onAddProduct;
  final SalesRepository salesRepository;
  final VoidCallback onOpenMissing;
  final VoidCallback onOpenLowStock;

  @override
  ProductsPageState createState() => ProductsPageState();
}

class ProductsPageState extends State<ProductsPage> {
  final _searchController = TextEditingController();
  final _productsScrollController = ScrollController();
  final _products = <Product>[];
  late Future<ProductStockCounts> _stockCountsFuture;
  Timer? _searchDebounce;
  String _search = '';
  ProductListFilter _selectedFilter = ProductListFilter.available;
  final Map<int, SaleCartLine> _saleCart = {};
  static const _pageSize = 60;
  bool _loadingProducts = true;
  bool _loadingMore = false;
  bool _hasMoreProducts = true;
  Object? _productsError;
  int _nextOffset = 0;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _productsScrollController.addListener(_maybeLoadMoreProducts);
    _loadProducts();
    _loadStockCounts();
  }

  @override
  void didUpdateWidget(covariant ProductsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      refreshFromOutside();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _productsScrollController
      ..removeListener(_maybeLoadMoreProducts)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadProducts() {
    _startProductLoad(reset: true);
  }

  void _loadStockCounts() {
    _stockCountsFuture = _readStockCounts();
  }

  Future<ProductResultsPage> _readProductPage(int offset) async {
    final repository = widget.repository;
    if (repository is ProductPagingRepository) {
      return (repository as ProductPagingRepository).getProductsPage(
        search: _search,
        filter: _selectedFilter,
        offset: offset,
        limit: _pageSize,
      );
    }
    final allProducts = await repository.getProducts(
      search: _search,
      filter: _selectedFilter,
    );
    final pageProducts = allProducts.skip(offset).take(_pageSize).toList();
    return ProductResultsPage(
      products: pageProducts,
      hasMore: offset + pageProducts.length < allProducts.length,
    );
  }

  Future<ProductStockCounts> _readStockCounts() async {
    final repository = widget.repository;
    if (repository is ProductPagingRepository) {
      return (repository as ProductPagingRepository).getStockCounts();
    }
    final results = await Future.wait<List<Product>>([
      repository.getProducts(filter: ProductListFilter.missing),
      repository.getProducts(filter: ProductListFilter.lowStock),
    ]);
    return ProductStockCounts(
      available: 0,
      missing: results[0].length,
      lowStock: results[1].length,
    );
  }

  void _startProductLoad({required bool reset}) {
    if (!reset && (_loadingProducts || _loadingMore || !_hasMoreProducts)) {
      return;
    }
    final generation = reset ? ++_loadGeneration : _loadGeneration;
    final offset = reset ? 0 : _nextOffset;
    setState(() {
      if (reset) {
        _products.clear();
        _nextOffset = 0;
        _hasMoreProducts = true;
        _loadingProducts = true;
        _loadingMore = false;
        _productsError = null;
      } else {
        _loadingMore = true;
      }
    });
    unawaited(_fetchProductPage(generation, offset));
  }

  Future<void> _fetchProductPage(int generation, int offset) async {
    try {
      final page = await _readProductPage(offset);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _products.addAll(page.products);
        _nextOffset = offset + page.products.length;
        _hasMoreProducts = page.hasMore;
        _loadingProducts = false;
        _loadingMore = false;
        _productsError = null;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loadingProducts = false;
        _loadingMore = false;
        _productsError = error;
      });
    }
  }

  void _maybeLoadMoreProducts() {
    if (!_productsScrollController.hasClients || !_hasMoreProducts) return;
    final position = _productsScrollController.position;
    if (position.maxScrollExtent - position.pixels < 420) {
      _startProductLoad(reset: false);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    setState(() {
      _search = value;
      _loadGeneration++;
      _hasMoreProducts = false;
      _loadingMore = false;
      _productsError = null;
    });
    if (value.trim().isEmpty) {
      _loadProducts();
    } else {
      _searchDebounce = Timer(const Duration(milliseconds: 250), _loadProducts);
    }
  }

  void _refresh() {
    if (!mounted) return;
    widget.onDataChanged();
  }

  void refreshFromOutside() {
    if (!mounted) return;
    _searchDebounce?.cancel();
    final repository = widget.repository;
    if (repository is ProductPagingRepository) {
      (repository as ProductPagingRepository).invalidateProductPages();
    }
    _loadProducts();
    _loadStockCounts();
  }

  void addScannedProduct(Product product, {required double quantity}) {
    final productId = product.id;
    if (productId == null || !quantity.isFinite || quantity <= 0) return;
    final existing = _saleCart[productId];
    final totalQuantity = (existing?.quantity ?? 0) + quantity;
    if (totalQuantity > product.stockOnHand + 0.0000001) {
      _showMessage(
        'المتاح من «${product.name}» هو ${formatQuantity(product.stockOnHand)} فقط.',
      );
      return;
    }
    setState(() {
      _saleCart[productId] = SaleCartLine(
        product: product,
        quantity: totalQuantity,
      );
    });
    _showMessage('أُضيف «${product.name}» إلى فاتورة البيع.');
  }

  void _selectFilter(ProductListFilter filter) {
    _searchDebounce?.cancel();
    setState(() => _selectedFilter = filter);
    _loadProducts();
  }

  void _addProduct() => widget.onAddProduct();

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
        title: const Text('نقل المنتج إلى الأصناف المحذوفة؟'),
        content: Text(
          'سيختفي «${product.name}» من القوائم النشطة، مع الاحتفاظ ببياناته وسجل حركاته. يمكنك استرجاعه لاحقًا.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('نقل إلى المحذوفة'),
          ),
        ],
      ),
    );
    if (confirmed != true || product.id == null) return;

    try {
      await widget.repository.archive(product.id!);
      if (!mounted) return;
      _refresh();
      _showMessage('نُقل المنتج إلى الأصناف المحذوفة ويمكن استرجاعه.');
    } catch (error) {
      if (mounted) _showMessage(_friendlyError(error));
    }
  }

  Future<void> _removeProductCode(Product product) async {
    if (product.id == null || !product.hasCode) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إزالة الكود من الصنف؟'),
        content: Text(
          'سيُزال QR أو الباركود المرتبط بـ«${product.name}». لا يُحذف الصنف.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('إزالة الكود'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.save(
        Product(
          id: product.id,
          name: product.name,
          purchasePriceMinor: product.purchasePriceMinor,
          salePriceMinor: product.salePriceMinor,
          minimumStock: product.minimumStock,
          stockOnHand: product.stockOnHand,
          createdAt: product.createdAt,
          updatedAt: product.updatedAt,
        ),
      );
      if (!mounted) return;
      _refresh();
      _showMessage('تمت إزالة الكود من الصنف.');
    } catch (error) {
      if (mounted) _showMessage(_friendlyError(error));
    }
  }

  void _handleProductAction(Product product, _ProductAction action) {
    switch (action) {
      case _ProductAction.details:
        _showDetails(product);
      case _ProductAction.edit:
        _editProduct(product);
      case _ProductAction.stock:
        _adjustStock(product);
      case _ProductAction.archive:
        _archiveProduct(product);
      case _ProductAction.code:
        _editProduct(product);
      case _ProductAction.removeCode:
        _removeProductCode(product);
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

  void _handleSaleCartAction() {
    if (_saleCart.isNotEmpty) {
      _openSaleInvoice();
      return;
    }
    _showMessage('اضغط على الأصناف لإضافتها، ثم راجع فاتورة البيع.');
  }

  void _addToSaleCart(Product product) {
    final productId = product.id;
    if (productId == null) return;
    final existing = _saleCart[productId];
    final quantity = existing == null
        ? (product.stockOnHand < 1 ? product.stockOnHand : 1.0)
        : existing.quantity + 1;
    if (quantity > product.stockOnHand + 0.0000001) {
      _showMessage(
        'المتاح من «${product.name}» هو ${formatQuantity(product.stockOnHand)} فقط.',
      );
      return;
    }
    setState(() {
      _saleCart[productId] = SaleCartLine(product: product, quantity: quantity);
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  void _updateSaleCart(List<SaleCartLine> lines) {
    if (!mounted) return;
    final updated = <int, SaleCartLine>{};
    for (final line in lines) {
      final productId = line.product.id;
      if (productId != null) updated[productId] = line;
    }
    setState(() {
      _saleCart
        ..clear()
        ..addAll(updated);
    });
  }

  Future<void> _openSaleInvoice() async {
    if (_saleCart.isEmpty) return;
    final receipt = await showModalBottomSheet<SaleReceipt>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.95,
        child: SalesInvoiceSheet(
          initialLines: _saleCart.values.toList(growable: false),
          salesRepository: widget.salesRepository,
          onCartChanged: _updateSaleCart,
        ),
      ),
    );
    if (receipt == null || !mounted) return;
    setState(() {
      _saleCart.clear();
    });
    _refresh();
    _showMessage(
      'تم حفظ ${receipt.invoiceNumber} بإجمالي ${formatMoneyMinor(receipt.totalMinor)}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
              child: FutureBuilder<ProductStockCounts>(
                future: _stockCountsFuture,
                builder: (context, snapshot) {
                  const emptyCounts = ProductStockCounts(
                    available: 0,
                    lowStock: 0,
                    missing: 0,
                  );
                  final counts = snapshot.data ?? emptyCounts;
                  return Row(
                    children: [
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.remove_shopping_cart_outlined,
                          label: 'الأصناف الناقصة',
                          count: counts.missing,
                          onTap: widget.onOpenMissing,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.warning_amber_rounded,
                          label: 'على وشك النفاد',
                          count: counts.lowStock,
                          onTap: widget.onOpenLowStock,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.add_box_outlined,
                          label: 'إضافة منتج جديد',
                          onTap: _addProduct,
                          isEmphasized: true,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن منتج',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _search.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'مسح البحث',
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: _saleCart.isNotEmpty
                        ? 'مراجعة الفاتورة (${_saleCart.length})'
                        : 'بدء فاتورة بيع',
                    onPressed: _handleSaleCartAction,
                    icon: Badge(
                      isLabelVisible: _saleCart.isNotEmpty,
                      label: Text('${_saleCart.length}'),
                      child: const Icon(Icons.shopping_cart_outlined),
                    ),
                  ),
                ],
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 500) {
                  return Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      20,
                      0,
                      20,
                      10,
                    ),
                    child: DropdownButtonFormField<ProductListFilter>(
                      initialValue: _selectedFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'تصفية الأصناف',
                        prefixIcon: Icon(Icons.filter_list_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ProductListFilter.available,
                          child: Text('كل الأصناف'),
                        ),
                        DropdownMenuItem(
                          value: ProductListFilter.withCode,
                          child: Text('الأصناف المرتبطة بـ QR أو باركود'),
                        ),
                        DropdownMenuItem(
                          value: ProductListFilter.withoutCode,
                          child: Text('الأصناف بدون QR أو باركود'),
                        ),
                      ],
                      onChanged: (filter) {
                        if (filter != null) _selectFilter(filter);
                      },
                    ),
                  );
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 10),
                  child: Row(
                    children: [
                      _ProductFilterTab(
                        label: 'كل الأصناف',
                        selected:
                            _selectedFilter == ProductListFilter.available,
                        onTap: () => _selectFilter(ProductListFilter.available),
                      ),
                      const SizedBox(width: 8),
                      _ProductFilterTab(
                        label: 'الأصناف ذات الباركود أو QR',
                        selected: _selectedFilter == ProductListFilter.withCode,
                        onTap: () => _selectFilter(ProductListFilter.withCode),
                      ),
                      const SizedBox(width: 8),
                      _ProductFilterTab(
                        label: 'الأصناف بدون باركود أو QR',
                        selected:
                            _selectedFilter == ProductListFilter.withoutCode,
                        onTap: () =>
                            _selectFilter(ProductListFilter.withoutCode),
                      ),
                    ],
                  ),
                );
              },
            ),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (_loadingProducts && _products.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (_productsError != null && _products.isEmpty) {
                    return _EmptyProducts(
                      icon: Icons.error_outline_rounded,
                      title: 'تعذر تحميل المنتجات',
                      message: 'تحقق من قاعدة البيانات ثم حاول مرة أخرى.',
                      actionLabel: 'إعادة المحاولة',
                      onPressed: _loadProducts,
                    );
                  }

                  if (_products.isEmpty) {
                    final isSearching = _search.trim().isNotEmpty;
                    final emptyTitle = switch (_selectedFilter) {
                      ProductListFilter.available => 'لا توجد منتجات بعد',
                      ProductListFilter.withCode => 'لا توجد أصناف مرتبطة بكود',
                      ProductListFilter.withoutCode => 'كل الأصناف مرتبطة بكود',
                      _ => 'لا توجد نتائج',
                    };
                    return _EmptyProducts(
                      icon: isSearching
                          ? Icons.search_off_rounded
                          : Icons.inventory_2_outlined,
                      title: isSearching ? 'لا توجد نتائج' : emptyTitle,
                      message: isSearching
                          ? 'جرّب كلمة بحث مختلفة.'
                          : 'أضف منتجاتك لتبدأ متابعة الأسعار والكميات.',
                      actionLabel: isSearching ? null : 'إضافة منتج جديد',
                      onPressed: isSearching ? null : _addProduct,
                    );
                  }

                  final width = MediaQuery.sizeOf(context).width;
                  final columns = width >= 1024
                      ? 4
                      : width >= 600
                      ? 3
                      : 2;
                  final rowCount = (_products.length + columns - 1) ~/ columns;
                  final showFooter = _hasMoreProducts || _loadingMore;
                  return ListView.builder(
                    controller: _productsScrollController,
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      20,
                      0,
                      20,
                      96,
                    ),
                    itemCount: rowCount + (showFooter ? 1 : 0),
                    itemBuilder: (context, rowIndex) {
                      if (rowIndex >= rowCount) {
                        if (_loadingMore) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (_productsError != null) {
                          return TextButton.icon(
                            onPressed: () => _startProductLoad(reset: false),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text(
                              'تعذر تحميل المزيد؛ أعد المحاولة',
                            ),
                          );
                        }
                        return TextButton.icon(
                          onPressed: () => _startProductLoad(reset: false),
                          icon: const Icon(Icons.expand_more_rounded),
                          label: Text(
                            _search.trim().isEmpty
                                ? 'تحميل المزيد'
                                : 'متابعة البحث عن نتائج أخرى',
                          ),
                        );
                      }

                      final rowStart = rowIndex * columns;
                      final rowEnd = (rowStart + columns).clamp(
                        0,
                        _products.length,
                      );
                      final rowProducts = _products.sublist(rowStart, rowEnd);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (
                                var column = 0;
                                column < columns;
                                column++
                              ) ...[
                                if (column > 0) const SizedBox(width: 12),
                                Expanded(
                                  child: column < rowProducts.length
                                      ? TweenAnimationBuilder<double>(
                                          key: ValueKey(
                                            'product-card-${rowProducts[column].id}',
                                          ),
                                          tween: Tween(begin: 0, end: 1),
                                          duration: const Duration(
                                            milliseconds: 140,
                                          ),
                                          curve: Curves.easeOutCubic,
                                          builder: (context, progress, child) =>
                                              Opacity(
                                                opacity: progress,
                                                child: Transform.translate(
                                                  offset: Offset(
                                                    0,
                                                    6 * (1 - progress),
                                                  ),
                                                  child: child,
                                                ),
                                              ),
                                          child: _ProductCard(
                                            product: rowProducts[column],
                                            selectionMode: true,
                                            saleQuantity:
                                                _saleCart[rowProducts[column]
                                                        .id]
                                                    ?.quantity ??
                                                0,
                                            onTap: () => _addToSaleCart(
                                              rowProducts[column],
                                            ),
                                            onAction: (action) =>
                                                _handleProductAction(
                                                  rowProducts[column],
                                                  action,
                                                ),
                                            hasCode:
                                                rowProducts[column].hasCode,
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        if (_saleCart.isNotEmpty)
          PositionedDirectional(
            start: 72,
            end: 16,
            bottom: 16,
            child: SafeArea(
              child: FilledButton.icon(
                onPressed: _openSaleInvoice,
                icon: const Icon(Icons.shopping_cart_checkout_rounded),
                label: Text('مراجعة الفاتورة (${_saleCart.length})'),
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.count,
    this.isEmphasized = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? count;
  final bool isEmphasized;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: isEmphasized ? const Color(0xFFFFF4D8) : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 23,
                color: isEmphasized ? const Color(0xFF8A6412) : colors.primary,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
              ),
              if (count != null) ...[
                const SizedBox(height: 2),
                Text(
                  '$count',
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductFilterTab extends StatelessWidget {
  const _ProductFilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? colors.secondaryContainer : colors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected
                    ? colors.onSecondaryContainer
                    : colors.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onAction,
    required this.selectionMode,
    required this.saleQuantity,
    required this.hasCode,
  });

  final Product product;
  final VoidCallback onTap;
  final ValueChanged<_ProductAction> onAction;
  final bool selectionMode;
  final double saleQuantity;
  final bool hasCode;

  static const List<Color> _cardColors = [
    Color(0xFFF1E3C4),
    Color(0xFFDCEAF3),
    Color(0xFFE4E3EA),
    Color(0xFFE2E9CE),
    Color(0xFFEAD4CA),
    Color(0xFFFFE8B8),
    Color(0xFFD6E5EF),
    Color(0xFFD8EADB),
    Color(0xFFF2E2B4),
    Color(0xFFE5D5C8),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final colorIndex =
        (product.id ?? product.name.hashCode).abs() % _cardColors.length;
    return Card(
      color: _cardColors[colorIndex],
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0x22173A33)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectionMode && saleQuantity > 0)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          child: Text(
                            formatQuantity(saleQuantity),
                            textDirection: TextDirection.ltr,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: colors.onPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      product.name,
                      softWrap: true,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF173A33),
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                  PopupMenuButton<_ProductAction>(
                    tooltip: 'إجراءات ${product.name}',
                    onSelected: onAction,
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: _ProductAction.details,
                        child: Text('عرض التفاصيل'),
                      ),
                      const PopupMenuItem(
                        value: _ProductAction.edit,
                        child: Text('تعديل المنتج'),
                      ),
                      const PopupMenuItem(
                        value: _ProductAction.stock,
                        child: Text('حركة المخزون'),
                      ),
                      PopupMenuItem(
                        value: _ProductAction.code,
                        child: Text(
                          hasCode
                              ? 'تعديل QR أو الباركود'
                              : 'إضافة QR أو باركود',
                        ),
                      ),
                      if (hasCode)
                        const PopupMenuItem(
                          value: _ProductAction.removeCode,
                          child: Text('إزالة الكود'),
                        ),
                      const PopupMenuItem(
                        value: _ProductAction.archive,
                        child: Text('نقل إلى الأصناف المحذوفة'),
                      ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.more_vert_rounded,
                        color: const Color(0xFF173A33),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ProductValue(
                      label: 'المتاح',
                      value: formatQuantity(product.stockOnHand),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ProductValue(
                      label: 'سعر البيع',
                      value: formatMoneyMinor(product.salePriceMinor),
                    ),
                  ),
                ],
              ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF62736D), fontSize: 12),
        ),
        Text(
          value,
          textDirection: TextDirection.ltr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
    if (movement.sourceType == 'cost_transition') {
      return 'تحديد تكلفة انتقالية';
    }
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
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('حذف'),
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
                      final isCostTransition =
                          movement.sourceType == 'cost_transition';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          isCostTransition
                              ? Icons.price_check_outlined
                              : isAddition
                              ? Icons.add_circle_outline
                              : Icons.remove_circle_outline,
                          color: isCostTransition
                              ? Theme.of(context).colorScheme.primary
                              : isAddition
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
                          isCostTransition
                              ? '—'
                              : '${isAddition ? '+' : ''}${formatQuantity(movement.quantityDelta)}',
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
