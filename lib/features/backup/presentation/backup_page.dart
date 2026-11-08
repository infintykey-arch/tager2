import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../data/database_backup_repository.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({
    super.key,
    required this.repository,
    required this.onDataRestored,
  });

  final DatabaseBackupRepository repository;
  final VoidCallback onDataRestored;

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _busy = false;

  Future<void> _createBackup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await widget.repository.createBackupBytes();
      final now = DateTime.now();
      final timestamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}-'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}';
      final uri = await FilePicker.saveFile(
        fileName: 'tager2-backup-$timestamp.json',
        bytes: bytes,
        mimeType: 'application/json',
        dialogTitle: 'حفظ نسخة احتياطية من تاجر ٢',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uri == null
                ? 'لم يتم حفظ النسخة الاحتياطية.'
                : 'تم حفظ النسخة. احتفظ بالملف في مكان آمن.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'اختيار نسخة تاجر ٢',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (!mounted || file == null) return;

      final length = file.lengthSync() ?? await file.length();
      if (length == null ||
          length <= 0 ||
          length > DatabaseBackupRepository.maximumBackupBytes) {
        throw const FormatException('حجم ملف النسخة غير صالح.');
      }
      final bytes = await file.readAsBytes();
      final summary = widget.repository.inspectBackup(bytes);
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('استعادة نسخة احتياطية؟'),
          content: Text(
            'الملف: ${file.name}\n'
            'تاريخ النسخة: ${formatDateTime(summary.createdAt)}\n'
            'عدد السجلات: ${summary.totalRows}\n\n'
            'سيتم استبدال بيانات تاجر ٢ الموجودة على هذا الجهاز بالكامل '
            'بمحتوى هذه النسخة. أنشئ نسخة من بياناتك الحالية أولًا إذا '
            'كنت تريد الاحتفاظ بها. هل تريد المتابعة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('استبدال البيانات واستعادة النسخة'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      await widget.repository.restoreBackup(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت استعادة النسخة الاحتياطية.')),
      );
      widget.onDataRestored();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object error) {
    if (error is FormatException) return error.message.toString();
    if (error is StateError) return error.message;
    return 'تعذر إكمال العملية. لم تتغير بياناتك.';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 18, 16, 100),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, size: 34, color: colors.primary),
                  const SizedBox(height: 12),
                  Text(
                    'بياناتك محفوظة على هذا الجهاز',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'أنشئ ملف JSON لاسترجاع الأصناف والفواتير والدفعات '
                    'والمصروفات لاحقًا أو لنقلها يدويًا إلى جهاز آخر. '
                    'النسخة لا تُرسل إلى الإنترنت، والملف غير مشفّر؛ '
                    'احتفظ به في مكان موثوق.',
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إنشاء نسخة احتياطية',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text('حفظ نسخة كاملة من البيانات الموجودة حاليًا.'),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _createBackup,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('حفظ نسخة على الجهاز'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'استعادة نسخة سابقة',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'اختر ملف JSON صادرًا من تاجر ٢. سيظهر ملخص قبل '
                    'الاستعادة، ولن تُستبدل البيانات قبل تأكيدك.',
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _restoreBackup,
                      icon: const Icon(Icons.restore_rounded),
                      label: const Text('اختيار ملف واستعادة'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_busy) ...[
          const SizedBox(height: 18),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }
}
