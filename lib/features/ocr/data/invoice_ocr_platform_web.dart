import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

@JS('_extractPdfText')
external JSPromise<JSString> _extractPdfText(JSString pdfBase64, JSAny options);

Future<String> recognizeImage({
  required Uint8List bytes,
  required String mimeType,
  String? localPath,
}) async {
  if (bytes.isEmpty) throw ArgumentError('ملف الصورة فارغ.');
  final imageDataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
  return FlutterTesseractOcr.extractText(
    imageDataUrl,
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
  final options = <String, Object>{
    'language': 'ara+eng',
    'maxPages': maxPages.clamp(1, 10),
    'args': const {'psm': '6', 'preserve_interword_spaces': '1'},
  }.jsify()!;
  final text = await _extractPdfText(base64Encode(bytes).toJS, options).toDart;
  return text.toDart;
}
