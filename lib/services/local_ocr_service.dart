// lib/services/local_ocr_service.dart
// ⚡ 100% LOCAL OCR SERVICE - Server kerak emas!

import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class LocalOcrService {
  // Text recognizer (Latin script)
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Perform OCR on device - Fast, Free, Offline!
  ///
  /// Returns extracted text from image
  Future<String> recognizeText(File image) async {
    try {
      print('⚡ Starting LOCAL OCR (on-device)...');
      final startTime = DateTime.now();

      // Convert to InputImage
      final inputImage = InputImage.fromFile(image);

      // Process image
      final recognizedText = await textRecognizer.processImage(inputImage);

      // Calculate duration
      final duration = DateTime.now().difference(startTime);
      print('✅ Local OCR completed in ${duration.inMilliseconds}ms');
      print('📝 Extracted ${recognizedText.text.length} characters');

      return recognizedText.text;
    } catch (e) {
      print('❌ Local OCR failed: $e');
      throw Exception('OCR error: $e');
    }
  }

  /// Get confidence score for text quality
  /// Returns 0.0 - 1.0 (higher is better)
  double getConfidence(String text) {
    if (text.isEmpty) return 0.0;

    int score = 0;

    // Has reasonable length
    if (text.length >= 10) score += 25;

    // Has spaces (not all concatenated)
    if (text.contains(' ')) score += 20;

    // Has punctuation
    if (RegExp(r'[.,!?;:]').hasMatch(text)) score += 20;

    // Has reasonable word count
    final wordCount = text.split(RegExp(r'\s+')).length;
    if (wordCount >= 3 && wordCount <= 1000) score += 25;

    // Valid characters ratio
    final validPattern = RegExp(r"[a-zA-Zа-яА-ЯёЁ0-9\s.,!?;:()\-]");
    final chars = text.split('');
    final validCount = chars.where((c) => validPattern.hasMatch(c)).length;
    final validRatio = validCount / text.length;

    if (validRatio > 0.85) score += 10;

    return score / 100;
  }

  /// Check if text has Cyrillic characters
  bool hasCyrillic(String text) {
    return RegExp(r'[а-яА-ЯёЁ]').hasMatch(text);
  }

  /// Clean up and format text
  String cleanText(String text) {
    String result = text;

    // Remove multiple spaces
    result = result.replaceAll(RegExp(r' +'), ' ');

    // Remove multiple newlines (max 2)
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // Trim each line
    final lines = result.split('\n');
    result = lines.map((line) => line.trim()).join('\n');

    return result.trim();
  }

  /// Dispose resources
  void dispose() {
    textRecognizer.close();
  }
}
