// lib/services/docx_creator_service.dart
// 📄 ODDIY DOCX Creator - Faqat text, title yo'q!

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

class DocxCreatorService {
  /// Create simple DOCX with plain text (NO title, NO fancy formatting)
  Future<File> createSimpleDocx(String text) async {
    print('📄 Creating DOCX...');

    final archive = Archive();

    // Add DOCX structure files
    archive.addFile(_createFile('[Content_Types].xml', _getContentTypesXml()));
    archive.addFile(_createFile('_rels/.rels', _getRelsXml()));
    archive.addFile(
      _createFile('word/_rels/document.xml.rels', _getDocumentRelsXml()),
    );
    archive.addFile(_createFile('word/document.xml', _getDocumentXml(text)));
    archive.addFile(_createFile('word/styles.xml', _getStylesXml()));

    // Encode to ZIP
    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw Exception('Failed to create DOCX');
    }

    // Save to file
    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final fileName =
        'Scan_${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}.docx';
    final file = File('${dir.path}/$fileName');

    await file.writeAsBytes(zipBytes, flush: true);

    print('✅ DOCX created: ${file.path}');
    return file;
  }

  ArchiveFile _createFile(String name, String content) {
    final bytes = utf8.encode(content);
    return ArchiveFile(name, bytes.length, bytes);
  }

  /// Simple document XML - NO title, just text
  String _getDocumentXml(String text) {
    final buffer = StringBuffer();

    buffer.write('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
''');

    // Add text paragraphs (NO title!)
    final paragraphs = text.split('\n');
    for (final para in paragraphs) {
      if (para.trim().isEmpty) {
        buffer.write('    <w:p/>\n');
      } else {
        // Escape XML characters
        final escaped = para
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;')
            .replaceAll('"', '&quot;')
            .replaceAll("'", '&apos;');

        buffer.write('''    <w:p>
      <w:r>
        <w:t xml:space="preserve">$escaped</w:t>
      </w:r>
    </w:p>
''');
      }
    }

    buffer.write('''  </w:body>
</w:document>''');

    return buffer.toString();
  }

  String _getContentTypesXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';
  }

  String _getRelsXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
  }

  String _getDocumentRelsXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';
  }

  String _getStylesXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Arial" w:hAnsi="Arial"/>
        <w:sz w:val="24"/>
      </w:rPr>
    </w:rPrDefault>
    <w:pPrDefault>
      <w:pPr>
        <w:spacing w:after="200" w:line="276" w:lineRule="auto"/>
      </w:pPr>
    </w:pPrDefault>
  </w:docDefaults>
</w:styles>''';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
