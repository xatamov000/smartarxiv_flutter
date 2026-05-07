// lib/services/image_compress_service.dart
// Rasm siqish xizmati — max 2000px, JPEG 80% sifat
// compute() orqali alohida isolate da ishlanadi (UI bloklanmaydi)

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImageCompressService {
  static const int maxDimension = 2000;
  static const int jpegQuality = 80;

  /// Bitta rasmni siqish: max 2000px, JPEG 80%
  static Future<File> compressImage(File file) async {
    final bytes = await file.readAsBytes();
    final dir = await getTemporaryDirectory();
    final outPath =
        '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final compressed = await compute(_processImage, bytes);

    if (compressed == null) {
      return file; // Dekod qilib bo'lmasa original qaytariladi
    }

    final outFile = File(outPath);
    await outFile.writeAsBytes(compressed);
    return outFile;
  }

  /// Bir nechta rasmlarni siqish (progress callback bilan)
  static Future<List<File>> compressImages(
    List<File> files, {
    void Function(int current, int total)? onProgress,
  }) async {
    final results = <File>[];
    for (int i = 0; i < files.length; i++) {
      onProgress?.call(i + 1, files.length);
      final compressed = await compressImage(files[i]);
      results.add(compressed);
    }
    return results;
  }

  /// Isolate ichida ishlaydigan funksiya (UI thread bloklanmaydi)
  static List<int>? _processImage(Uint8List bytes) {
    try {
      var image = img.decodeImage(bytes);
      if (image == null) return null;

      // Agar rasm 2000px dan katta bo'lsa — resize qilinadi
      if (image.width > maxDimension || image.height > maxDimension) {
        if (image.width >= image.height) {
          image = img.copyResize(image, width: maxDimension);
        } else {
          image = img.copyResize(image, height: maxDimension);
        }
      }

      return img.encodeJpg(image, quality: jpegQuality);
    } catch (_) {
      return null;
    }
  }
}
