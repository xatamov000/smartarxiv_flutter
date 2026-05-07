// lib/services/ocr_api_service.dart
// Backend OCR xizmati — local_ocr_service o'rniga ishlatiladi
// Barcha OCR serverda amalga oshiriladi

import 'dart:io';

import 'api_service.dart';
import 'image_compress_service.dart';

class OcrProcessResult {
  final String text;
  final List<int>? docxBytes;

  OcrProcessResult({required this.text, this.docxBytes});
}

enum OcrErrorType { network, server, invalidImage }

class OcrApiException implements Exception {
  final String message;
  final OcrErrorType type;

  OcrApiException(this.message, this.type);

  @override
  String toString() => message;
}

class OcrApiService {
  OcrApiService._internal();
  static final OcrApiService _instance = OcrApiService._internal();
  factory OcrApiService() => _instance;

  final _api = ApiService();

  /// Check backend availability
  Future<bool> isAvailable() => _api.checkHealth();

  /// Process images: compress → upload → OCR → result
  Future<OcrProcessResult> processImages(
    List<File> images, {
    void Function(String status, double progress)? onProgress,
  }) async {
    if (images.isEmpty) {
      throw OcrApiException('No images provided', OcrErrorType.invalidImage);
    }

    // 1. Server tekshirish
    onProgress?.call('Checking server...', 0.0);
    final isOnline = await _api.checkHealth();
    if (!isOnline) {
      throw OcrApiException(
        'No connection to server. Please check your internet connection.',
        OcrErrorType.network,
      );
    }

    // 2. Rasmlarni siqish
    onProgress?.call('Compressing images...', 0.05);
    final compressed = <File>[];
    for (int i = 0; i < images.length; i++) {
      final progress = 0.05 + (0.20 * (i + 1) / images.length);
      onProgress?.call('Compressing: ${i + 1}/${images.length}', progress);
      compressed.add(await ImageCompressService.compressImage(images[i]));
    }

    // 3. Har bir rasmni OCR qilish
    final allText = StringBuffer();
    for (int i = 0; i < compressed.length; i++) {
      final progress = 0.25 + (0.55 * (i + 1) / compressed.length);
      onProgress?.call('Running OCR: ${i + 1}/${compressed.length}', progress);

      try {
        final result = await _api.sendImageForOcr(compressed[i]);
        if (result.text.isNotEmpty) {
          if (compressed.length > 1) {
            allText.writeln('--- Page ${i + 1} ---\n');
          }
          allText.writeln(result.text);
          allText.writeln();
        }
      } catch (e) {
        throw OcrApiException(
          'Error processing image ${i + 1}: $e',
          OcrErrorType.server,
        );
      }
    }

    final text = allText.toString().trim();
    if (text.isEmpty) {
      throw OcrApiException(
        'No text found. Please make sure the image contains readable text.',
        OcrErrorType.invalidImage,
      );
    }

    onProgress?.call('Done!', 1.0);
    return OcrProcessResult(text: text);
  }

  /// Build DOCX from text (on server)
  Future<List<int>> buildDocx(String text) async {
    final isOnline = await _api.checkHealth();
    if (!isOnline) {
      throw OcrApiException('No connection to server', OcrErrorType.network);
    }
    return _api.buildDocxFromText(text);
  }

  /// Build DOCX directly from images (server OCR + formatting)
  Future<List<int>> buildDocxFromImages(List<File> images) async {
    final isOnline = await _api.checkHealth();
    if (!isOnline) {
      throw OcrApiException('No connection to server', OcrErrorType.network);
    }

    // Compress and send images
    final compressed = <File>[];
    for (final img in images) {
      compressed.add(await ImageCompressService.compressImage(img));
    }
    return _api.buildDocxFromImages(compressed);
  }
}
