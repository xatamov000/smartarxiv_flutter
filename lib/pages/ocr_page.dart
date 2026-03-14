// lib/pages/ocr_page.dart
// 🎯 SMART OCR PAGE v4
//
// FLOW:
//   1. Local OCR → matn preview (tez, offline)
//   2. "DOCX saqlash" bosilganda:
//      a) 5s ichida backend bormi? → HA: /ocr/docx (ML model)
//      b) Backend yo'q? → Offline Smart DOCX (noise filter + merge + split)

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/document_model.dart';
import '../services/api_service.dart';
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
  final _apiService = ApiService();
  final _docxCreator = DocxCreatorService();

  String _extractedText = '';
  bool _isProcessing = false;
  bool _isSavingDocx = false;
  int _currentImageIndex = 0;
  double _progress = 0.0;
  String _savingStatus = '';
  String _ocrMode = ''; // 'server' yoki 'local'

  @override
  void initState() {
    super.initState();
    _processAllImages();
  }

  // ============================================================
  // 1) OCR — Server primary, Local fallback
  // ============================================================

  Future<void> _processAllImages() async {
    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _ocrMode = '';
    });

    // Avval server borligini tekshiramiz
    bool useServer = false;
    try {
      print('🔍 Backend OCR tekshirilmoqda...');
      useServer = await _apiService.checkHealth();
      print(useServer ? '✅ Server OCR ishlatiladi' : '⚠️ Server yo\'q, local OCR');
    } catch (_) {
      useServer = false;
    }

    setState(() {
      _ocrMode = useServer ? 'server' : 'local';
    });

    final allText = StringBuffer();

    for (int i = 0; i < widget.images.length; i++) {
      setState(() {
        _currentImageIndex = i;
        _progress = (i + 1) / widget.images.length;
      });

      try {
        print('⚡ OCR: image ${i + 1}/${widget.images.length} ($_ocrMode)');
        String text;

        if (useServer) {
          // SERVER OCR — yuqori sifat
          final result = await _apiService.sendImageForOcr(widget.images[i]);
          text = result.text;
          print('✅ Server OCR: ${text.length} chars, confidence: ${result.confidence}');
        } else {
          // LOCAL OCR — fallback
          text = await _localOcr.recognizeText(widget.images[i]);
        }

        final cleanedText = _localOcr.cleanText(text);

        if (cleanedText.isNotEmpty) {
          if (widget.images.length > 1) {
            allText.writeln('--- Sahifa ${i + 1} ---\n');
          }
          allText.writeln(cleanedText);
          allText.writeln();
        }
        print('✅ Image ${i + 1}: ${cleanedText.length} chars');
      } catch (e) {
        print('❌ OCR Error: $e');
        // Server xato bersa, shu rasm uchun local ga tushish
        if (useServer) {
          try {
            print('🔄 Fallback to local OCR for image ${i + 1}');
            final text = await _localOcr.recognizeText(widget.images[i]);
            final cleanedText = _localOcr.cleanText(text);
            if (cleanedText.isNotEmpty) {
              if (widget.images.length > 1) {
                allText.writeln('--- Sahifa ${i + 1} ---\n');
              }
              allText.writeln(cleanedText);
              allText.writeln();
            }
          } catch (e2) {
            print('❌ Local OCR ham xato: $e2');
            allText.writeln('--- Sahifa ${i + 1}: Xatolik ---\n');
          }
        } else {
          allText.writeln('--- Sahifa ${i + 1}: Xatolik ---\n');
        }
      }
    }

    setState(() {
      _extractedText = allText.toString().trim();
      _isProcessing = false;
    });
    print('✅ OCR complete ($_ocrMode): ${_extractedText.length} total chars');
  }

  // ============================================================
  // 2) BACKEND URL
  // ============================================================

  String _getBaseUrl() {
    const defaultUrl = 'http://10.163.30.170:8000';
    try {
      final box = Hive.box('settings_box');
      final v = (box.get('base_url') ?? '').toString().trim();
      if (v.isEmpty) return defaultUrl;
      return v.endsWith('/') ? v.substring(0, v.length - 1) : v;
    } catch (_) {
      return defaultUrl;
    }
  }

  // ============================================================
  // 3) QUICK BACKEND CHECK — 5 sekund
  // ============================================================

  Future<bool> _isBackendAvailable() async {
    try {
      print('🔍 Quick backend check (5s)...');
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      final res = await dio.get('${_getBaseUrl()}/health');
      final ok = res.statusCode == 200;
      print(ok ? '✅ Backend mavjud!' : '❌ Backend javob bermadi');
      return ok;
    } catch (e) {
      print('❌ Backend mavjud emas: $e');
      return false;
    }
  }

  // ============================================================
  // 4) DIRECT BACKEND DOCX — prewarm yo'q, tezkor
  // ============================================================

  Future<List<int>?> _buildDocxViaBackend() async {
    try {
      final baseUrl = _getBaseUrl();
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 60),
        ),
      );

      if (widget.images.length == 1) {
        final formData = FormData.fromMap({
          'image': await MultipartFile.fromFile(widget.images.first.path),
        });
        final res = await dio.post(
          '$baseUrl/ocr/docx',
          data: formData,
          options: Options(responseType: ResponseType.bytes),
        );
        return List<int>.from(res.data);
      } else {
        final files = <MultipartFile>[];
        for (final f in widget.images) {
          files.add(await MultipartFile.fromFile(f.path));
        }
        final formData = FormData.fromMap({'images': files});
        final res = await dio.post(
          '$baseUrl/ocr/docx/multi',
          data: formData,
          options: Options(responseType: ResponseType.bytes),
        );
        return List<int>.from(res.data);
      }
    } catch (e) {
      print('❌ Backend DOCX xatolik: $e');
      return null;
    }
  }

  // ============================================================
  // 5) DOCX SAQLASH
  // ============================================================

  Future<void> _saveAsDocx() async {
    if (_extractedText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Matn topilmadi!')));
      return;
    }

    setState(() {
      _isSavingDocx = true;
      _savingStatus = 'Tekshirilmoqda...';
    });

    File? docxFile;
    bool usedBackend = false;

    try {
      final backendOk = await _isBackendAvailable();

      if (backendOk) {
        setState(() => _savingStatus = 'Server: ML formatlash...');
        print('📄 Backend DOCX...');
        final bytes = await _buildDocxViaBackend();

        if (bytes != null && bytes.isNotEmpty) {
          final dir = await getApplicationDocumentsDirectory();
          final now = DateTime.now();
          final fileName =
              'Scan_${now.year}${_pad(now.month)}${_pad(now.day)}'
              '_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}.docx';
          docxFile = File('${dir.path}/$fileName');
          await docxFile.writeAsBytes(bytes, flush: true);
          usedBackend = true;
          print('✅ Backend DOCX: ${docxFile.path}');
        }
      }

      if (docxFile == null) {
        setState(() => _savingStatus = 'Offline: Smart formatlash...');
        print('📄 Offline Smart DOCX...');
        docxFile = await _docxCreator.createFormattedDocx(_extractedText);
        print('✅ Offline DOCX: ${docxFile.path}');
      }
    } catch (e) {
      print('❌ DOCX xatolik: $e');
      setState(() {
        _isSavingDocx = false;
        _savingStatus = '';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
      );
      return;
    }

    // Hive ga saqlash
    try {
      final docBox = Hive.box<DocumentModel>('documents_box');
      final document = DocumentModel(
        title: docxFile!.path.split('/').last.replaceAll('.docx', ''),
        filePath: docxFile.path,
        createdAt: DateTime.now(),
        fileType: 'docx',
        category: 'O\'quv',
      );
      await docBox.add(document);
      print('✅ Hive saved');

      setState(() {
        _isSavingDocx = false;
        _savingStatus = '';
      });
      if (!mounted) return;
      await _showSuccessDialog(docxFile, usedBackend);
    } catch (e) {
      setState(() {
        _isSavingDocx = false;
        _savingStatus = '';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ============================================================
  // SUCCESS DIALOG
  // ============================================================

  Future<void> _showSuccessDialog(File docxFile, bool usedBackend) async {
    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 12),
                Flexible(child: Text('Tayyor!')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _checkRow(
                        usedBackend
                            ? 'ML formatlangan DOCX'
                            : 'Smart formatlangan DOCX',
                      ),
                      const SizedBox(height: 6),
                      _checkRow('Documents ga qo\'shildi'),
                      const SizedBox(height: 6),
                      _checkRow('Noise filtrlandi, satrlar birlashtirildi'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  docxFile.path.split('/').last,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('Orqaga'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await OpenFile.open(docxFile.path);
                },
                icon: const Icon(Icons.open_in_new, size: 16),
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
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Ulashish'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
    );
  }

  Widget _checkRow(String text) {
    return Row(
      children: [
        const Icon(Icons.check, color: Colors.green, size: 18),
        const SizedBox(width: 8),
        Flexible(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    );
  }

  // ============================================================
  // UI
  // ============================================================

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
            Text(
              _ocrMode == 'server'
                  ? '🖥️ Server OCR ishlamoqda...'
                  : '⚡ Matn ajratilmoqda...',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  const Icon(Icons.check_circle, color: Colors.green, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _ocrMode == 'server'
                              ? 'Matn ajratildi! (Server)'
                              : 'Matn ajratildi! (Local)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${widget.images.length} ta rasm, ${_extractedText.length} belgi',
                          style: TextStyle(
                            fontSize: 13,
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
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            constraints: const BoxConstraints(maxHeight: 280),
            child: SingleChildScrollView(
              child: SelectableText(
                _extractedText.isEmpty ? 'Matn topilmadi' : _extractedText,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: _isSavingDocx ? null : _saveAsDocx,
            icon:
                _isSavingDocx
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.save, size: 22),
            label: Text(
              _isSavingDocx
                  ? (_savingStatus.isNotEmpty
                      ? _savingStatus
                      : 'Saqlanmoqda...')
                  : '💾 DOCX ga saqlash',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              elevation: 3,
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Smart Formatlash',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '✓ Telefon UI chiqindilari olib tashlanadi\n'
                  '✓ Uzilgan satrlar birlashtiriladi\n'
                  '✓ Paragraflar to\'g\'ri ajratiladi\n'
                  '✓ Sarlavha, ro\'yxat, abzats aniqlanadi\n'
                  '✓ Times New Roman, A4, 1.5 interval\n'
                  '✓ Online: ML model | Offline: Smart filter',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  void dispose() {
    _localOcr.dispose();
    super.dispose();
  }
}
