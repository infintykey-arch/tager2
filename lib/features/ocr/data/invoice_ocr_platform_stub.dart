import 'dart:typed_data';

Future<String> recognizeImage({
  required Uint8List bytes,
  required String mimeType,
  String? localPath,
}) => Future.error(UnsupportedError('OCR المحلي متاح على Android والويب فقط.'));

Future<String> recognizePdf({
  required Uint8List bytes,
  String? localPath,
  int maxPages = 5,
}) => Future.error(
  UnsupportedError('OCR ملفات PDF متاح على Android والويب فقط.'),
);
