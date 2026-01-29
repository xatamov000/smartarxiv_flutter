// lib/services/document_service.dart
//
// 🔥 YANGILANGAN Document Service - fastMode parametri bilan
//

import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../models/document_model.dart';
import 'api_service.dart';

class DocumentService {
  DocumentService._internal();
  static final DocumentService _instance = DocumentService._internal();
  factory DocumentService() => _instance;

  static const String _boxName = 'documents_box';
  Box<DocumentModel>? _box;

  Future<Box<DocumentModel>> _openBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<DocumentModel>(_boxName);
    return _box!;
  }

  /// ✅ DocumentsPage FutureBuilder uchun
  Future<Box<DocumentModel>> openBoxForUi() => _openBox();

  List<DocumentModel> getDocuments() {
    if (_box == null || !_box!.isOpen) return [];
    return _box!.values.toList().reversed.toList();
  }

  // ============================================================
  // TEXT -> DOCX
  // ============================================================

  Future<DocumentModel> createDocxFromText({
    required String title,
    required String text,
  }) async {
    final api = ApiService();
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      throw Exception("Matn bo'sh. DOCX yaratib bo'lmaydi.");
    }

    final bytes = await api.buildDocxFromText(cleanText);

    final dir = await getApplicationDocumentsDirectory();
    final safeName = _safeFileName(title);
    final filePath =
        "${dir.path}/${safeName}_${DateTime.now().millisecondsSinceEpoch}.docx";

    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    final doc = DocumentModel(
      title: title.trim().isEmpty ? "Hujjat" : title.trim(),
      filePath: filePath,
      createdAt: DateTime.now(),
      fileType: "docx",
    );

    final box = await _openBox();
    await box.add(doc);
    return doc;
  }

  // ============================================================
  // IMAGES -> DOCX (SYNC with OCR) - 🔥 FASTMODE QOSHILDI
  // ============================================================

  Future<DocumentModel> createDocxFromImages({
    required String title,
    required List<File> images,
    String lang = "auto",
    String? documentId,
    bool fastMode = true, // 🔥 YANGI: default true (tezroq)
  }) async {
    final api = ApiService();

    if (images.isEmpty) {
      throw Exception("Rasm yo'q. DOCX yaratib bo'lmaydi.");
    }

    final bytes = await api.buildDocxFromImages(
      images,
      lang: lang,
      documentId: documentId,
      fastMode: fastMode, // 🔥 YANGI
    );

    final dir = await getApplicationDocumentsDirectory();
    final safeName = _safeFileName(title);
    final filePath =
        "${dir.path}/${safeName}_${DateTime.now().millisecondsSinceEpoch}.docx";

    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    final doc = DocumentModel(
      title: title.trim().isEmpty ? "Hujjat" : title.trim(),
      filePath: filePath,
      createdAt: DateTime.now(),
      fileType: "docx",
    );

    final box = await _openBox();
    await box.add(doc);
    return doc;
  }

  // ============================================================
  // CRUD
  // ============================================================

  Future<void> deleteDocument(int index) async {
    final box = await _openBox();
    final key = box.keyAt(box.length - 1 - index);
    final doc = box.get(key);

    if (doc != null) {
      final file = File(doc.filePath);
      if (await file.exists()) await file.delete();
    }
    await box.delete(key);
  }

  Future<void> renameDocument(int index, String newTitle) async {
    final box = await _openBox();
    final key = box.keyAt(box.length - 1 - index);
    final doc = box.get(key);
    if (doc == null) return;

    final t = newTitle.trim();
    if (t.isEmpty) return;

    await box.put(key, doc.copyWith(title: t));
  }

  // ============================================================
  // Helpers
  // ============================================================

  String _safeFileName(String input) {
    final s = input.trim();
    if (s.isEmpty) return "document";

    final cleaned = s
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');

    return cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
  }
}
