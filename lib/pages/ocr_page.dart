// lib/pages/ocr_page.dart
// 🎯 ODDIY YECHIM - Mavjud servicelar bilan!

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

import '../models/document_model.dart';
import '../services/docx_creator_service.dart';
import '../services/local_ocr_service.dart';

class OcrPage extends StatefulWidget {
  final List<File> images;

  const OcrPage({Key? key, required this.images}) : super(key: key);

  @override
  State<OcrPage> createState() => _OcrPageState();
}

class _OcrPageState extends State<OcrPage> {
  final _localOcr = LocalOcrService();
  final _docxCreator = DocxCreatorService();

  String _extractedText = '';
  bool _isProcessing = false;
  bool _isSavingDocx = false;
  int _currentImageIndex = 0;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _processAllImages();
  }

  Future<void> _processAllImages() async {
    setState(() {
      _isProcessing = true;
      _progress = 0.0;
    });

    final allText = StringBuffer();

    for (int i = 0; i < widget.images.length; i++) {
      setState(() {
        _currentImageIndex = i;
        _progress = (i + 1) / widget.images.length;
      });

      try {
        print('⚡ OCR: image ${i + 1}/${widget.images.length}');

        final text = await _localOcr.recognizeText(widget.images[i]);
        final cleanedText = _localOcr.cleanText(text);

        if (cleanedText.isNotEmpty) {
          if (widget.images.length > 1) {
            allText.writeln('--- Sahifa ${i + 1} ---\n');
          }
          allText.writeln(cleanedText);
          allText.writeln();
        }

        print('✅ Image ${i + 1} processed: ${cleanedText.length} chars');
      } catch (e) {
        print('❌ Error: $e');
        allText.writeln('--- Sahifa ${i + 1}: Xatolik ---\n');
      }
    }

    setState(() {
      _extractedText = allText.toString().trim();
      _isProcessing = false;
    });

    print('✅ OCR complete: ${_extractedText.length} total chars');
  }

  Future<void> _saveAsDocx() async {
    if (_extractedText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Matn topilmadi!')));
      return;
    }

    setState(() => _isSavingDocx = true);

    try {
      print('📄 Creating DOCX...');

      final docxFile = await _docxCreator.createSimpleDocx(_extractedText);

      final docBox = Hive.box<DocumentModel>('documents_box');
      final now = DateTime.now();

      final document = DocumentModel(
        title: docxFile.path.split('/').last.replaceAll('.docx', ''),
        filePath: docxFile.path,
        createdAt: now,
        fileType: 'docx',
        category: 'O\'quv', // yoki 'Boshqa'
      );

      await docBox.add(document);

      print('✅ Document saved to Hive');

      setState(() => _isSavingDocx = false);

      if (!mounted) return;

      await showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 28),
                  SizedBox(width: 12),
                  Text('Tayyor!'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check, color: Colors.green, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'DOCX yaratildi',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.check, color: Colors.green, size: 20),
                            SizedBox(width: 8),
                            Text('Documents ga qo\'shildi'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    docxFile.path.split('/').last,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text('Documents ga'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await OpenFile.open(docxFile.path);
                  },
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Ochish'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await Share.shareXFiles([
                      XFile(docxFile.path),
                    ], text: '📄 Scan');
                  },
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Ulashish'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
      );
    } catch (e) {
      print('❌ Error: $e');

      setState(() => _isSavingDocx = false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OCR - Matnni ajratish')),
      body: _isProcessing ? _buildProcessingUI() : _buildResultUI(),
    );
  }

  Widget _buildProcessingUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            const Text(
              '⚡ Matn ajratilmoqda...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Rasm ${_currentImageIndex + 1} / ${widget.images.length}',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            Text(
              '${(_progress * 100).toInt()}%',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            const Text(
              '100% offline!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '✅ Matn ajratildi!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${widget.images.length} ta rasm, ${_extractedText.length} belgi',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Matn:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              child: SelectableText(
                _extractedText.isEmpty ? 'Matn topilmadi' : _extractedText,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: _isSavingDocx ? null : _saveAsDocx,
            icon:
                _isSavingDocx
                    ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.save, size: 24),
            label: Text(
              _isSavingDocx ? 'Saqlanmoqda...' : '💾 DOCX ga saqlash',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              elevation: 4,
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Xususiyatlar',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  '✓ DOCX formatida\n✓ Documents ga qo\'shiladi\n✓ Word/Google Docs da ochiladi\n✓ 100% offline',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _localOcr.dispose();
    super.dispose();
  }
}
