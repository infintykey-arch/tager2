import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/ads/native_ad_card.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  static final whatsappUri = Uri.parse('https://wa.me/201117175132');

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  bool _opening = false;

  Future<void> _openWhatsApp() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final opened = await launchUrl(
        ContactPage.whatsappUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح WhatsApp على هذا الجهاز.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر فتح WhatsApp. تحقق من وجود التطبيق أو المتصفح.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 112),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.support_agent_rounded,
                      size: 56,
                      color: colors.primary,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'اتصل بنا',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'للتواصل عبر WhatsApp، اضغط على الزر. '
                      'سيتم فتح تطبيق WhatsApp أو صفحة الويب المناسبة.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SelectableText(
                      '+20 111 717 5132',
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _opening ? null : _openWhatsApp,
                      icon: _opening
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chat_rounded),
                      label: const Text('فتح محادثة WhatsApp'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: const NativeAdCard(),
          ),
        ),
      ],
    );
  }
}
