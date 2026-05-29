// lib/services/image_compress_service.dart
//
// OCR uchun manbaga moslashgan rasm tayyorlash xizmati.
//
// Asosiy o'zgarishlar (v1 → v2):
//   • Screenshot'lar (PNG, uzun aspect) HECH QACHON qayta kodlanmaydi —
//     PNG holatida saqlanadi (8×8 DCT bloklash artefaktlari yo'q).
//   • Kamera/galereya suratlari faqat uzun chet > 3500px bo'lsagina
//     1920px ga kichraytiriladi. JPEG sifati 80 → 92 (OCR-xavfsiz).
//   • Hech qachon kichik rasmlarni zo'rlab kichraytirmaydi (eski kod
//     1080-1440px screenshot'larni 2000px ga buzadigan edi).
//   • compute() orqali alohida isolate'da ishlanadi (UI bloklanmaydi).

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageCompressService {
  /// Maksimal qabul qilinadigan o'lcham — bundan kattalari kichraytiriladi
  static const int kMaxDimension = 3500;

  /// Kichraytirish maqsadli o'lchami (backend det_limit_side_len = 1920)
  static const int kTargetDimension = 1920;

  /// OCR-xavfsiz JPEG sifati (eski 80 — matn chetlarida ringing yaratadi)
  static const int kJpegQuality = 92;

  /// Bitta rasmni OCR uchun tayyorlash.
  /// Manbaga moslashadi — screenshot'larni qayta kodlamaydi.
  static Future<File> compressImage(File file) async {
    final bytes = await file.readAsBytes();
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;

    final result = await compute(
      _prepareForOcr,
      _PrepareInput(bytes: bytes, sourcePath: file.path),
    );

    if (result == null) {
      // Decode bo'lmadi — original yuboramiz
      return file;
    }

    final ext = result.isPng ? 'png' : 'jpg';
    final outPath = '${dir.path}/ocr_$ts.$ext';
    final outFile = File(outPath);
    await outFile.writeAsBytes(result.bytes);
    return outFile;
  }

  /// Bir nechta rasmlar (progress callback bilan)
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

  // ────────────────────────────────────────────────
  // Isolate ichida ishlaydigan funksiya
  // ────────────────────────────────────────────────

  static _PrepareOutput? _prepareForOcr(_PrepareInput input) {
    try {
      final decoded = img.decodeImage(input.bytes);
      if (decoded == null) return null;

      final ext = p.extension(input.sourcePath).toLowerCase();
      final w = decoded.width;
      final h = decoded.height;
      final aspect = w == 0 ? 1.0 : (h / w);

      // Screenshot aniqlash:
      //   PNG fayl + uzun aspect (>1.7) → telefon screenshot
      //   YOKI: PNG fayl va chetlari deyarli toza (raqamli)
      final isScreenshot =
          (ext == '.png' && aspect > 1.7) ||
          (ext == '.png' && _looksLikeDigitalImage(decoded));

      if (isScreenshot) {
        // Screenshot: hech qachon JPEG'ga qayta kodlamaslik.
        // Faqat haddan tashqari katta bo'lsagina aql bilan kichraytirish.
        final longEdge = w > h ? w : h;
        if (longEdge > kMaxDimension) {
          final scale = kTargetDimension / longEdge;
          final resized = img.copyResize(
            decoded,
            width: (w * scale).round(),
            height: (h * scale).round(),
            interpolation: img.Interpolation.average,
          );
          return _PrepareOutput(
            bytes: img.encodePng(resized, level: 6),
            isPng: true,
          );
        }
        // Original PNG bayt'lari aynan saqlanadi — qayta kodlash yo'q
        return _PrepareOutput(
          bytes: List<int>.from(input.bytes),
          isPng: true,
        );
      }

      // Kamera / galereya surati yo'li:
      final longEdge = w > h ? w : h;
      img.Image toEncode = decoded;

      if (longEdge > kMaxDimension) {
        // Faqat haqiqatan ortiqcha katta bo'lsa kichraytirish
        // (zamonaviy telefon foto 4032px — matn uchun ortiqcha)
        final scale = kTargetDimension / longEdge;
        toEncode = img.copyResize(
          decoded,
          width: (w * scale).round(),
          height: (h * scale).round(),
          interpolation: img.Interpolation.cubic, // matn uchun cubic
        );
      }
      // longEdge ≤ kMaxDimension bo'lsa — ORIGINAL O'LCHAMDA QOLAMIZ.
      // Eski koddagi xato: 1080px rasmlarni ham 2000px ga "kichraytiradi"
      // bu o'lchamni o'zgartirishga umuman zarurat yo'q edi.

      return _PrepareOutput(
        bytes: img.encodeJpg(toEncode, quality: kJpegQuality),
        isPng: false,
      );
    } catch (_) {
      return null;
    }
  }

  /// "Raqamli" rasm belgisi: chetlar pikselllari deyarli bir xil rangda
  /// (kamera surati emas).
  static bool _looksLikeDigitalImage(img.Image image) {
    if (image.height < 50 || image.width < 50) return false;
    final samples = <int>[];
    var sum = 0.0;
    final rowsToCheck = [0, 1, 2, image.height - 1, image.height - 2];
    for (final y in rowsToCheck) {
      if (y < 0 || y >= image.height) continue;
      for (var x = 0; x < image.width; x += 8) {
        final px = image.getPixel(x, y);
        // ITU-R BT.601 luma
        final l = (0.299 * px.r + 0.587 * px.g + 0.114 * px.b).toInt();
        samples.add(l);
        sum += l;
      }
    }
    if (samples.length < 20) return false;
    final mean = sum / samples.length;
    var variance = 0.0;
    for (final s in samples) {
      variance += (s - mean) * (s - mean);
    }
    variance /= samples.length;
    // Past varians (~64 dan past) → raqamli rasm
    return variance < 64;
  }
}

// ────────────────────────────────────────────────
// Isolate uchun yordamchi sinflar
// ────────────────────────────────────────────────

class _PrepareInput {
  final Uint8List bytes;
  final String sourcePath;
  _PrepareInput({required this.bytes, required this.sourcePath});
}

class _PrepareOutput {
  final List<int> bytes;
  final bool isPng;
  _PrepareOutput({required this.bytes, required this.isPng});
}