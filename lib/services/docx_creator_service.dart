// lib/services/docx_creator_service.dart
// 📄 SMART DOCX CREATOR v6 — TIGHT MARGINS

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

class DocxCreatorService {
  Future<File> createFormattedDocx(String text) async {
    print('📄 Creating SMART FORMATTED DOCX v6...');

    final List<Map<String, String>> blocks = _processText(text);
    print('📊 Pipeline: ${blocks.length} blocks');

    final archive = Archive();
    archive.addFile(_archiveFile('[Content_Types].xml', _contentTypesXml()));
    archive.addFile(_archiveFile('_rels/.rels', _relsXml()));
    archive.addFile(
      _archiveFile('word/_rels/document.xml.rels', _documentRelsXml()),
    );
    archive.addFile(_archiveFile('word/numbering.xml', _numberingXml()));
    archive.addFile(_archiveFile('word/styles.xml', _stylesXml()));
    archive.addFile(
      _archiveFile('word/document.xml', _buildDocumentXml(blocks)),
    );

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) throw Exception('DOCX yaratishda xatolik');

    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final fileName =
        'Scan_${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}.docx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(zipBytes, flush: true);

    print('✅ Smart DOCX: ${file.path}');
    return file;
  }

  Future<File> createSimpleDocx(String text) async {
    return createFormattedDocx(text);
  }

  // ================================================================
  // PIPELINE
  // ================================================================

  List<Map<String, String>> _processText(String text) {
    final rawLines = text.split('\n');

    final cleanLines = <String>[];
    for (final line in rawLines) {
      if (!_isNoiseLine(line)) cleanLines.add(line);
    }

    final blocks = <Map<String, String>>[];
    Map<String, String>? current;

    for (int i = 0; i < cleanLines.length; i++) {
      final line = cleanLines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        if (current != null) {
          blocks.add(current);
          current = null;
        }
        continue;
      }
      if (RegExp(r'^-{2,}\s*Sahifa\s+\d+\s*-{2,}$').hasMatch(trimmed)) continue;

      final type = _classifyLine(trimmed);

      if (type == 'heading') {
        if (current != null) {
          blocks.add(current);
          current = null;
        }
        blocks.add({'type': 'heading', 'text': trimmed});
      } else if (type == 'numbered') {
        if (current != null) blocks.add(current);
        final cleanText = trimmed.replaceFirst(RegExp(r'^\d{1,3}[.\)]\s*'), '');
        current = {'type': 'numbered', 'text': cleanText};
      } else if (type == 'bullet') {
        if (current != null) blocks.add(current);
        final cleanText = trimmed.replaceFirst(RegExp(r'^[-•·*▪►○■]\s*'), '');
        current = {'type': 'bullet', 'text': cleanText};
      } else {
        if (current == null) {
          current = {'type': 'paragraph', 'text': trimmed};
        } else if (current['type'] == 'paragraph') {
          if (_shouldSplitParagraph(current['text']!, trimmed)) {
            blocks.add(current);
            current = {'type': 'paragraph', 'text': trimmed};
          } else {
            current = {
              'type': 'paragraph',
              'text': '${current['text']} $trimmed',
            };
          }
        } else if (current['type'] == 'numbered' ||
            current['type'] == 'bullet') {
          if (_isContinuationLine(current['text'] ?? '', trimmed)) {
            current = {
              'type': current['type']!,
              'text': '${current['text']} $trimmed',
            };
          } else {
            blocks.add(current);
            current = {'type': 'paragraph', 'text': trimmed};
          }
        } else {
          blocks.add(current);
          current = {'type': 'paragraph', 'text': trimmed};
        }
      }
    }
    if (current != null) blocks.add(current);

    return blocks.where((b) => (b['text'] ?? '').trim().length > 2).toList();
  }

  // ================================================================
  // PARAGRAPH SPLIT
  // ================================================================

  bool _shouldSplitParagraph(String prevText, String currentLine) {
    final prev = prevText.trim();
    final curr = currentLine.trim();
    if (prev.isEmpty || curr.isEmpty) return false;
    if (prev.length < 200) return false;
    final lastChar = prev[prev.length - 1];
    if (lastChar != '.' && lastChar != '?' && lastChar != '!') return false;
    final firstChar = curr[0];
    if (firstChar == firstChar.toUpperCase() &&
        firstChar != firstChar.toLowerCase()) {
      return true;
    }
    return false;
  }

  // ================================================================
  // NOISE FILTER
  // ================================================================

  bool _isNoiseLine(String line) {
    final t = line.trim();
    if (t.isEmpty) return false;
    if (t.length <= 3 && RegExp(r'^[\d\s.,;:()]+$').hasMatch(t)) return true;
    if (RegExp(r'^\d{1,2}:\d{2}\s*[\(\)♡⊙☆\s]*$').hasMatch(t)) return true;
    if (t.contains('chrome-native://') || t.contains('chrome://')) return true;
    if (RegExp(r'[45]G[\+]?\s*[.:]*\s*[iIlL|\d]').hasMatch(t) && t.length < 25)
      return true;
    if (RegExp(r'KB/[sS]', caseSensitive: false).hasMatch(t) && t.length < 20)
      return true;
    if (RegExp(r'^D?KB[/I]?[sS]', caseSensitive: false).hasMatch(t))
      return true;
    if (RegExp(r'^\s*[\(\s]*\d{1,3}\s*%\s*\)?\s*$').hasMatch(t)) return true;
    if (RegExp(r'^\s*\d{1,3}\s*$').hasMatch(t)) return true;
    if (RegExp(r'^\s*<?\s*\d{1,4}\s*/\s*\d{1,4}\s*>?\s*$').hasMatch(t))
      return true;
    if (RegExp(r'^\s*\d{1,2}[,.]\d{0,3}\s*$').hasMatch(t)) return true;
    if (t == '0') return true;
    if (RegExp(r'Scan[_\s]?\d{8}[_\s]?\d{4,6}').hasMatch(t)) return true;
    if (RegExp(r'^\s*[\(\)\s♡⊙☆<>]+\s*$').hasMatch(t)) return true;
    if (t.length < 5 && !RegExp(r'[a-zA-Zа-яА-ЯўқғҳЎҚҒҲ]').hasMatch(t))
      return true;
    if (RegExp(r'Kes\s+[45]G').hasMatch(t)) return true;
    const ui = <String>{
      'Ulashish',
      'Tahrirlash',
      "O'chirish",
      'Yana',
      'Bos',
      'Documents',
      'Merge',
      'Scan',
      'Profile',
      'Compress',
      'Yopish',
      'Drive',
      'Ochish',
      'Orqaga',
      'Super hujjatlar >',
      'Super hujjatlar',
      'PDF ni ochish',
      'PDF Split',
      'Split PDF',
    };
    if (ui.contains(t)) return true;
    if (t.contains('OVERFLOWED BY')) return true;
    if (RegExp(r'^(Img\s*-+\s*PDF|Word\s+PDF|PDF)$').hasMatch(t)) return true;
    return false;
  }

  // ================================================================
  // CLASSIFICATION
  // ================================================================

  String _classifyLine(String line) {
    final t = line.trim();
    if (t.isEmpty) return 'empty';
    if (RegExp(r'^\d{1,3}[.\)]\s+\S').hasMatch(t)) return 'numbered';
    if (RegExp(r'^[-•·*▪►○■]\s+\S').hasMatch(t)) return 'bullet';
    if (_isHeading(t)) return 'heading';
    return 'paragraph';
  }

  bool _isHeading(String text) {
    final t = text.trim();
    if (t.length > 100 || t.length < 5) return false;
    if (RegExp(r'^\d+-\s*ma.?ruza\s+uchun', caseSensitive: false).hasMatch(t))
      return true;
    if (RegExp(
      r'(^\d+[-.\s]*mavzu|mavzu\s*\d+)',
      caseSensitive: false,
    ).hasMatch(t))
      return true;
    if (RegExp(
          r'^(Bob|Paragraf|Bo.?lim|Kirish|Xulosa|Mundarija)\s',
          caseSensitive: false,
        ).hasMatch(t) &&
        t.length <= 80)
      return true;
    int lc = 0, uc = 0;
    for (int i = 0; i < t.length; i++) {
      final c = t[i];
      if (c.toUpperCase() != c.toLowerCase()) {
        lc++;
        if (c == c.toUpperCase()) uc++;
      }
    }
    if (lc >= 8 && uc / lc >= 0.7 && t.length <= 40) return true;
    if (t.endsWith(':') && t.split(' ').length >= 2 && t.length <= 60)
      return true;
    return false;
  }

  bool _isContinuationLine(String prev, String curr) {
    final ct = curr.trim();
    if (ct.isEmpty) return false;
    final pt = prev.trim();
    if (pt.isNotEmpty && '.?!'.contains(pt[pt.length - 1])) return false;
    final fc = ct[0];
    if (fc == fc.toLowerCase() && fc != fc.toUpperCase()) return true;
    if (pt.isNotEmpty && !'.?!:'.contains(pt[pt.length - 1])) return true;
    return false;
  }

  // ================================================================
  // DOCX XML — TIGHT MARGINS
  // ================================================================

  String _buildDocumentXml(List<Map<String, String>> blocks) {
    final buf = StringBuffer();
    buf.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    buf.write(
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"',
    );
    buf.write(
      ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\n',
    );
    buf.write('  <w:body>\n');

    for (final block in blocks) {
      final type = block['type'] ?? 'paragraph';
      final escaped = _escXml(block['text'] ?? '');
      switch (type) {
        case 'heading':
          buf.write(_headingXml(escaped));
          break;
        case 'numbered':
          buf.write(_numberedXml(escaped));
          break;
        case 'bullet':
          buf.write(_bulletXml(escaped));
          break;
        default:
          buf.write(_paragraphXml(escaped));
          break;
      }
    }

    // A4: left/right 1cm, top/bottom 2cm
    buf.write('    <w:sectPr>\n');
    buf.write('      <w:pgSz w:w="11906" w:h="16838" w:orient="portrait"/>\n');
    buf.write(
      '      <w:pgMar w:top="1134" w:right="567" w:bottom="1134" w:left="567"',
    );
    buf.write(' w:header="709" w:footer="709" w:gutter="0"/>\n');
    buf.write('    </w:sectPr>\n');
    buf.write('  </w:body>\n</w:document>');
    return buf.toString();
  }

  // Heading: Bold, 14pt
  String _headingXml(String text) => '''    <w:p>
      <w:pPr>
        <w:pStyle w:val="Heading1"/>
        <w:spacing w:before="240" w:after="120"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman" w:eastAsia="Times New Roman"/>
          <w:b/><w:bCs/>
          <w:sz w:val="28"/><w:szCs w:val="28"/>
        </w:rPr>
        <w:t xml:space="preserve">$text</w:t>
      </w:r>
    </w:p>
''';

  // Numbered list: tight indent
  String _numberedXml(String text) => '''    <w:p>
      <w:pPr>
        <w:pStyle w:val="ListNumber"/>
        <w:numPr><w:ilvl w:val="0"/><w:numId w:val="2"/></w:numPr>
        <w:spacing w:after="60" w:line="276" w:lineRule="auto"/>
        <w:ind w:left="340" w:hanging="340"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman" w:eastAsia="Times New Roman"/>
          <w:sz w:val="24"/><w:szCs w:val="24"/>
        </w:rPr>
        <w:t xml:space="preserve">$text</w:t>
      </w:r>
    </w:p>
''';

  // Bullet list: tight indent
  String _bulletXml(String text) => '''    <w:p>
      <w:pPr>
        <w:pStyle w:val="ListBullet"/>
        <w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr>
        <w:spacing w:after="60" w:line="276" w:lineRule="auto"/>
        <w:ind w:left="340" w:hanging="340"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman" w:eastAsia="Times New Roman"/>
          <w:sz w:val="24"/><w:szCs w:val="24"/>
        </w:rPr>
        <w:t xml:space="preserve">$text</w:t>
      </w:r>
    </w:p>
''';

  // Paragraph: 12pt, 1.5 spacing, small indent, justified
  String _paragraphXml(String text) => '''    <w:p>
      <w:pPr>
        <w:spacing w:after="120" w:line="360" w:lineRule="auto"/>
        <w:ind w:firstLine="400"/>
        <w:jc w:val="both"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman" w:eastAsia="Times New Roman"/>
          <w:sz w:val="24"/><w:szCs w:val="24"/>
        </w:rPr>
        <w:t xml:space="preserve">$text</w:t>
      </w:r>
    </w:p>
''';

  // ================================================================
  // DOCX STRUCTURE FILES
  // ================================================================

  String _numberingXml() =>
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:abstractNum w:abstractNumId="0">
    <w:lvl w:ilvl="0">
      <w:start w:val="1"/><w:numFmt w:val="bullet"/>
      <w:lvlText w:val="\u2022"/><w:lvlJc w:val="left"/>
      <w:pPr><w:ind w:left="340" w:hanging="340"/></w:pPr>
      <w:rPr><w:rFonts w:ascii="Symbol" w:hAnsi="Symbol" w:hint="default"/></w:rPr>
    </w:lvl>
  </w:abstractNum>
  <w:abstractNum w:abstractNumId="1">
    <w:lvl w:ilvl="0">
      <w:start w:val="1"/><w:numFmt w:val="decimal"/>
      <w:lvlText w:val="%1."/><w:lvlJc w:val="left"/>
      <w:pPr><w:ind w:left="340" w:hanging="340"/></w:pPr>
      <w:rPr><w:rFonts w:hint="default"/></w:rPr>
    </w:lvl>
  </w:abstractNum>
  <w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>
  <w:num w:numId="2"><w:abstractNumId w:val="1"/></w:num>
</w:numbering>''';

  String _stylesXml() =>
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault><w:rPr>
      <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:eastAsia="Times New Roman" w:cs="Times New Roman"/>
      <w:sz w:val="24"/><w:szCs w:val="24"/>
      <w:lang w:val="uz-UZ" w:eastAsia="en-US" w:bidi="ar-SA"/>
    </w:rPr></w:rPrDefault>
    <w:pPrDefault><w:pPr>
      <w:spacing w:after="120" w:line="360" w:lineRule="auto"/>
    </w:pPr></w:pPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/><w:qFormat/>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:qFormat/>
    <w:pPr><w:keepNext/><w:spacing w:before="240" w:after="120"/></w:pPr>
    <w:rPr><w:b/><w:bCs/><w:sz w:val="28"/><w:szCs w:val="28"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="ListBullet">
    <w:name w:val="List Bullet"/><w:basedOn w:val="Normal"/>
    <w:pPr><w:spacing w:after="60"/></w:pPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="ListNumber">
    <w:name w:val="List Number"/><w:basedOn w:val="Normal"/>
    <w:pPr><w:spacing w:after="60"/></w:pPr>
  </w:style>
</w:styles>''';

  String _contentTypesXml() =>
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>
</Types>''';

  String _relsXml() =>
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

  String _documentRelsXml() =>
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>
</Relationships>''';

  ArchiveFile _archiveFile(String name, String content) {
    final bytes = utf8.encode(content);
    return ArchiveFile(name, bytes.length, bytes);
  }

  String _escXml(String t) => t
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  String _pad(int n) => n.toString().padLeft(2, '0');
}
