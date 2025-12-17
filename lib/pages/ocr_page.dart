// lib/pages/ocr_page.dart
//
// OCR page (production-ready):
// - Multi-page OCR -> bitta text (preview)
// - OCR til AUTO + backend cache + document_id
// - DOCX yaratish backend bilan to‘liq sync

import 'dart:io';

import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../services/api_service.dart';
import '../services/document_service.dart';

class OcrPage extends StatefulWidget {
  final List<File> images;

  const OcrPage({super.key, required this.images});

  @override
  State<OcrPage> createState() => _OcrPageState();
}

class _OcrPageState extends State<OcrPage> {
  final _titleCtrl = TextEditingController();
  final _textCtrl = TextEditingController();

  bool _loading = false;
  bool _saving = false;

  int _currentStep = 0;
  String _status = "";

  /// 🔥 User-selected / detected OCR language
  String _lang = "auto";

  /// 🔥 Backend bilan bog‘lash uchun bitta hujjat ID
  late final String _documentId =
      DateTime.now().millisecondsSinceEpoch.toString();

  static const _langs = {
    "auto": "Auto",
    "uzb": "O‘zbek (lotin)",
    "uzb_cyrl": "O‘zbek (krill)",
    "rus": "Rus",
    "eng": "English",
  };

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = "Hujjat $_documentId";
    _runOcr();
  }

  Future<void> _runOcr() async {
    if (widget.images.isEmpty) return;

    setState(() {
      _loading = true;
      _currentStep = 0;
      _status = "OCR boshlanmoqda...";
    });

    try {
      final api = ApiService();

      final ok = await api.checkHealth();
      if (!ok) {
        throw Exception(
          "Backend ishlamayapti.\n"
          "Telefon va PC bir xil Wi-Fi’da ekanini tekshir.",
        );
      }

      final buffer = StringBuffer();

      for (int i = 0; i < widget.images.length; i++) {
        setState(() {
          _currentStep = i + 1;
          _status = "OCR: ${i + 1}/${widget.images.length}";
        });

        final res = await api.sendImageForOcr(
          widget.images[i],
          lang: _lang,
          documentId: _documentId, // 🔥 MUHIM
        );

        final text = res.text.trim();
        if (text.isNotEmpty) buffer.writeln(text);
        if (i != widget.images.length - 1) buffer.writeln("\n");

        // 🔥 Backend aniqlagan tilni Flutter ham bilib oladi
        if (_lang == "auto" && res.detectedLang != null) {
          _lang = res.detectedLang!;
        }
      }

      _textCtrl.text = buffer.toString().trim();

      if (_textCtrl.text.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ OCR natijasi bo‘sh chiqdi")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ OCR xatolik: $e")));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _status = "";
        });
      }
    }
  }

  Future<void> _createDocx() async {
    final title =
        _titleCtrl.text.trim().isEmpty
            ? "Hujjat $_documentId"
            : _titleCtrl.text.trim();

    setState(() => _saving = true);

    try {
      await DocumentService().createDocxFromImages(
        title: title,
        images: widget.images,
        lang: _lang, // 🔥 backend cache bilan sync
        documentId: _documentId, // 🔥 MUHIM
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ DOCX yaratildi va saqlandi")),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ DOCX xatolik: $e")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.images.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text("OCR – Matnni ajratish"),
        actions: [
          IconButton(
            tooltip: "Qayta OCR",
            onPressed: (_loading || _saving) ? null : _runOcr,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _lang,
              decoration: const InputDecoration(
                labelText: "OCR tili",
                border: OutlineInputBorder(),
              ),
              items:
                  _langs.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
              onChanged:
                  (_loading || _saving)
                      ? null
                      : (v) {
                        if (v == null) return;
                        setState(() => _lang = v);
                        _runOcr();
                      },
            ),

            const SizedBox(height: 12),

            if (_loading) ...[
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : (_currentStep / total),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text("$_currentStep/$total"),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _status,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 12),
            ],

            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: "Hujjat nomi",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: TextField(
                controller: _textCtrl,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  labelText: "Ajratilgan matn (preview)",
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: (_loading || _saving) ? null : _createDocx,
                icon:
                    _saving
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.description),
                label: Text(_saving ? "DOCX yaratilmoqda..." : "DOCX yaratish"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
