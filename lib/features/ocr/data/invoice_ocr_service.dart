import 'dart:typed_data';

import 'invoice_ocr_platform_stub.dart'
    if (dart.library.io) 'invoice_ocr_platform_io.dart'
    if (dart.library.js_interop) 'invoice_ocr_platform_web.dart'
    as platform;

class LocalInvoiceOcrService {
  const LocalInvoiceOcrService();

  Future<String> recognizeImage({
    required Uint8List bytes,
    required String mimeType,
    String? localPath,
  }) => platform.recognizeImage(
    bytes: bytes,
    mimeType: mimeType,
    localPath: localPath,
  );

  Future<String> recognizePdf({
    required Uint8List bytes,
    String? localPath,
    int maxPages = 5,
  }) {
    if (bytes.isEmpty) throw ArgumentError('ملف PDF فارغ.');
    if (bytes.lengthInBytes > 20 * 1024 * 1024) {
      throw ArgumentError('حجم ملف PDF أكبر من الحد المحلي وهو 20 ميجابايت.');
    }
    return platform.recognizePdf(
      bytes: bytes,
      localPath: localPath,
      maxPages: maxPages,
    );
  }
}
