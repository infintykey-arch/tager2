import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/features/ocr/data/invoice_ocr_service.dart';

void main() {
  const service = LocalInvoiceOcrService();

  test('rejects an empty PDF before invoking a platform engine', () {
    expect(
      () => service.recognizePdf(bytes: Uint8List(0)),
      throwsArgumentError,
    );
  });

  test('rejects a PDF larger than the local processing limit', () {
    expect(
      () => service.recognizePdf(bytes: Uint8List(20 * 1024 * 1024 + 1)),
      throwsArgumentError,
    );
  });

  test('requires a local file path on Android/native platforms', () async {
    await expectLater(
      service.recognizePdf(bytes: Uint8List.fromList([37, 80, 68, 70])),
      throwsStateError,
    );
  });
}
