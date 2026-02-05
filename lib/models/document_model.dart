// lib/models/document_model.dart
// 🔥 YANGILANGAN - Favorites va Categories qo'shildi

import 'package:hive/hive.dart';

part 'document_model.g.dart';

@HiveType(typeId: 1)
class DocumentModel extends HiveObject {
  @HiveField(0)
  final String title;

  @HiveField(1)
  final String filePath;

  @HiveField(2)
  final DateTime createdAt;

  /// pdf / docx kabi hujjat turi
  @HiveField(3)
  final String? fileType;

  /// 🔥 YANGI: Sevimli hujjat
  @HiveField(4)
  bool isFavorite;

  /// 🔥 YANGI: Kategoriya
  @HiveField(5)
  String category;

  DocumentModel({
    required this.title,
    required this.filePath,
    required this.createdAt,
    this.fileType,
    this.isFavorite = false,
    this.category = 'Umumiy',
  });

  /// Agar fileType null bo'lsa, filePath'dan taxmin qilamiz
  String get resolvedType {
    final t = (fileType ?? "").toLowerCase().trim();
    if (t == "pdf" || t == "docx") return t;

    final lower = filePath.toLowerCase();
    if (lower.endsWith(".pdf")) return "pdf";
    if (lower.endsWith(".docx")) return "docx";
    return "file";
  }

  /// 🔁 Nusxa olish (rename/update uchun)
  DocumentModel copyWith({
    String? title,
    String? filePath,
    DateTime? createdAt,
    String? fileType,
    bool? isFavorite,
    String? category,
  }) {
    return DocumentModel(
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      createdAt: createdAt ?? this.createdAt,
      fileType: fileType ?? this.fileType,
      isFavorite: isFavorite ?? this.isFavorite,
      category: category ?? this.category,
    );
  }
}
