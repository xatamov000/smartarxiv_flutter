import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart' as path;
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfSplitService {
  static Future<int> getPageCount(File file) async {
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    final count = document.pages.count;

    document.dispose();
    return count;
  }

  static Future<String> splitPdf({
    required File file,
    required int startPage,
    required int endPage,
    required Directory outputDir,
  }) async {
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    final newDocument = PdfDocument();
    newDocument.pages.removeAt(0);

    for (int i = startPage - 1; i < endPage; i++) {
      final originalPage = document.pages[i];
      final Size pageSize = originalPage.size;

      newDocument.pageSettings.size = pageSize;
      newDocument.pageSettings.margins =
          PdfMargins()
            ..left = 0
            ..top = 0
            ..right = 0
            ..bottom = 0;

      final newPage = newDocument.pages.add();

      newPage.graphics.drawPdfTemplate(
        originalPage.createTemplate(),
        Offset.zero,
        pageSize,
      );
    }

    final outputPath = path.join(
      outputDir.path,
      "split_${DateTime.now().millisecondsSinceEpoch}.pdf",
    );

    final fileBytes = await newDocument.save();

    final newFile = File(outputPath);
    await newFile.writeAsBytes(fileBytes);

    document.dispose();
    newDocument.dispose();

    return outputPath;
  }
}
