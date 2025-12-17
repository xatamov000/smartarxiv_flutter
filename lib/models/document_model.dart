// lib/models/document_model.dart
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

  /// pdf / docx kabi hujjat turi (eski yozuvlarda null bo'lishi mumkin)
  @HiveField(3)
  final String? fileType;

  DocumentModel({
    required this.title,
    required this.filePath,
    required this.createdAt,
    this.fileType,
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
  }) {
    return DocumentModel(
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      createdAt: createdAt ?? this.createdAt,
      fileType: fileType ?? this.fileType,
    );
  }
}
