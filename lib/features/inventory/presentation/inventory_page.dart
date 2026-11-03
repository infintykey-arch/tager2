import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../products/data/products_repository.dart';
import '../../products/domain/product.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key, required this.repository});

  final ProductsRepository repository;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: repository.getProducts(lowStockOnly: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const _InventoryMessage(
            icon: Icons.error_outline_rounded,
            title: 'تعذر تحميل المخزون',
            message: 'أغلق الصفحة وافتحها مرة أخرى. إذا استمرت المشكلة، راجع قاعدة البيانات.',
          );
        }

        final products = snapshot.data ?? const <Product>[];
        if (products.isEmpty) {
          return const _InventoryMessage(
            icon: Icons.check_circle_outline_rounded,
            title: 'لا توجد تنبيهات مخزون',
            message:
                'ستظهر هنا المنتجات التي وصلت إلى حد التنبيه أو انخفضت عنه.',
          );
        }

        return ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 24),
          children: [
            Text(
              'مراجعة سريعة للكميات',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'الرصيد محسوب من سجل حركات المخزون.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: const Color(0xFF62736D)),
            ),
            const SizedBox(height: 14),
            ...products.map(
              (product) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFFF1D9),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFF9A6415),
                      ),
                    ),
                    title: Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'حد التنبيه: ${formatQuantity(product.minimumStock)}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('المتاح', style: TextStyle(fontSize: 12)),
                        Text(
                          formatQuantity(product.stockOnHand),
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
          ],
        ),
      ),
    );
  }
}
