import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../products/data/products_repository.dart';
import '../../products/domain/product.dart';

class ProductCodeBindingSheet extends StatefulWidget {
  const ProductCodeBindingSheet({
    super.key,
    required this.repository,
    required this.code,
    required this.codeType,
  });

  final ProductsRepository repository;
  final String code;
  final String codeType;

  @override
  State<ProductCodeBindingSheet> createState() =>
      _ProductCodeBindingSheetState();
}

class _ProductCodeBindingSheetState extends State<ProductCodeBindingSheet> {
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
    _productsFuture = widget.repository.findUncodedActiveProducts(
      search: _search,
    );
  }

  Future<void> _assign(Product product) async {
    final productId = product.id;
    if (productId == null) return;
    try {
      await widget.repository.assignCode(
        productId,
        widget.code,
        codeType: widget.codeType,
      );
      if (mounted) Navigator.of(context).pop(product);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_friendlyError(error))));
      setState(_loadProducts);
    }
  }

  String _friendlyError(Object error) {
    if (error is StateError || error is ArgumentError) {
      return error.toString().replaceFirst('Bad state: ', '');
    }
    return 'تعذر ربط الكود بالصنف. حاول مرة أخرى.';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'هذا الـ QR أو الباركود غير معرّف',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'يُرجى اختيار الصنف الذي تريد إضافة هذا الكود له.',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.codeType == 'qr' ? 'QR' : 'الباركود'}: ${widget.code}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _search = value;
                    _loadProducts();
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'ابحث عن الصنف الذي تريد ربطه',
                  prefixIcon: Icon(Icons.search_rounded),
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
                    return const Center(child: Text('تعذر تحميل الأصناف.'));
                  }
                  final products = snapshot.data ?? const <Product>[];
                  if (products.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _search.isEmpty
                              ? 'لا توجد أصناف فعالة بلا كود. أضف الصنف أولًا أو أدخل الكود من شاشة تحرير الصنف.'
                              : 'لا توجد أصناف بلا كود تطابق البحث.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      16,
                      0,
                      16,
                      24,
                    ),
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.inventory_2_outlined),
                          ),
                          title: Text(product.name),
                          subtitle: Text(
                            'سعر البيع: ${formatMoneyMinor(product.salePriceMinor)}'
                            ' · المخزون: ${formatQuantity(product.stockOnHand)}',
                          ),
                          trailing: const Icon(Icons.link_rounded),
                          onTap: () => _assign(product),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
