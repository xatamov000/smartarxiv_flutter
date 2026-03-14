// lib/services/local_ocr_service.dart
// ⚡ HYBRID OCR SERVICE v2
//
// ML Kit = PRIMARY (tez, aniq, ro'yxatlar yaxshi)
// Tesseract = FAQAT Cyrillic uchun fallback

import 'dart:io';

import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class LocalOcrService {
  final _mlKitRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// OCR — ML Kit primary, Tesseract fallback for Cyrillic
  Future<String> recognizeText(File image) async {
    try {
      print('⚡ Starting LOCAL OCR (ML Kit primary)...');
      final startTime = DateTime.now();

      // STEP 1: ML Kit bilan OCR
      final inputImage = InputImage.fromFile(image);
      final mlKitResult = await _mlKitRecognizer.processImage(inputImage);
      final mlKitText = mlKitResult.text;

      final duration = DateTime.now().difference(startTime);
      print('✅ ML Kit completed in ${duration.inMilliseconds}ms');
      print('📝 ML Kit: ${mlKitText.length} characters');

      // STEP 2: Buzilgan Cyrillic bormi tekshirish
      if (_hasGarbledCyrillic(mlKitText)) {
        print('🔤 Buzilgan Cyrillic aniqlandi — Tesseract ishlatilmoqda...');

        try {
          final tessStart = DateTime.now();
          final tessText = await FlutterTesseractOcr.extractText(
            image.path,
            language: 'rus+eng+uzb+uzb_cyrl',
            args: {'psm': '3', 'preserve_interword_spaces': '1'},
          );

          final tessDuration = DateTime.now().difference(tessStart);
          print('✅ Tesseract completed in ${tessDuration.inMilliseconds}ms');
          print('📝 Tesseract: ${tessText.length} characters');

          final bestText = _chooseBestResult(mlKitText, tessText);
          print('🏆 Best: ${bestText == mlKitText ? "ML Kit" : "Tesseract"}');
          return bestText;
        } catch (e) {
          print('⚠️ Tesseract failed, using ML Kit: $e');
          return mlKitText;
        }
      }

      return mlKitText;
    } catch (e) {
      print('❌ Local OCR failed: $e');
      throw Exception('OCR error: $e');
    }
  }

  /// Buzilgan Cyrillic aniqlash
  /// ML Kit Latin script Cyrillic harflarni noto'g'ri o'qiydi:
  /// "Рутковская" → "PyTKOBCKas", "Нейронные" → "HeipoHHble"
  bool _hasGarbledCyrillic(String text) {
    if (text.length < 20) return false;

    final words = text.split(RegExp(r'\s+'));
    int garbledCount = 0;

    for (final word in words) {
      if (word.length < 4) continue;

      // 3+ consecutive uppercase ichida + kichik harf aralash = garbled
      if (RegExp(r'[A-Z]{3,}').hasMatch(word) &&
          RegExp(r'[a-z]').hasMatch(word) &&
          !RegExp(r'^[A-Z]+$').hasMatch(word)) {
        garbledCount++;
      }
    }

    // 1 ta garbled so'z ham yetarli
    final hasGarbled = garbledCount >= 1;
    if (hasGarbled) {
      print('🔍 Garbled words found: $garbledCount');
    }
    return hasGarbled;
  }

  /// Ikkala natijadan yaxshisini tanlash
  String _chooseBestResult(String mlKit, String tesseract) {
    if (tesseract.trim().isEmpty) return mlKit;
    if (mlKit.trim().isEmpty) return tesseract;

    final hasCyrillic = RegExp(r'[а-яА-ЯёЁ]').hasMatch(tesseract);

    if (hasCyrillic) {
      final mlKitNumbered =
          RegExp(r'^\d{1,3}[.\)]\s', multiLine: true).allMatches(mlKit).length;
      final tessNumbered =
          RegExp(
            r'^\d{1,3}[.\)]\s',
            multiLine: true,
          ).allMatches(tesseract).length;

      if (mlKitNumbered > tessNumbered + 3) {
        print('📊 ML Kit better for lists ($mlKitNumbered vs $tessNumbered)');
        return mlKit;
      }

      return tesseract;
    }

    return mlKit;
  }

  double getConfidence(String text) {
    if (text.isEmpty) return 0.0;

    int score = 0;
    if (text.length >= 10) score += 25;
    if (text.contains(' ')) score += 20;
    if (RegExp(r'[.,!?;:]').hasMatch(text)) score += 20;

    final wordCount = text.split(RegExp(r'\s+')).length;
    if (wordCount >= 3 && wordCount <= 1000) score += 25;

    final validPattern = RegExp(r"[a-zA-Zа-яА-ЯёЁўқғҳЎҚҒҲ0-9\s.,!?;:()\-]");
    final chars = text.split('');
    final validCount = chars.where((c) => validPattern.hasMatch(c)).length;
    final validRatio = validCount / text.length;
    if (validRatio > 0.85) score += 10;

    return score / 100;
  }

  bool hasCyrillic(String text) {
    return RegExp(r'[а-яА-ЯёЁ]').hasMatch(text);
  }

  String cleanText(String text) {
    String result = text;
    result = result.replaceAll(RegExp(r' +'), ' ');
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    final lines = result.split('\n');
    result = lines.map((line) => line.trim()).join('\n');
    return result.trim();
  }

  void dispose() {
    _mlKitRecognizer.close();
  }
}
