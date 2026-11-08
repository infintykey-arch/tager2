import 'package:flutter/material.dart';

import '../../products/data/products_repository.dart';
import '../../products/domain/product.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.repository,
    required this.onOpenProducts,
  });

  final ProductsRepository repository;
  final VoidCallback onOpenProducts;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: repository.getProducts(),
      builder: (context, snapshot) {
        final products = snapshot.data ?? const <Product>[];
        final lowStockCount = products
            .where((product) => product.isLowStock)
            .length;

        return ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 28),
          children: [
            Text(
              'إدارة محلك من مكان واحد',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF173A33),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'بيانات نشاطك محفوظة على هذا الجهاز.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: const Color(0xFF62736D)),
            ),
            const SizedBox(height: 20),
            if (snapshot.connectionState == ConnectionState.waiting)
              const LinearProgressIndicator(minHeight: 3)
            else if (snapshot.hasError)
              _LoadError(message: 'تعذر تحميل ملخص المنتجات.')
            else ...[
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.inventory_2_outlined,
                      label: 'المنتجات',
                      value: '${products.length}',
                      tint: const Color(0xFFE6F2EE),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.warning_amber_rounded,
                      label: 'تحتاج متابعة',
                      value: '$lowStockCount',
                      tint: const Color(0xFFFFF1D9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.storefront_rounded,
                        color: Color(0xFF176B5B),
                        size: 30,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        products.isEmpty
                            ? 'ابدأ بإضافة منتجاتك'
                            : 'تابع إدارة المنتجات',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        products.isEmpty
                            ? 'سجّل أسماء المنتجات وأسعارها وكمياتها لتبدأ متابعة المخزون.'
                            : 'يمكنك تعديل بيانات المنتجات أو تسجيل حركة مخزون جديدة.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF62736D),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: onOpenProducts,
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: Text(
                          products.isEmpty ? 'إضافة أول منتج' : 'فتح المنتجات',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _OfflineNote(),
            ],
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: tint,
              child: Icon(icon, size: 19, color: const Color(0xFF176B5B)),
            ),
            const SizedBox(height: 14),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              value,
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2F8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: Color(0xFF46677C)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'يعمل التطبيق دون تسجيل دخول. بياناتك محفوظة محليًا، والنسخ الاحتياطي الخارجي سيُضاف ضمن مرحلة مستقلة.',
              style: TextStyle(height: 1.5, color: Color(0xFF38576B)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(child: Text(message)),
    );
  }
}
