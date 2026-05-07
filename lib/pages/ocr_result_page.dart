// lib/pages/ocr_result_page.dart
// OCR natija sahifasi â€” matn ko'rish, nusxalash, Download Word

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_colors.dart';
import '../models/document_model.dart';
import '../services/ocr_api_service.dart';

class OcrResultPage extends StatefulWidget {
  final List<File> images;

  const OcrResultPage({super.key, required this.images});

  @override
  State<OcrResultPage> createState() => _OcrResultPageState();
}

class _OcrResultPageState extends State<OcrResultPage> {
  final _ocrService = OcrApiService();

  String _extractedText = '';
  bool _isProcessing = true;
  bool _isDownloading = false;
  String _statusText = 'Starting...';
  double _progress = 0.0;
  String? _errorMessage;
  OcrErrorType? _errorType;
  int _currentPreviewIndex = 0;

  @override
  void initState() {
    super.initState();
    _processImages();
  }

  // ============================================================
  // OCR â€” Backend orqali
  // ============================================================

  Future<void> _processImages() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _errorType = null;
      _progress = 0.0;
      _statusText = 'Starting...';
    });

    try {
      final result = await _ocrService.processImages(
        widget.images,
        onProgress: (status, progress) {
          if (mounted) {
            setState(() {
              _statusText = status;
              _progress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _extractedText = result.text;
          _isProcessing = false;
        });
      }
    } on OcrApiException catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = _getErrorMessage(e);
          _errorType = e.type;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Unexpected error: $e';
        });
      }
    }
  }

  String _getErrorMessage(OcrApiException e) {
    switch (e.type) {
      case OcrErrorType.network:
        return 'Check your internet connection and try again.';
      case OcrErrorType.server:
        return 'A server error occurred. Please try again later.';
      case OcrErrorType.invalidImage:
        return 'No text found in the image. Please select another image.';
    }
  }

  // ============================================================
  // Matnni nusxalash
  // ============================================================

  Future<void> _copyText() async {
    if (_extractedText.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: _extractedText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Text copied!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ============================================================
  // Word yuklab olish
  // ============================================================

  Future<void> _downloadDocx() async {
    if (_extractedText.isEmpty) return;

    setState(() => _isDownloading = true);

    try {
      // Backend orqali DOCX yaratish
      final bytes = await _ocrService.buildDocx(_extractedText);

      // Faylni saqlash
      final dir = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final fileName =
          'Scan_${now.year}${_pad(now.month)}${_pad(now.day)}'
          '_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}.docx';
      final docxFile = File('${dir.path}/$fileName');
      await docxFile.writeAsBytes(bytes, flush: true);

      // Hive ga saqlash
      final docBox = Hive.box<DocumentModel>('documents_box');
      final document = DocumentModel(
        title: fileName.replaceAll('.docx', ''),
        filePath: docxFile.path,
        createdAt: DateTime.now(),
        fileType: 'docx',
        category: 'Education',
      );
      await docBox.add(document);

      if (!mounted) return;
      setState(() => _isDownloading = false);
      await _showDownloadSuccessDialog(docxFile);
    } on OcrApiException catch (e) {
      if (!mounted) return;
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating Word: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // Muvaffaqiyat dialogi
  // ============================================================

  Future<void> _showDownloadSuccessDialog(File docxFile) async {
    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 12),
                Flexible(child: Text('Word created!')),
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
                      _checkRow('DOCX file created'),
                      const SizedBox(height: 6),
                      _checkRow('Saved to Documents'),
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
                child: const Text('Back'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await OpenFile.open(docxFile.path);
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open'),
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
                  ], text: 'Scanned document');
                },
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Share'),
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

  String _pad(int n) => n.toString().padLeft(2, '0');

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('OCR Result'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body:
          _isProcessing
              ? _buildProcessingUI()
              : _errorMessage != null
              ? _buildErrorUI()
              : _buildResultUI(),
    );
  }

  // ============================================================
  // Loading UI â€” progress ko'rsatish
  // ============================================================

  Widget _buildProcessingUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: _progress > 0 ? _progress : null,
                strokeWidth: 6,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _statusText,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: Colors.grey.shade200,
                color: AppColors.primary,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 10),
            if (_progress > 0)
              Text(
                '${(_progress * 100).toInt()}%',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            const SizedBox(height: 32),
            // Jarayon bosqichlari
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  _stepRow('Compressing images', _progress >= 0.05),
                  const SizedBox(height: 8),
                  _stepRow('Uploading to server', _progress >= 0.25),
                  const SizedBox(height: 8),
                  _stepRow('Processing OCR', _progress >= 0.50),
                  const SizedBox(height: 8),
                  _stepRow('Preparing result', _progress >= 0.95),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${widget.images.length} images are being processed',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepRow(String text, bool done) {
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done ? Colors.green : Colors.grey.shade400,
          size: 20,
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: done ? Colors.green.shade700 : Colors.grey.shade600,
            fontWeight: done ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Xatolik UI
  // ============================================================

  Widget _buildErrorUI() {
    IconData errorIcon;
    Color errorColor;

    switch (_errorType) {
      case OcrErrorType.network:
        errorIcon = Icons.wifi_off;
        errorColor = Colors.orange;
        break;
      case OcrErrorType.server:
        errorIcon = Icons.cloud_off;
        errorColor = Colors.red;
        break;
      case OcrErrorType.invalidImage:
        errorIcon = Icons.image_not_supported;
        errorColor = Colors.amber;
        break;
      default:
        errorIcon = Icons.error_outline;
        errorColor = Colors.red;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(errorIcon, size: 80, color: errorColor),
            const SizedBox(height: 24),
            const Text(
              'An error occurred',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _processImages,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Natija UI matn + preview + download
  // ============================================================

  Widget _buildResultUI() {
    return Column(
      children: [
        // Rasm preview (gorizontal scroll)
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              final isActive = index == _currentPreviewIndex;
              return GestureDetector(
                onTap: () => setState(() => _currentPreviewIndex = index),
                child: Container(
                  width: 110,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isActive ? AppColors.primary : Colors.grey.shade300,
                      width: isActive ? 2.5 : 1,
                    ),
                    image: DecorationImage(
                      image: FileImage(widget.images[index]),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Statistika
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${widget.images.length} images | ${_extractedText.length} characters',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                onPressed: _copyText,
                tooltip: 'Copy',
                color: AppColors.primary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Ajratilgan matn
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                _extractedText.isEmpty ? 'No text found' : _extractedText,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ),
          ),
        ),

        // Tugmalar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Nusxalash tugmasi
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _copyText,
                    icon: const Icon(Icons.copy, size: 20),
                    label: const Text('Copy'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Word yuklab olish tugmasi
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isDownloading ? null : _downloadDocx,
                    icon:
                        _isDownloading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.download, size: 22),
                    label: Text(
                      _isDownloading ? 'Downloading...' : 'Download Word',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
