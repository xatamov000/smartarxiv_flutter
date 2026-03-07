// lib/services/word_to_pdf_service.dart
// 🔥 YUQORI SIFATLI Word (DOCX) → PDF konvertatsiya
// ✅ Roboto TTF font + To'g'ri ro'yxat raqamlash + UTF-8
// Packages: archive, xml, pdf, path_provider, flutter/services

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';

class WordToPdfService {
  // ============================================================
  // FONT CACHE
  // ============================================================
  static pw.Font? _regular;
  static pw.Font? _bold;
  static pw.Font? _italic;
  static pw.Font? _boldItalic;

  static Future<_Fonts> _loadFonts() async {
    try {
      _regular ??= pw.Font.ttf(
        await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
      );
      _bold ??= pw.Font.ttf(
        await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
      );

      if (_italic == null) {
        try {
          _italic = pw.Font.ttf(
            await rootBundle.load('assets/fonts/Roboto-Italic.ttf'),
          );
        } catch (_) {
          _italic = pw.Font.ttf(
            await rootBundle.load('assets/fonts/Roboto-Medium.ttf'),
          );
        }
      }

      if (_boldItalic == null) {
        try {
          _boldItalic = pw.Font.ttf(
            await rootBundle.load('assets/fonts/Roboto-BoldItalic.ttf'),
          );
        } catch (_) {
          _boldItalic = _bold;
        }
      }

      return _Fonts(
        regular: _regular!,
        bold: _bold!,
        italic: _italic!,
        boldItalic: _boldItalic!,
      );
    } catch (e) {
      print('⚠️ TTF font yuklanmadi, Helvetica fallback: $e');
      return _Fonts(
        regular: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
        boldItalic: pw.Font.helveticaBoldOblique(),
      );
    }
  }

  // ============================================================
  // MAIN CONVERT
  // ============================================================

  static Future<String> convertToPdf(File wordFile) async {
    final bytes = await wordFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final docXml = _fileContent(archive, 'word/document.xml');
    if (docXml == null) throw Exception("document.xml topilmadi");

    final stylesXml = _fileContent(archive, 'word/styles.xml');
    final relsXml = _fileContent(archive, 'word/_rels/document.xml.rels');
    final numberingXml = _fileContent(archive, 'word/numbering.xml');

    final images = _extractImages(archive);
    final rels = _parseRelationships(relsXml);
    final styles = _parseStyles(stylesXml);

    // 🔥 Ro'yxat formatlari va counter
    final listDefs = _parseNumbering(numberingXml);
    final listCounters = <String, int>{}; // "numId-ilvl" -> counter

    final doc = XmlDocument.parse(docXml);
    final body = doc.findAllElements('w:body').firstOrNull;
    if (body == null) throw Exception("w:body topilmadi");

    final fonts = await _loadFonts();
    final widgets = <pw.Widget>[];

    for (final node in body.children) {
      if (node is! XmlElement) continue;
      final tag = node.name.local;

      if (tag == 'p') {
        final w = _buildParagraph(
          node,
          fonts,
          styles,
          images,
          rels,
          listDefs,
          listCounters,
        );
        if (w != null) widgets.add(w);
      } else if (tag == 'tbl') {
        final w = _buildTable(node, fonts, styles);
        if (w != null) widgets.add(w);
      }
    }

    final pdf = pw.Document();

    if (widgets.isEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build:
              (_) => pw.Center(
                child: pw.Text(
                  "Bo'sh dokument",
                  style: pw.TextStyle(font: fonts.regular, fontSize: 14),
                ),
              ),
        ),
      );
    } else {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 50, vertical: 45),
          footer:
              (ctx) => pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  '${ctx.pageNumber} / ${ctx.pagesCount}',
                  style: pw.TextStyle(
                    font: fonts.regular,
                    fontSize: 8,
                    color: PdfColors.grey,
                  ),
                ),
              ),
          build: (_) => widgets,
        ),
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final name = p.basenameWithoutExtension(wordFile.path);
    final outPath = p.join(
      dir.path,
      '${name}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await File(outPath).writeAsBytes(await pdf.save());

    return outPath;
  }

  // ============================================================
  // NUMBERING.XML PARSER — Ro'yxat formatlarini olish
  // ============================================================

  static Map<String, _ListDef> _parseNumbering(String? xml) {
    // Qaytaradi: "numId-ilvl" -> _ListDef
    final result = <String, _ListDef>{};
    if (xml == null) return result;

    try {
      final doc = XmlDocument.parse(xml);

      // 1. abstractNum larni olish: abstractNumId -> levels
      final abstractMap = <String, Map<String, _ListDef>>{};

      for (final abs in doc.findAllElements('w:abstractNum')) {
        final absId = abs.getAttribute('w:abstractNumId');
        if (absId == null) continue;

        final levels = <String, _ListDef>{};

        for (final lvl in abs.findAllElements('w:lvl')) {
          final ilvl = lvl.getAttribute('w:ilvl') ?? '0';
          final numFmt =
              lvl.getElement('w:numFmt')?.getAttribute('w:val') ?? 'decimal';
          final lvlText =
              lvl.getElement('w:lvlText')?.getAttribute('w:val') ?? '%1.';
          final startVal =
              int.tryParse(
                lvl.getElement('w:start')?.getAttribute('w:val') ?? '1',
              ) ??
              1;

          levels[ilvl] = _ListDef(
            format: numFmt,
            textPattern: lvlText,
            startValue: startVal,
          );
        }

        abstractMap[absId] = levels;
      }

      // 2. w:num -> abstractNumId mapping
      for (final num in doc.findAllElements('w:num')) {
        final numId = num.getAttribute('w:numId');
        final absRef = num.getElement('w:abstractNumId')?.getAttribute('w:val');

        if (numId == null || absRef == null) continue;
        if (!abstractMap.containsKey(absRef)) continue;

        final levels = abstractMap[absRef]!;
        for (final entry in levels.entries) {
          result['$numId-${entry.key}'] = entry.value;
        }
      }
    } catch (_) {}

    return result;
  }

  // ============================================================
  // PARAGRAPH BUILDER
  // ============================================================

  static pw.Widget? _buildParagraph(
    XmlElement para,
    _Fonts fonts,
    Map<String, _Style> styles,
    Map<String, Uint8List> images,
    Map<String, String> rels,
    Map<String, _ListDef> listDefs,
    Map<String, int> listCounters,
  ) {
    final pPr = para.getElement('w:pPr');

    double fontSize = 12;
    bool pBold = false;
    bool pItalic = false;
    pw.TextAlign align = pw.TextAlign.left;
    double spaceBefore = 0;
    double spaceAfter = 4;
    double leftIndent = 0;
    double firstLineIndent = 0;

    // Ro'yxat ma'lumotlari
    bool isList = false;
    String listPrefix = '';
    double listIndent = 0;

    if (pPr != null) {
      final styleId = pPr.getElement('w:pStyle')?.getAttribute('w:val');
      if (styleId != null && styles.containsKey(styleId)) {
        final s = styles[styleId]!;
        if (s.fontSize != null) fontSize = s.fontSize!;
        pBold = s.bold;
        pItalic = s.italic;
      }

      // Heading detection
      if (styleId != null) {
        final lower = styleId.toLowerCase();
        if (lower.contains('heading1') || lower == 'title') {
          fontSize = 22;
          pBold = true;
          spaceBefore = 14;
          spaceAfter = 8;
        } else if (lower.contains('heading2') || lower.contains('subtitle')) {
          fontSize = 18;
          pBold = true;
          spaceBefore = 12;
          spaceAfter = 6;
        } else if (lower.contains('heading3')) {
          fontSize = 15;
          pBold = true;
          spaceBefore = 10;
          spaceAfter = 4;
        } else if (lower.contains('heading4')) {
          fontSize = 13;
          pBold = true;
          spaceBefore = 8;
          spaceAfter = 3;
        } else if (lower.contains('heading5') || lower.contains('heading6')) {
          fontSize = 12;
          pBold = true;
          spaceBefore = 6;
          spaceAfter = 2;
        }
      }

      // Alignment
      final jc = pPr.getElement('w:jc')?.getAttribute('w:val');
      if (jc != null) {
        switch (jc) {
          case 'center':
            align = pw.TextAlign.center;
            break;
          case 'right':
          case 'end':
            align = pw.TextAlign.right;
            break;
          case 'both':
          case 'justify':
            align = pw.TextAlign.justify;
            break;
        }
      }

      // Spacing
      final spacing = pPr.getElement('w:spacing');
      if (spacing != null) {
        final bef = spacing.getAttribute('w:before');
        final aft = spacing.getAttribute('w:after');
        if (bef != null) spaceBefore = (double.tryParse(bef) ?? 0) / 20;
        if (aft != null) spaceAfter = (double.tryParse(aft) ?? 80) / 20;
      }

      // Indent
      final ind = pPr.getElement('w:ind');
      if (ind != null) {
        final left = ind.getAttribute('w:left') ?? ind.getAttribute('w:start');
        if (left != null) leftIndent = (double.tryParse(left) ?? 0) / 20;

        final firstLine = ind.getAttribute('w:firstLine');
        if (firstLine != null) {
          firstLineIndent = (double.tryParse(firstLine) ?? 0) / 20;
        }
      }

      // 🔥 RO'YXAT — numPr parsing
      final numPr = pPr.getElement('w:numPr');
      if (numPr != null) {
        final numIdStr =
            numPr.getElement('w:numId')?.getAttribute('w:val') ?? '0';
        final ilvlStr =
            numPr.getElement('w:ilvl')?.getAttribute('w:val') ?? '0';
        final numId = int.tryParse(numIdStr) ?? 0;
        final ilvl = int.tryParse(ilvlStr) ?? 0;

        // 🔥 numId=0 = ro'yxat EMAS (oddiy indent qoladi)
        if (numId > 0) {
          isList = true;
          final defKey = '$numIdStr-$ilvlStr';
          final counterKey = '$numIdStr-$ilvlStr';

          // Counter ni oshirish
          listCounters[counterKey] = (listCounters[counterKey] ?? 0) + 1;

          // Ro'yxat formati
          if (listDefs.containsKey(defKey)) {
            final def = listDefs[defKey]!;
            final counter = listCounters[counterKey]!;
            final actualNum = def.startValue + counter - 1;

            // Format bo'yicha prefix yaratish
            listPrefix = _formatListNumber(
              def.format,
              def.textPattern,
              actualNum,
            );
          } else {
            // Default: raqamli ro'yxat
            final counter = listCounters[counterKey]!;
            listPrefix = '$counter.';
          }

          listIndent = 15.0 + (ilvl * 18.0);
        }
        // numId=0 bo'lsa — leftIndent saqlanadi, lekin ro'yxat belgi qo'shilmaydi
      }
    }

    // --- Run larni parse qilish ---
    final spans = <pw.InlineSpan>[];
    final inlineImages = <pw.Widget>[];
    bool hasText = false;

    for (final child in para.children) {
      if (child is! XmlElement) continue;
      final tag = child.name.local;

      if (tag == 'r') {
        _parseRun(
          child,
          spans,
          inlineImages,
          fonts,
          images,
          rels,
          baseFontSize: fontSize,
          baseBold: pBold,
          baseItalic: pItalic,
        );
        if (spans.isNotEmpty) hasText = true;
      } else if (tag == 'hyperlink') {
        for (final hChild in child.children) {
          if (hChild is XmlElement && hChild.name.local == 'r') {
            _parseRun(
              hChild,
              spans,
              inlineImages,
              fonts,
              images,
              rels,
              baseFontSize: fontSize,
              baseBold: pBold,
              baseItalic: pItalic,
              isHyperlink: true,
            );
            if (spans.isNotEmpty) hasText = true;
          }
        }
      }
    }

    // Bo'sh paragraf
    if (!hasText && inlineImages.isEmpty) {
      return pw.SizedBox(height: fontSize * 0.6);
    }

    // FirstLine indent — faqat chapga/justify tekislangan matn uchun
    if (firstLineIndent > 0 &&
        spans.isNotEmpty &&
        !isList &&
        align != pw.TextAlign.center &&
        align != pw.TextAlign.right) {
      final indentSpaces = ' ' * (firstLineIndent ~/ 3).clamp(1, 20);
      spans.insert(
        0,
        pw.TextSpan(
          text: indentSpaces,
          style: pw.TextStyle(font: fonts.regular, fontSize: fontSize),
        ),
      );
    }

    // Text widget
    pw.Widget content;

    if (inlineImages.isNotEmpty && spans.isEmpty) {
      content = pw.Column(children: inlineImages);
    } else if (inlineImages.isNotEmpty) {
      content = pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.RichText(text: pw.TextSpan(children: spans), textAlign: align),
          ...inlineImages,
        ],
      );
    } else {
      content = pw.RichText(
        text: pw.TextSpan(children: spans),
        textAlign: align,
      );
    }

    // 🔥 Ro'yxat yoki oddiy indent qo'llash
    if (isList) {
      content = pw.Padding(
        padding: pw.EdgeInsets.only(left: listIndent),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 25,
              child: pw.Text(
                listPrefix,
                style: pw.TextStyle(font: fonts.regular, fontSize: fontSize),
              ),
            ),
            pw.Expanded(child: content),
          ],
        ),
      );
    } else if (leftIndent > 0 &&
        align != pw.TextAlign.center &&
        align != pw.TextAlign.right) {
      content = pw.Padding(
        padding: pw.EdgeInsets.only(left: leftIndent),
        child: content,
      );
    }

    return pw.Padding(
      padding: pw.EdgeInsets.only(top: spaceBefore, bottom: spaceAfter),
      child: content,
    );
  }

  // ============================================================
  // LIST NUMBER FORMATTER
  // ============================================================

  static String _formatListNumber(String format, String pattern, int number) {
    String numStr;

    switch (format) {
      case 'decimal':
        numStr = '$number';
        break;
      case 'lowerLetter':
        numStr = String.fromCharCode(96 + (number > 0 ? number : 1)); // a, b, c
        break;
      case 'upperLetter':
        numStr = String.fromCharCode(64 + (number > 0 ? number : 1)); // A, B, C
        break;
      case 'lowerRoman':
        numStr = _toRoman(number).toLowerCase(); // i, ii, iii
        break;
      case 'upperRoman':
        numStr = _toRoman(number); // I, II, III
        break;
      case 'bullet':
        return '-'; // Bullet ro'yxat
      case 'none':
        return '';
      default:
        numStr = '$number';
    }

    // Pattern qo'llash: "%1." -> "1.", "%1)" -> "1)"
    String result = pattern.replaceAll('%1', numStr);
    result = result.replaceAll('%2', numStr);
    result = result.replaceAll('%3', numStr);

    return result;
  }

  static String _toRoman(int number) {
    if (number <= 0 || number > 3999) return '$number';
    const romanNumerals = {
      1000: 'M',
      900: 'CM',
      500: 'D',
      400: 'CD',
      100: 'C',
      90: 'XC',
      50: 'L',
      40: 'XL',
      10: 'X',
      9: 'IX',
      5: 'V',
      4: 'IV',
      1: 'I',
    };
    var result = '';
    var remaining = number;
    for (final entry in romanNumerals.entries) {
      while (remaining >= entry.key) {
        result += entry.value;
        remaining -= entry.key;
      }
    }
    return result;
  }

  // ============================================================
  // RUN PARSER
  // ============================================================

  static void _parseRun(
    XmlElement run,
    List<pw.InlineSpan> spans,
    List<pw.Widget> inlineImages,
    _Fonts fonts,
    Map<String, Uint8List> images,
    Map<String, String> rels, {
    required double baseFontSize,
    required bool baseBold,
    required bool baseItalic,
    bool isHyperlink = false,
  }) {
    final rPr = run.getElement('w:rPr');

    double fontSize = baseFontSize;
    bool bold = baseBold;
    bool italic = baseItalic;
    bool underline = isHyperlink;
    bool strike = false;
    bool superscript = false;
    bool subscript = false;
    PdfColor color = isHyperlink ? PdfColors.blue800 : PdfColors.black;
    PdfColor? bgColor;

    if (rPr != null) {
      final sz = rPr.getElement('w:sz') ?? rPr.getElement('w:szCs');
      if (sz != null) {
        final val = sz.getAttribute('w:val');
        if (val != null)
          fontSize = (double.tryParse(val) ?? baseFontSize * 2) / 2;
      }

      final bEl = rPr.getElement('w:b') ?? rPr.getElement('w:bCs');
      if (bEl != null) {
        final v = bEl.getAttribute('w:val');
        bold = v != 'false' && v != '0';
      }

      final iEl = rPr.getElement('w:i') ?? rPr.getElement('w:iCs');
      if (iEl != null) {
        final v = iEl.getAttribute('w:val');
        italic = v != 'false' && v != '0';
      }

      final uEl = rPr.getElement('w:u');
      if (uEl != null) {
        final v = uEl.getAttribute('w:val');
        underline = v != null && v != 'none';
      }

      if (rPr.getElement('w:strike') != null ||
          rPr.getElement('w:dstrike') != null) {
        strike = true;
      }

      final cEl = rPr.getElement('w:color');
      if (cEl != null) {
        final v = cEl.getAttribute('w:val');
        if (v != null && v != 'auto') color = _hexColor(v);
      }

      final hlEl = rPr.getElement('w:highlight');
      if (hlEl != null) {
        final v = hlEl.getAttribute('w:val');
        if (v != null) bgColor = _namedColor(v);
      }

      final vertAlign = rPr.getElement('w:vertAlign');
      if (vertAlign != null) {
        final v = vertAlign.getAttribute('w:val');
        if (v == 'superscript') superscript = true;
        if (v == 'subscript') subscript = true;
      }
    }

    pw.Font currentFont;
    if (bold && italic) {
      currentFont = fonts.boldItalic;
    } else if (bold) {
      currentFont = fonts.bold;
    } else if (italic) {
      currentFont = fonts.italic;
    } else {
      currentFont = fonts.regular;
    }

    if (superscript || subscript) fontSize = fontSize * 0.65;

    pw.TextDecoration? decoration;
    if (underline && strike) {
      decoration = pw.TextDecoration.combine([
        pw.TextDecoration.underline,
        pw.TextDecoration.lineThrough,
      ]);
    } else if (underline) {
      decoration = pw.TextDecoration.underline;
    } else if (strike) {
      decoration = pw.TextDecoration.lineThrough;
    }

    final style = pw.TextStyle(
      font: currentFont,
      fontSize: fontSize,
      color: color,
      decoration: decoration,
      background: bgColor != null ? pw.BoxDecoration(color: bgColor) : null,
    );

    for (final child in run.children) {
      if (child is! XmlElement) continue;
      final tag = child.name.local;

      if (tag == 't') {
        final text = child.innerText;
        if (text.isNotEmpty) {
          spans.add(pw.TextSpan(text: text, style: style));
        }
      } else if (tag == 'tab') {
        spans.add(pw.TextSpan(text: '        ', style: style));
      } else if (tag == 'br') {
        spans.add(pw.TextSpan(text: '\n', style: style));
      } else if (tag == 'drawing' || tag == 'pict') {
        final blips = child.findAllElements('a:blip');
        for (final blip in blips) {
          final rId = blip.getAttribute('r:embed');
          if (rId != null && rels.containsKey(rId)) {
            final target = rels[rId]!;
            final imgPath =
                target.startsWith('/') ? 'word$target' : 'word/$target';

            if (images.containsKey(imgPath)) {
              try {
                final imgBytes = images[imgPath]!;
                final image = pw.MemoryImage(imgBytes);

                double imgWidth = 400;
                final extents = child.findAllElements('wp:extent');
                if (extents.isNotEmpty) {
                  final cx = extents.first.getAttribute('cx');
                  if (cx != null) {
                    imgWidth = (double.tryParse(cx) ?? 5000000) / 12700;
                    if (imgWidth > 450) imgWidth = 450;
                    if (imgWidth < 50) imgWidth = 200;
                  }
                }

                inlineImages.add(
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 6),
                    child: pw.Center(
                      child: pw.Image(
                        image,
                        width: imgWidth,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ),
                );
              } catch (_) {}
            }
          }
        }
      }
    }
  }

  // ============================================================
  // TABLE BUILDER
  // ============================================================

  static pw.Widget? _buildTable(
    XmlElement table,
    _Fonts fonts,
    Map<String, _Style> styles,
  ) {
    try {
      final rows = table.findAllElements('w:tr').toList();
      if (rows.isEmpty) return null;

      PdfColor borderColor = PdfColors.grey600;
      double borderWidth = 0.5;

      final tblPr = table.getElement('w:tblPr');
      if (tblPr != null) {
        final borders = tblPr.getElement('w:tblBorders');
        if (borders != null) {
          final top = borders.getElement('w:top');
          if (top != null) {
            final colorAttr = top.getAttribute('w:color');
            if (colorAttr != null && colorAttr != 'auto')
              borderColor = _hexColor(colorAttr);
            final sz = top.getAttribute('w:sz');
            if (sz != null) borderWidth = (double.tryParse(sz) ?? 4) / 8;
          }
        }
      }

      int maxCols = 0;
      for (final row in rows) {
        final cells = row.findAllElements('w:tc').length;
        if (cells > maxCols) maxCols = cells;
      }

      final tableRows = <pw.TableRow>[];

      for (final row in rows) {
        final cells = row.findAllElements('w:tc').toList();
        final cellWidgets = <pw.Widget>[];

        for (final cell in cells) {
          PdfColor? cellBg;
          final tcPr = cell.getElement('w:tcPr');
          if (tcPr != null) {
            final shd = tcPr.getElement('w:shd');
            if (shd != null) {
              final fill = shd.getAttribute('w:fill');
              if (fill != null && fill != 'auto' && fill != 'FFFFFF') {
                cellBg = _hexColor(fill);
              }
            }
          }

          final cellContent = <pw.Widget>[];
          final paragraphs = cell.findAllElements('w:p');

          for (final pg in paragraphs) {
            final cellRuns = pg.findAllElements('w:r');
            final spans = <pw.InlineSpan>[];
            double cellFontSize = 10;
            PdfColor cellColor = PdfColors.black;

            for (final r in cellRuns) {
              final rPr = r.getElement('w:rPr');
              bool cellBold = false;
              bool cellItalic = false;
              pw.Font cellFont = fonts.regular;

              if (rPr != null) {
                final sz = rPr.getElement('w:sz');
                if (sz != null) {
                  final v = sz.getAttribute('w:val');
                  if (v != null) cellFontSize = (double.tryParse(v) ?? 20) / 2;
                }
                final bEl = rPr.getElement('w:b');
                if (bEl != null) {
                  final v = bEl.getAttribute('w:val');
                  cellBold = v != 'false' && v != '0';
                }
                final iEl = rPr.getElement('w:i');
                if (iEl != null) {
                  final v = iEl.getAttribute('w:val');
                  cellItalic = v != 'false' && v != '0';
                }
                final cEl = rPr.getElement('w:color');
                if (cEl != null) {
                  final v = cEl.getAttribute('w:val');
                  if (v != null && v != 'auto') cellColor = _hexColor(v);
                }
              }

              if (cellBold && cellItalic) {
                cellFont = fonts.boldItalic;
              } else if (cellBold) {
                cellFont = fonts.bold;
              } else if (cellItalic) {
                cellFont = fonts.italic;
              }

              for (final t in r.findAllElements('w:t')) {
                spans.add(
                  pw.TextSpan(
                    text: t.innerText,
                    style: pw.TextStyle(
                      font: cellFont,
                      fontSize: cellFontSize,
                      color: cellColor,
                    ),
                  ),
                );
              }
            }

            if (spans.isNotEmpty) {
              final pPr = pg.getElement('w:pPr');
              final jc = pPr?.getElement('w:jc')?.getAttribute('w:val');
              pw.TextAlign cellAlign = pw.TextAlign.left;
              if (jc == 'center') cellAlign = pw.TextAlign.center;
              if (jc == 'right' || jc == 'end') cellAlign = pw.TextAlign.right;

              cellContent.add(
                pw.RichText(
                  text: pw.TextSpan(children: spans),
                  textAlign: cellAlign,
                ),
              );
            }
          }

          cellWidgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(5),
              color: cellBg,
              child:
                  cellContent.isEmpty
                      ? pw.Text('')
                      : pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: cellContent,
                      ),
            ),
          );
        }

        while (cellWidgets.length < maxCols) {
          cellWidgets.add(pw.Container(padding: const pw.EdgeInsets.all(5)));
        }

        tableRows.add(pw.TableRow(children: cellWidgets));
      }

      if (tableRows.isEmpty) return null;

      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8),
        child: pw.Table(
          border: pw.TableBorder.all(color: borderColor, width: borderWidth),
          children: tableRows,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // DOCX EXTRACTION HELPERS
  // ============================================================

  static String? _fileContent(Archive archive, String path) {
    for (final file in archive) {
      if (file.name == path && file.isFile) {
        final bytes = file.content as List<int>;
        return utf8.decode(bytes, allowMalformed: true);
      }
    }
    return null;
  }

  static Map<String, Uint8List> _extractImages(Archive archive) {
    final map = <String, Uint8List>{};
    for (final file in archive) {
      if (file.name.startsWith('word/media/') && file.isFile) {
        map[file.name] = Uint8List.fromList(file.content as List<int>);
      }
    }
    return map;
  }

  static Map<String, String> _parseRelationships(String? xml) {
    final map = <String, String>{};
    if (xml == null) return map;
    try {
      final doc = XmlDocument.parse(xml);
      for (final rel in doc.findAllElements('Relationship')) {
        final id = rel.getAttribute('Id');
        final target = rel.getAttribute('Target');
        if (id != null && target != null) map[id] = target;
      }
    } catch (_) {}
    return map;
  }

  static Map<String, _Style> _parseStyles(String? xml) {
    final map = <String, _Style>{};
    if (xml == null) return map;
    try {
      final doc = XmlDocument.parse(xml);
      for (final style in doc.findAllElements('w:style')) {
        final id = style.getAttribute('w:styleId');
        if (id == null) continue;

        double? fontSize;
        bool bold = false;
        bool italic = false;
        PdfColor? color;

        final rPr = style.getElement('w:rPr');
        if (rPr != null) {
          final sz = rPr.getElement('w:sz');
          if (sz != null) {
            final v = sz.getAttribute('w:val');
            if (v != null) fontSize = (double.tryParse(v) ?? 24) / 2;
          }
          final bEl = rPr.getElement('w:b');
          if (bEl != null) {
            final v = bEl.getAttribute('w:val');
            bold = v != 'false' && v != '0';
          }
          final iEl = rPr.getElement('w:i');
          if (iEl != null) {
            final v = iEl.getAttribute('w:val');
            italic = v != 'false' && v != '0';
          }
          final cEl = rPr.getElement('w:color');
          if (cEl != null) {
            final v = cEl.getAttribute('w:val');
            if (v != null && v != 'auto') color = _hexColor(v);
          }
        }

        final pPr = style.getElement('w:pPr');
        if (pPr != null) {
          final pRpr = pPr.getElement('w:rPr');
          if (pRpr != null) {
            if (fontSize == null) {
              final sz = pRpr.getElement('w:sz');
              if (sz != null) {
                final v = sz.getAttribute('w:val');
                if (v != null) fontSize = (double.tryParse(v) ?? 24) / 2;
              }
            }
            final bEl = pRpr.getElement('w:b');
            if (bEl != null && !bold) {
              final v = bEl.getAttribute('w:val');
              bold = v != 'false' && v != '0';
            }
          }
        }

        map[id] = _Style(
          fontSize: fontSize,
          bold: bold,
          italic: italic,
          color: color,
        );
      }
    } catch (_) {}
    return map;
  }

  // ============================================================
  // COLOR HELPERS
  // ============================================================

  static PdfColor _hexColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) {
        final r = int.parse(hex.substring(0, 2), radix: 16);
        final g = int.parse(hex.substring(2, 4), radix: 16);
        final b = int.parse(hex.substring(4, 6), radix: 16);
        return PdfColor.fromInt((0xFF << 24) | (r << 16) | (g << 8) | b);
      }
    } catch (_) {}
    return PdfColors.black;
  }

  static PdfColor _namedColor(String name) {
    switch (name.toLowerCase()) {
      case 'yellow':
        return PdfColors.yellow100;
      case 'green':
        return PdfColors.lightGreen100;
      case 'cyan':
        return PdfColors.cyan100;
      case 'magenta':
        return PdfColors.pink100;
      case 'blue':
        return PdfColors.blue100;
      case 'red':
        return PdfColors.red100;
      case 'darkblue':
        return PdfColors.blue200;
      case 'darkcyan':
        return PdfColors.cyan200;
      case 'darkgreen':
        return PdfColors.green200;
      case 'darkmagenta':
        return PdfColors.pink200;
      case 'darkred':
        return PdfColors.red200;
      case 'darkyellow':
        return PdfColors.amber200;
      case 'darkgray':
      case 'darkgrey':
        return PdfColors.grey400;
      case 'lightgray':
      case 'lightgrey':
        return PdfColors.grey200;
      case 'black':
        return PdfColors.grey300;
      default:
        return PdfColors.yellow100;
    }
  }

  // ============================================================
  // UTILITY
  // ============================================================

  static bool isDocxFile(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    return ext == '.docx' || ext == '.doc';
  }

  static Future<List<String>> convertMultiple(List<File> files) async {
    final results = <String>[];
    for (final f in files) {
      try {
        results.add(await convertToPdf(f));
      } catch (e) {
        print("❌ ${p.basename(f.path)}: $e");
      }
    }
    return results;
  }
}

// ============================================================
// MODELS
// ============================================================

class _Fonts {
  final pw.Font regular, bold, italic, boldItalic;
  _Fonts({
    required this.regular,
    required this.bold,
    required this.italic,
    required this.boldItalic,
  });
}

class _Style {
  final double? fontSize;
  final bool bold, italic;
  final PdfColor? color;
  _Style({this.fontSize, this.bold = false, this.italic = false, this.color});
}

/// Ro'yxat formatining ta'rifi
class _ListDef {
  final String format; // decimal, lowerLetter, bullet, etc.
  final String textPattern; // "%1.", "%1)", "(%1)" kabi
  final int startValue; // Boshlang'ich raqam (odatda 1)

  _ListDef({
    required this.format,
    required this.textPattern,
    this.startValue = 1,
  });
}
