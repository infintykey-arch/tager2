import 'dart:typed_data';

import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

Future<String> recognizeImage({
  required Uint8List bytes,
  required String mimeType,
  String? localPath,
}) async {
  if (bytes.isEmpty) throw ArgumentError('ملف الصورة فارغ.');
  if (localPath == null || localPath.isEmpty) {
    throw StateError('تعذر الوصول إلى الصورة المحلية. أعد اختيار الملف.');
  }

  return FlutterTesseractOcr.extractText(
    localPath,
    language: 'ara+eng',
    args: const {'psm': '6', 'preserve_interword_spaces': '1'},
  );
}

Future<String> recognizePdf({
  required Uint8List bytes,
  String? localPath,
  int maxPages = 5,
}) async {
  if (bytes.isEmpty) throw ArgumentError('ملف PDF فارغ.');
  if (localPath == null || localPath.isEmpty) {
    throw StateError('تعذر الوصول إلى ملف PDF المحلي. أعد اختيار الملف.');
  }
  return FlutterTesseractOcr.extractPdfText(
    localPath,
    language: 'ara+eng',
    args: const {'psm': '6', 'preserve_interword_spaces': '1'},
    maxPages: maxPages,
  );
}
