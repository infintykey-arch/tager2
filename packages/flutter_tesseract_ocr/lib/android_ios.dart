// part of flutter_tesseract_ocr;
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

class FlutterTesseractOcr {
  static const String tessDataConfigAsset = 'assets/tessdata_config.json';
  static const String tessDataPath = 'assets/tessdata';
  static const MethodChannel _channel = MethodChannel('flutter_tesseract_ocr');

  /// image to  text
  ///```
  /// String _ocrText = await FlutterTesseractOcr.extractText(url, language: langs, args: {
  ///    "preserve_interword_spaces": "1",});
  ///```
  static Future<String> extractText(String imagePath,
      {String? language, Map? args}) async {
    assert(await File(imagePath).exists(), true);
    final String tessData = await _loadTessData();
    final String extractText =
        await _channel.invokeMethod('extractText', <String, dynamic>{
      'imagePath': imagePath,
      'tessData': tessData,
      'language': language,
      'args': args,
    });
    return extractText;
  }

  static Future<String> extractPdfText(
    String pdfPath, {
    String? language,
    Map? args,
    int maxPages = 5,
  }) async {
    assert(await File(pdfPath).exists(), true);
    final String tessData = await _loadTessData();
    final String? text = await _channel.invokeMethod<String>(
      'extractPdfText',
      <String, dynamic>{
        'pdfPath': pdfPath,
        'tessData': tessData,
        'language': language ?? 'ara+eng',
        'args': args,
        'maxPages': maxPages,
      },
    );
    return text ?? '';
  }

  /// image to  html text(hocr)
  ///```
  /// String _ocrHocr = await FlutterTesseractOcr.extractText(url, language: langs, args: {
  ///    "preserve_interword_spaces": "1",});
  ///```
  static Future<String> extractHocr(String imagePath,
      {String? language, Map? args}) async {
    assert(await File(imagePath).exists(), true);
    final String tessData = await _loadTessData();
    final String extractText =
        await _channel.invokeMethod('extractHocr', <String, dynamic>{
      'imagePath': imagePath,
      'tessData': tessData,
      'language': language,
      'args': args,
    });
    return extractText;
  }

  /// getTessdataPath
  ///```
  /// print(await FlutterTesseractOcr.getTessdataPath())
  ///```
  static Future<String> getTessdataPath() async {
    final Directory appDirectory = await getApplicationDocumentsDirectory();
    final String tessdataDirectory = join(appDirectory.path, 'tessdata');
    return tessdataDirectory;
  }

  static Future<String> _loadTessData() async {
    final Directory appDirectory = await getApplicationDocumentsDirectory();
    final String tessdataDirectory = join(appDirectory.path, 'tessdata');

    if (!await Directory(tessdataDirectory).exists()) {
      await Directory(tessdataDirectory).create();
    }
    await _copyTessDataToAppDocumentsDirectory(tessdataDirectory);
    return appDirectory.path;
  }

  static Future _copyTessDataToAppDocumentsDirectory(
      String tessdataDirectory) async {
    final String config = await rootBundle.loadString(tessDataConfigAsset);
    Map<String, dynamic> files = jsonDecode(config);
    for (var file in files["files"]) {
      if (!await File('$tessdataDirectory/$file').exists()) {
        final ByteData data = await rootBundle.load('$tessDataPath/$file');
        final Uint8List bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await File('$tessdataDirectory/$file').writeAsBytes(bytes);
      }
    }
  }
}
