import 'package:flutter/material.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  static const _plannedFeatures = [
    (Icons.people_alt_outlined, 'العملاء والتحصيلات'),
    (Icons.receipt_long_outlined, 'المبيعات والفواتير'),
    (Icons.local_shipping_outlined, 'المشتريات والموردون'),
    (Icons.payments_outlined, 'المصروفات والمرتجعات'),
    (Icons.bar_chart_rounded, 'التقارير والتحليلات'),
    (Icons.backup_outlined, 'النسخ الاحتياطي والاستعادة'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 24),
      children: [
        Text(
          'الأقسام التالية ضمن مراحل البناء',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'نبدأ بالمنتجات والمخزون، ثم نضيف كل قسم بعد اعتماد قواعده واختباره.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: const Color(0xFF62736D), height: 1.5),
        ),
        const SizedBox(height: 18),
        ..._plannedFeatures.map(
          (feature) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFE6F2EE),
                  child: Icon(feature.$1, color: const Color(0xFF176B5B)),
                ),
                title: Text(
                  feature.$2,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Text(
                  'لاحقًا',
                  style: TextStyle(color: Color(0xFF62736D), fontSize: 12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
