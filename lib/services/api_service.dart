// lib/services/api_service.dart
//
// Backend API (FastAPI) bilan ishlash:
// - /health
// - /ocr (text + detected_lang)
// - /build-docx
// - /image-to-docx
// - /images-to-docx

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:hive/hive.dart';

// ============================================================
// OCR RESPONSE MODEL
// ============================================================

class OcrResult {
  final String text;
  final String? detectedLang;

  OcrResult({required this.text, this.detectedLang});

  factory OcrResult.fromJson(Map data) {
    return OcrResult(
      text: (data["text"] ?? "").toString(),
      detectedLang: data["detected_lang"]?.toString(),
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

  static const String _defaultBaseUrl = "http://127.0.0.1:8000";

  String _readBaseUrl() {
    try {
      final box = Hive.box('settings_box');
      final v = (box.get('base_url') ?? '').toString().trim();
      return v.isEmpty ? _defaultBaseUrl : v;
    } catch (_) {
      return _defaultBaseUrl;
    }
  }

  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _readBaseUrl(),
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 120),
      headers: {"Accept": "application/json"},
    ),
  );

  void _refreshBaseUrl() {
    final url = _readBaseUrl();
    if (_dio.options.baseUrl != url) {
      _dio.options.baseUrl = url;
    }
  }

  // ------------------------------------------------------------
  // Health
  // ------------------------------------------------------------

  Future<bool> checkHealth() async {
    try {
      _refreshBaseUrl();
      final res = await _dio.get("/health");
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------
  // OCR: image -> text + detected_lang
  // ------------------------------------------------------------

  Future<OcrResult> sendImageForOcr(
    File image, {
    String lang = "auto",
    String? documentId,
  }) async {
    try {
      _refreshBaseUrl();

      final formData = FormData.fromMap({
        "image": await MultipartFile.fromFile(image.path),
        "lang": lang,
        if (documentId != null) "document_id": documentId,
      });

      final res = await _dio.post("/ocr", data: formData);
      final data = res.data;

      if (data is Map) return OcrResult.fromJson(data);
      return OcrResult(text: "");
    } on DioException catch (e) {
      throw Exception(_niceDioError(e));
    } catch (e) {
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
        "/build-docx",
        data: FormData.fromMap({"text": text}),
        options: Options(responseType: ResponseType.bytes),
      );
      return List<int>.from(res.data);
    } on DioException catch (e) {
      throw Exception(_niceDioError(e));
    }
  }

  // ------------------------------------------------------------
  // DOCX: 1 image
  // ------------------------------------------------------------

  Future<List<int>> buildDocxFromSingleImage(
    File image, {
    String lang = "auto",
    String? documentId,
  }) async {
    try {
      _refreshBaseUrl();

      final formData = FormData.fromMap({
        "image": await MultipartFile.fromFile(image.path),
        "lang": lang,
        if (documentId != null) "document_id": documentId,
      });

      final res = await _dio.post(
        "/image-to-docx",
        data: formData,
        options: Options(responseType: ResponseType.bytes),
      );

      return List<int>.from(res.data);
    } on DioException catch (e) {
      throw Exception(_niceDioError(e));
    }
  }

  // ------------------------------------------------------------
  // DOCX: many images
  // ------------------------------------------------------------

  Future<List<int>> buildDocxFromImages(
    List<File> images, {
    String lang = "auto",
    String? documentId,
  }) async {
    if (images.isEmpty) {
      throw Exception("Rasm yo‘q (images bo‘sh).");
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

      final files = <MultipartFile>[];
      for (final f in images) {
        files.add(await MultipartFile.fromFile(f.path));
      }

      final formData = FormData.fromMap({
        "images": files,
        "lang": lang,
        if (documentId != null) "document_id": documentId,
      });

      final res = await _dio.post(
        "/images-to-docx",
        data: formData,
        options: Options(responseType: ResponseType.bytes),
      );

      return List<int>.from(res.data);
    } on DioException catch (e) {
      throw Exception(_niceDioError(e));
    }
  }

  // ------------------------------------------------------------
  // Helpers
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

    return e.message ?? "Network xatolik";
  }
}
