// lib/services/api_service.dart
//
// ✅ FINAL VERSION - Hybrid OCR
// 1. Cloud OCR (backend) - sifatli
// 2. Local OCR (on-device) - tez
// 3. Hybrid logic - smart selection
//

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:hive/hive.dart';

import 'local_ocr_service.dart'; // ← LOCAL OCR IMPORT

// ============================================================
// OCR RESPONSE MODEL
// ============================================================

class OcrResult {
  final String text;
  final String? detectedLang;
  final String? source; // 'local' or 'cloud'
  final double? confidence; // Quality score

  OcrResult({
    required this.text,
    this.detectedLang,
    this.source,
    this.confidence,
  });

  factory OcrResult.fromJson(Map data) {
    return OcrResult(
      text: (data["text"] ?? "").toString(),
      detectedLang: data["detected_lang"]?.toString(),
      source: 'cloud',
      confidence: null,
    );
  }
}

// ============================================================
// API SERVICE
// ============================================================

class ApiService {
  ApiService._internal();
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  static const String _defaultBaseUrl = "http://10.38.221.170:8000";
  String _readBaseUrl() {
    try {
      final box = Hive.box('settings_box');
      final v = (box.get('base_url') ?? '').toString().trim();
      if (v.endsWith('/')) {
        return v.substring(0, v.length - 1);
      }
      return v.isEmpty ? _defaultBaseUrl : v;
    } catch (_) {
      return _defaultBaseUrl;
    }
  }

  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _readBaseUrl(),
      connectTimeout: const Duration(seconds: 120),
      receiveTimeout: const Duration(seconds: 300),
      sendTimeout: const Duration(seconds: 300),
      headers: {"Accept": "application/json"},
    ),
  );

  // ✅ LOCAL OCR INSTANCE
  final _localOcr = LocalOcrService();

  void _refreshBaseUrl() {
    final url = _readBaseUrl();
    if (_dio.options.baseUrl != url) {
      _dio.options.baseUrl = url;
    }
  }

  // ------------------------------------------------------------
  // Pre-warm server
  // ------------------------------------------------------------

  Future<void> _prewarmServer() async {
    try {
      print("🔥 Pre-warming server...");
      await _dio.get(
        "/health",
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      print("✅ Server warmed up!");
    } catch (e) {
      print("⚠️ Pre-warm failed (continuing anyway): $e");
    }
  }

  // ------------------------------------------------------------
  // Health check
  // ------------------------------------------------------------

  Future<bool> checkHealth({int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        _refreshBaseUrl();
        print("🔄 Backend tekshirilmoqda (urinish $attempt/$maxRetries)...");

        final res = await _dio.get(
          "/health",
          options: Options(
            sendTimeout: const Duration(seconds: 120),
            receiveTimeout: const Duration(seconds: 120),
          ),
        );

        if (res.statusCode == 200) {
          print("✅ Backend tayyor!");
          return true;
        }
      } catch (e) {
        print("❌ Urinish $attempt xatolik: $e");

        if (attempt < maxRetries) {
          final waitSeconds = attempt * 3;
          print("⏳ $waitSeconds sekund kutilmoqda...");
          await Future.delayed(Duration(seconds: waitSeconds));
        }
      }
    }

    print("❌ Backend ishlamayapti.");
    return false;
  }

  // ============================================================
  // ⚡ HYBRID OCR - Smart Selection
  // ============================================================

  /// HYBRID OCR: Try local first, fallback to cloud
  ///
  /// Usage:
  ///   final result = await ApiService().sendImageForOcrHybrid(image);
  ///
  /// Returns faster results using on-device OCR when possible,
  /// automatically falls back to cloud for complex images.
  Future<OcrResult> sendImageForOcrHybrid(
    File image, {
    String lang = "auto",
    String? documentId,
    bool forceCloud = false,
  }) async {
    // Option 1: Force cloud (skip local)
    if (forceCloud) {
      print('☁️ Force cloud mode - skipping local OCR');
      return await sendImageForOcr(image, lang: lang, documentId: documentId);
    }

    try {
      // Step 1: Try local OCR first (FAST!)
      print('⚡ Attempting local OCR...');
      final startTime = DateTime.now();

      final localText = await _localOcr.recognizeText(image);
      final confidence = _localOcr.getConfidence(localText);

      final duration = DateTime.now().difference(startTime);
      print(
        '📊 Local OCR: ${duration.inMilliseconds}ms, confidence: ${(confidence * 100).toInt()}%',
      );

      // Step 2: Check if quality is good enough
      if (confidence >= 0.75) {
        // Good quality! Use local result
        print('✅ Local OCR successful (high confidence)');
        return OcrResult(
          text: localText,
          detectedLang: 'auto',
          source: 'local',
          confidence: confidence,
        );
      } else {
        // Low quality, fallback to cloud
        print('⚠️ Local confidence low (${(confidence * 100).toInt()}%)');
        print('☁️ Falling back to cloud OCR for better quality...');

        final cloudResult = await sendImageForOcr(
          image,
          lang: lang,
          documentId: documentId,
        );

        return OcrResult(
          text: cloudResult.text,
          detectedLang: cloudResult.detectedLang,
          source: 'cloud',
          confidence: 0.95, // Cloud is high quality
        );
      }
    } catch (e) {
      // Local OCR failed completely, use cloud
      print('❌ Local OCR error: $e');
      print('☁️ Using cloud OCR as fallback...');

      final cloudResult = await sendImageForOcr(
        image,
        lang: lang,
        documentId: documentId,
      );

      return OcrResult(
        text: cloudResult.text,
        detectedLang: cloudResult.detectedLang,
        source: 'cloud (local failed)',
        confidence: 0.95,
      );
    }
  }

  // ------------------------------------------------------------
  // CLOUD OCR (original method - kept for compatibility)
  // ------------------------------------------------------------

  Future<OcrResult> sendImageForOcr(
    File image, {
    String lang = "auto",
    String? documentId,
    bool fastMode = false,
  }) async {
    try {
      _refreshBaseUrl();
      await _prewarmServer();

      print("📸 Sending image to cloud OCR...");

      final formData = FormData.fromMap({
        "image": await MultipartFile.fromFile(image.path),
        "lang": lang,
        if (documentId != null) "document_id": documentId,
      });

      final res = await _dio.post("/ocr", data: formData);
      final data = res.data;

      print("✅ Cloud OCR completed!");

      if (data is Map) return OcrResult.fromJson(data);
      return OcrResult(text: "", source: 'cloud');
    } on DioException catch (e) {
      print("❌ OCR XATOLIK:");
      print("  Status: ${e.response?.statusCode}");
      print("  Message: ${e.message}");
      print("  Type: ${e.type}");
      if (e.response?.data != null) {
        print("  Response: ${e.response?.data}");
      }
      throw Exception(_niceDioError(e));
    } catch (e) {
      print("❌ Unexpected error: $e");
      throw Exception("OCR xatolik: $e");
    }
  }

  // ------------------------------------------------------------
  // DOCX: text -> docx
  // ------------------------------------------------------------

  Future<List<int>> buildDocxFromText(String text) async {
    try {
      _refreshBaseUrl();
      final res = await _dio.post(
        "/text-to-docx",
        data: FormData.fromMap({"text": text}),
        options: Options(responseType: ResponseType.bytes),
      );
      return List<int>.from(res.data);
    } on DioException catch (e) {
      throw Exception(_niceDioError(e));
    }
  }

  // ------------------------------------------------------------
  // DOCX from single image
  // ------------------------------------------------------------

  Future<List<int>> buildDocxFromSingleImage(
    File image, {
    String lang = "auto",
    String? documentId,
    bool fastMode = false,
  }) async {
    try {
      _refreshBaseUrl();
      await _prewarmServer();

      final formData = FormData.fromMap({
        "image": await MultipartFile.fromFile(image.path),
        "lang": lang,
        if (documentId != null) "document_id": documentId,
      });

      // /ocr/docx — strukturaviy (heading, list, paragraph) DOCX
      final res = await _dio.post(
        "/ocr/docx",
        data: formData,
        options: Options(responseType: ResponseType.bytes),
      );

      return List<int>.from(res.data);
    } on DioException catch (e) {
      throw Exception(_niceDioError(e));
    }
  }

  // ------------------------------------------------------------
  // DOCX from multiple images
  // ------------------------------------------------------------

  Future<List<int>> buildDocxFromImages(
    List<File> images, {
    String lang = "auto",
    String? documentId,
    bool fastMode = false,
  }) async {
    if (images.isEmpty) {
      throw Exception("Rasm yo'q (images bo'sh).");
    }

    if (images.length == 1) {
      return buildDocxFromSingleImage(
        images.first,
        lang: lang,
        documentId: documentId,
      );
    }

    try {
      _refreshBaseUrl();
      await _prewarmServer();

      final files = <MultipartFile>[];
      for (final f in images) {
        files.add(await MultipartFile.fromFile(f.path));
      }

      final formData = FormData.fromMap({
        // /ocr/docx/multi — ko'p sahifa uchun
        "images": files,
        "lang": lang,
        if (documentId != null) "document_id": documentId,
      });

      final res = await _dio.post(
        "/ocr/docx/multi",
        data: formData,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 600),
        ),
      );

      return List<int>.from(res.data);
    } on DioException catch (e) {
      throw Exception(_niceDioError(e));
    }
  }

  // ------------------------------------------------------------
  // Error handling
  // ------------------------------------------------------------

  String _niceDioError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    String detail = "";
    if (data is Map && data["detail"] != null) {
      detail = data["detail"].toString();
    }

    if (status != null) {
      return "HTTP $status xatolik.\n${detail.isNotEmpty ? detail : e.message}";
    }

    if (e.type == DioExceptionType.connectionTimeout) {
      return "⏱️ Server javob bermadi (timeout).\n\n"
          "Ehtimol:\n"
          "• Backend uyqu holatida (birinchi request sekin)\n"
          "• Internet aloqasi zaif\n"
          "• Rasm juda katta\n\n"
          "Qayta urinib ko'ring!";
    }

    if (e.type == DioExceptionType.receiveTimeout) {
      return "⏱️ Server juda sekin javob berdi.\n\n"
          "Ehtimol:\n"
          "• Rasm juda katta\n"
          "• Server band\n"
          "• Internet sekin\n\n"
          "Rasmni kichikroq qiling yoki qayta urinib ko'ring.";
    }

    if (e.type == DioExceptionType.connectionError) {
      return "🌐 Internetga ulanish xatolik.\n\n"
          "Tekshiring:\n"
          "• Internet ulanishi\n"
          "• Backend URL: ${_dio.options.baseUrl}\n"
          "• VPN faol bo'lsa, o'chiring\n\n"
          "Qayta urinib ko'ring!";
    }

    return "❌ Network xatolik: ${e.message ?? 'Unknown'}";
  }

  // ------------------------------------------------------------
  // Cleanup
  // ------------------------------------------------------------

  void dispose() {
    _localOcr.dispose();
  }
}
