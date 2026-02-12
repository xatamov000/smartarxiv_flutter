// lib/services/word_to_pdf_service.dart
// 📄 Word fayllarni PDF ga o'girish xizmati

import 'dart:io';

import 'package:docx_to_text/docx_to_text.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class WordToPdfService {
  /// Word faylni PDF ga konvert qiladi
  ///
  /// [wordFile] - .docx fayl
  /// Returns: Yangi PDF fayl path
  static Future<String> convertToPdf(File wordFile) async {
    try {
      // 1. Word fayldan textni olish
      final bytes = await wordFile.readAsBytes();
      final text = docxToText(bytes);

      if (text.isEmpty) {
        throw Exception("Word faylda matn topilmadi");
      }

      // 2. PDF yaratish
      final pdf = pw.Document();

      // Textni sahifalarga bo'lish (har bir sahifada max 3000 belgi)
      final chunks = _splitTextIntoChunks(text, 3000);

      for (final chunk in chunks) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (context) {
              return pw.Container(
                padding: const pw.EdgeInsets.all(40),
                child: pw.Text(
                  chunk,
                  style: pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                ),
              );
            },
          ),
        );
      }

      // 3. PDF ni saqlash
      final dir = await getApplicationDocumentsDirectory();
      final fileName = path.basenameWithoutExtension(wordFile.path);
      final pdfPath = path.join(
        dir.path,
        '${fileName}_converted_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      final pdfFile = File(pdfPath);
      await pdfFile.writeAsBytes(await pdf.save());

      return pdfPath;
    } catch (e) {
      throw Exception("Word→PDF konvertatsiya xatolik: $e");
    }
  }

  /// Textni chunklarga bo'lish
  static List<String> _splitTextIntoChunks(String text, int chunkSize) {
    final chunks = <String>[];
    int start = 0;

    while (start < text.length) {
      int end = start + chunkSize;

      // Oxirgi chunk bo'lsa
      if (end >= text.length) {
        chunks.add(text.substring(start));
        break;
      }

      // So'zni kesmasligi uchun eng yaqin bo'sh joyni topish
      int lastSpace = text.lastIndexOf(' ', end);
      if (lastSpace > start) {
        end = lastSpace;
      }

      chunks.add(text.substring(start, end));
      start = end;
    }

    return chunks;
  }

  /// Bir nechta Word fayllarni bitta PDF ga birlashtiradi
  static Future<String> mergeWordsToPdf(List<File> wordFiles) async {
    try {
      final pdf = pw.Document();

      for (final wordFile in wordFiles) {
        // Har bir Word fayldan textni olish
        final bytes = await wordFile.readAsBytes();
        final text = docxToText(bytes);

        if (text.isNotEmpty) {
          // Har bir fayl uchun yangi sahifa
          final chunks = _splitTextIntoChunks(text, 3000);

          for (final chunk in chunks) {
            pdf.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                build: (context) {
                  return pw.Container(
                    padding: const pw.EdgeInsets.all(40),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Fayl nomi
                        pw.Text(
                          path.basename(wordFile.path),
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Divider(),
                        pw.SizedBox(height: 10),
                        // Matn
                        pw.Text(
                          chunk,
                          style: pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          }
        }
      }

      // PDF ni saqlash
      final dir = await getApplicationDocumentsDirectory();
      final pdfPath = path.join(
        dir.path,
        'merged_words_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      final pdfFile = File(pdfPath);
      await pdfFile.writeAsBytes(await pdf.save());

      return pdfPath;
    } catch (e) {
      throw Exception("Word birlashtirish xatolik: $e");
    }
  }
}
