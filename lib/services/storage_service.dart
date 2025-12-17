// lib/services/storage_service.dart

import 'package:hive/hive.dart';

import '../models/document_model.dart';

class StorageService {
  static const String documentBoxName = 'documents_box';
  static late Box<DocumentModel> _docBox;

  // Hive ni ishga tushirish va box ochish
  static Future<void> init() async {
    _docBox = await Hive.openBox<DocumentModel>(documentBoxName);
  }

  // Hujjat qo'shish
  static Future<void> addDocument(DocumentModel doc) async {
    await _docBox.add(doc);
  }

  // Barcha hujjatlarni olish
  static List<DocumentModel> getDocuments() {
    return _docBox.values.toList();
  }

  // Hujjatni o'chirish
  static Future<void> deleteDocument(int index) async {
    await _docBox.deleteAt(index);
  }

  // Hujjatni yangilash
  static Future<void> updateDocument(int index, DocumentModel doc) async {
    await _docBox.putAt(index, doc);
  }
}
