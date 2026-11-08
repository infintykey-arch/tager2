import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannedProductCode {
  const ScannedProductCode({required this.value, required this.type});

  final String value;
  final String type;
}

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  late final MobileScannerController _controller;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_completed) return;
    Barcode? scanned;
    for (final barcode in capture.barcodes) {
      if (barcode.rawValue?.trim().isNotEmpty ?? false) {
        scanned = barcode;
        break;
      }
    }
    final value = scanned?.rawValue?.trim();
    if (scanned == null || value == null || value.isEmpty) return;
    final type = switch (scanned.format) {
      BarcodeFormat.qrCode || BarcodeFormat.microQrCode => 'qr',
      _ => 'barcode',
    };
    _finish(ScannedProductCode(value: value, type: type));
  }

  void _finish(ScannedProductCode result) {
    if (_completed || !mounted) return;
    _completed = true;
    unawaited(_controller.stop());
    Navigator.of(context).pop(result);
  }

  Future<void> _enterManually() async {
    final controller = TextEditingController();
    var type = 'barcode';
    final result = await showDialog<ScannedProductCode>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إدخال الكود يدويًا'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'قيمة الكود'),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    Navigator.of(
                      dialogContext,
                    ).pop(ScannedProductCode(value: value.trim(), type: type));
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'نوع الكود'),
                items: const [
                  DropdownMenuItem(value: 'barcode', child: Text('باركود')),
                  DropdownMenuItem(value: 'qr', child: Text('QR')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => type = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) {
                  Navigator.of(dialogContext)
                      .pop(ScannedProductCode(value: value, type: type));
                }
              },
              child: const Text('متابعة'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result != null && mounted) _finish(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('مسح QR أو باركود'),
        actions: [
          IconButton(
            tooltip: 'إدخال الكود يدويًا',
            onPressed: _enterManually,
            icon: const Icon(Icons.keyboard_alt_outlined),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.no_photography_outlined,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'تعذر فتح الكاميرا. تحقق من إذن الكاميرا؛ وعلى الويب '
                      'استخدم HTTPS أو localhost؛ قارئ الباركود مضمن محليًا.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _enterManually,
                      icon: const Icon(Icons.keyboard_alt_outlined),
                      label: const Text('إدخال الكود يدويًا'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 280,
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Text(
                    'وجّه الكاميرا نحو الكود داخل الإطار، أو أدخل قيمته يدويًا.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
