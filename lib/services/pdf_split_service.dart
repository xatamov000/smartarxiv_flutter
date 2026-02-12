// lib/services/pdf_split_service.dart
// ✂️ PDF fayllarni sahifalarga bo'lish xizmati
// 🔥 SODDA VERSIYA - Native PDF reader kerak bo'ladi

import 'dart:io';

class PdfSplitService {
  /// PDF sahifalari sonini olish (taxminiy)
  ///
  /// Bu sodda versiya - faqat fayl o'lchamidan taxmin qiladi
  /// Aniq natija uchun native PDF library kerak
  static Future<int> getPageCount(File pdfFile) async {
    try {
      // PDF faylni o'qish
      final bytes = await pdfFile.readAsBytes();
      final content = String.fromCharCodes(bytes);

      // PDF da "/Type /Page" ni sanash (taxminiy)
      final pagePattern = RegExp(r'/Type\s*/Page[^s]');
      final matches = pagePattern.allMatches(content);

      int count = matches.length;

      // Agar topilmasa, fayl o'lchamidan taxmin qilish
      if (count == 0) {
        final sizeInKB = bytes.length / 1024;
        // Taxminan har 100KB = 1 sahifa
        count = (sizeInKB / 100).ceil();
        if (count < 1) count = 1;
      }

      return count;
    } catch (e) {
      // Xatolik bo'lsa, 1 sahifa deb qaytarish
      return 1;
    }
  }

  /// PDF faylni individual sahifalarga ajratadi
  ///
  /// ⚠️ ESLATMA: To'liq PDF split funksiyasi uchun native PDF library kerak
  /// Hozircha bu funksiya faqat xabar qaytaradi
  static Future<List<String>> splitPdfToPages(File pdfFile) async {
    throw UnsupportedError(
      "PDF split funksiyasi uchun quyidagi package lardan biri kerak:\n"
      "- syncfusion_flutter_pdf (katta, lekin kuchli)\n"
      "- native_pdf_renderer (tezroq)\n"
      "- pdfx (alternatif)\n\n"
      "Hozircha faqat sahifalar sonini ko'rish mumkin.",
    );
  }

  /// PDF dan ma'lum sahifalarni ajratib olish
  static Future<String> extractPages(
    File pdfFile,
    List<int> pageNumbers,
  ) async {
    throw UnsupportedError(
      "PDF extract funksiyasi uchun native PDF library kerak.\n"
      "Pubspec.yaml ga quyidagilardan birini qo'shing:\n"
      "- syncfusion_flutter_pdf: ^27.1.57\n"
      "- native_pdf_renderer: ^6.0.0\n"
      "- pdfx: ^2.6.0",
    );
  }

  /// PDF ni ma'lum oraliqda ajratish
  static Future<String> splitRange(
    File pdfFile,
    int startPage,
    int endPage,
  ) async {
    throw UnsupportedError(
      "PDF range split uchun native PDF library kerak.\n"
      "Bu funksiya ishga tushishi uchun package qo'shing.",
    );
  }
}
