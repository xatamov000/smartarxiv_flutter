// lib/services/api_service.dart

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:hive/hive.dart';

class OcrResult {
  final String text;
  final double? confidence;
  final String? imageSize;

  OcrResult({required this.text, this.confidence, this.imageSize});

  factory OcrResult.fromJson(Map data) {
    return OcrResult(
      text: (data["text"] ?? "").toString(),
      confidence: (data["confidence"] as num?)?.toDouble(),
      imageSize: data["image_size"]?.toString(),
    );
  }
}

class ApiService {
  ApiService._internal();
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  static const String _defaultBaseUrl = "http://10.163.30.170:8000";

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
      receiveTimeout: const Duration(seconds: 600),
      sendTimeout: const Duration(seconds: 600),
      headers: {"Accept": "application/json"},
    ),
  );

  void _refreshBaseUrl() {
    final url = _readBaseUrl();
    if (_dio.options.baseUrl != url) {
      _dio.options.baseUrl = url;
    }
  }

  Future<void> _prewarmServer() async {
    try {
      await _dio.get("/health");
    } catch (_) {}
  }

  // ============================================================
  // Health check
  // ============================================================

  Future<bool> checkHealth() async {
    try {
      _refreshBaseUrl();
      final res = await _dio.get(
        "/health",
        options: Options(
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // OCR → TEXT
  // ============================================================

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

      if (res.data is Map) {
        return OcrResult.fromJson(res.data);
      }

      return OcrResult(text: "");
    } on DioException catch (e) {
      throw Exception(_niceDioError(e));
    }
  }

  // ============================================================
  // IMAGE → DOCX
  // ============================================================

  Future<List<int>> buildDocxFromSingleImage(
    File image, {
    String lang = "auto",
    String? documentId,
  }) async {
    try {
      _refreshBaseUrl();
      await _prewarmServer();

      final formData = FormData.fromMap({
        "image": await MultipartFile.fromFile(image.path),
        "lang": lang,
        if (documentId != null) "document_id": documentId,
      });

      final res = await _dio.post(
        "/ocr/docx",
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

  // ============================================================
  // MULTI IMAGE → DOCX
  // ============================================================

  Future<List<int>> buildDocxFromImages(
    List<File> images, {
    String lang = "auto",
    String? documentId,
  }) async {
    if (images.isEmpty) {
      throw Exception("Rasm topilmadi");
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

      for (final img in images) {
        files.add(await MultipartFile.fromFile(img.path));
      }

      final formData = FormData.fromMap({
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

  // ============================================================
  // TEXT → DOCX
  // ============================================================

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

  // ============================================================
  // MERGE FILES
  // ============================================================

  Future<List<int>> mergeFiles(List<File> files) async {
    if (files.length < 2) {
      throw Exception("Kamida 2 ta fayl kerak.");
    }

    try {
      _refreshBaseUrl();
      await _prewarmServer();

      final multipartFiles = <MultipartFile>[];

      for (final file in files) {
        multipartFiles.add(
          await MultipartFile.fromFile(
            file.path,
            filename: file.path.split('/').last,
          ),
        );
      }

      final formData = FormData.fromMap({"files": multipartFiles});

      final res = await _dio.post(
        "/merge",
        data: formData,
        options: Options(responseType: ResponseType.bytes),
      );

      return List<int>.from(res.data);
    } on DioException catch (e) {
      throw Exception(_niceDioError(e));
    }
  }

  // ============================================================
  // ERROR HANDLING
  // ============================================================

  String _niceDioError(DioException e) {
    final status = e.response?.statusCode;

    if (status != null) {
      return "HTTP $status xatolik.";
    }

    if (e.type == DioExceptionType.connectionTimeout) {
      return "Server javob bermadi (timeout).";
    }

    if (e.type == DioExceptionType.connectionError) {
      return "Internet ulanish xatosi.";
    }

    if (e.type == DioExceptionType.receiveTimeout) {
      return "Server juda sekin javob berdi.";
    }

    return "Network xatolik: ${e.message}";
  }
}
