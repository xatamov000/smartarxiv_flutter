// lib/services/local_ocr_service.dart
// ⚡ LOCAL OCR SERVICE - Updated for new ML Kit package

import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class LocalOcrService {
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> recognizeText(File image) async {
    try {
      print('Starting LOCAL OCR');
      final startTime = DateTime.now();

      final inputImage = InputImage.fromFile(image);
      final recognizedText = await textRecognizer.processImage(inputImage);

      final duration = DateTime.now().difference(startTime);
      print('Local OCR done in ${duration.inMilliseconds}ms');

      return recognizedText.text;
    } catch (e) {
      print('Local OCR failed: $e');
      throw Exception('Local OCR error: $e');
    }
  }

  double getConfidence(String text) {
    if (text.isEmpty) return 0.0;

    int score = 0;

    // Has reasonable length
    if (text.length >= 10) score += 25;

    // Has spaces
    if (text.contains(' ')) score += 20;

    // Has punctuation
    if (RegExp(r'[.,!?;:]').hasMatch(text)) score += 20;

    // Has reasonable word count
    final wordCount = text.split(RegExp(r'\s+')).length;
    if (wordCount >= 3 && wordCount <= 1000) score += 25;

    // Check valid characters
    final validPattern = RegExp(
        r"[a-zA-Zа-яА-ЯёЁ0-9\s.,!?;:()\-]"
    );

    final chars = text.split('');
    final validCount = chars.where((c) => validPattern.hasMatch(c)).length;
    final validRatio = validCount / text.length;

    if (validRatio > 0.85) score += 10;

    return score / 100;
  }

  void dispose() {
    textRecognizer.close();
  }
}