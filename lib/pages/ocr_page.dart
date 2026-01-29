// lib/pages/ocr_page.dart
//
// 🔥 RENDER BACKEND UCHUN YANGILANGAN
//

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

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
  bool _fastMode = true; // 🔥 YANGI: default true (tezroq)

  int _currentStep = 0;
  String _status = "";

  /// User-selected / detected OCR language
  String _lang = "auto";

  /// Backend cache/sync uchun bitta hujjat ID
  late final String _documentId =
      DateTime.now().millisecondsSinceEpoch.toString();

  static const Map<String, String> _langs = {
    "auto": "Auto",
    "uzb": "O'zbek (lotin)",
    "uzb_cyrl": "O'zbek (krill)",
    "rus": "Rus",
    "eng": "English",
  };

  // settings_box bo'lsa: autoDetect + preferredLang dan default olamiz
  String _readEffectiveOcrLang() {
    try {
      final box = Hive.box('settings_box');

      final auto = box.get('ocr_auto_detect', defaultValue: true) as bool;
      final preferred =
          (box.get('ocr_preferred_lang', defaultValue: 'uzb')).toString();

      final lang = auto ? 'auto' : preferred;
      return _langs.containsKey(lang) ? lang : 'auto';
    } catch (_) {
      return 'auto';
    }
  }

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = "Hujjat $_documentId";

    // ✅ default tilni settings_box dan olamiz (bo'lmasa auto)
    _lang = _readEffectiveOcrLang();

    _runOcr();
  }

  Future<void> _runOcr() async {
    if (widget.images.isEmpty) return;

    setState(() {
      _loading = true;
      _currentStep = 0;
      _status = "Backend tekshirilmoqda...";
    });

    try {
      final api = ApiService();

      // 🔥 YANGILANGAN: Batafsil health check
      setState(() => _status = "Backend bilan bog'lanish... (60 sek kutish)");

      bool ok = false;
      String? errorMsg;

      try {
        ok = await api.checkHealth().timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            errorMsg =
                "⏱️ Backend javob bermadi (60 sek timeout).\n\n"
                "Ehtimol:\n"
                "• Backend uyquda (Render free plan)\n"
                "• URL noto'g'ri\n"
                "• Internet yo'q\n\n"
                "Qayta urinib ko'ring yoki 1-2 daqiqa kuting.";
            return false;
          },
        );
      } catch (e) {
        errorMsg =
            "❌ Backend bilan bog'lanish xatolik:\n$e\n\n"
            "Tekshiring:\n"
            "• Internet ulangan bo'lsin\n"
            "• Backend URL to'g'ri bo'lsin (api_service.dart)";
        ok = false;
      }

      if (!ok) {
        throw Exception(errorMsg ?? "Backend ishlamayapti.");
      }

      setState(() => _status = "✅ Backend tayyor!");
      await Future.delayed(const Duration(milliseconds: 500));

      final buffer = StringBuffer();

      for (int i = 0; i < widget.images.length; i++) {
        setState(() {
          _currentStep = i + 1;
          _status = "OCR: ${i + 1}/${widget.images.length}";
        });

        final res = await api.sendImageForOcr(
          widget.images[i],
          lang: _lang,
          documentId: _documentId,
          fastMode: _fastMode, // 🔥 YANGI
        );

        final text = res.text.trim();
        if (text.isNotEmpty) buffer.writeln(text);
        if (i != widget.images.length - 1) buffer.writeln("\n");

        // 🔥 Agar auto bo'lsa va backend aniqlab bersa, keyingi sahifalar shu til bilan ketadi
        if (_lang == "auto" && res.detectedLang != null) {
          final detected = res.detectedLang!.trim();
          if (_langs.containsKey(detected)) {
            _lang = detected;
          }
        }
      }

      _textCtrl.text = buffer.toString().trim();

      if (_textCtrl.text.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ OCR natijasi bo'sh chiqdi")),
        );
      }
    } catch (e) {
      if (!mounted) return;

      // 🔥 Batafsil xatolik xabari
      String errorMessage = e.toString();

      // "Exception: " prefiksini olib tashlash
      if (errorMessage.startsWith("Exception: ")) {
        errorMessage = errorMessage.substring(11);
      }

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text("❌ OCR Xatolik"),
              content: SingleChildScrollView(child: Text(errorMessage)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
                if (errorMessage.contains("timeout") ||
                    errorMessage.contains("Backend"))
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _runOcr(); // Qayta urinish
                    },
                    child: const Text("Qayta urinish"),
                  ),
              ],
            ),
      );
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
        lang: _lang,
        documentId: _documentId,
        fastMode: _fastMode, // 🔥 YANGI
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ DOCX yaratildi va saqlandi")),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      String errorMessage = e.toString();
      if (errorMessage.startsWith("Exception: ")) {
        errorMessage = errorMessage.substring(11);
      }

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text("❌ DOCX Xatolik"),
              content: Text(errorMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
      );
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
                      : (v) async {
                        if (v == null) return;
                        setState(() => _lang = v);
                        await _runOcr();
                      },
            ),
            const SizedBox(height: 12),

            // 🔥 YANGI: Fast Mode checkbox
            CheckboxListTile(
              title: const Text("Tez rejim"),
              subtitle: const Text("Aniqlik biroz kamayadi, lekin 2x tezroq"),
              value: _fastMode,
              onChanged:
                  (_loading || _saving)
                      ? null
                      : (value) {
                        setState(() => _fastMode = value ?? true);
                      },
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: "Hujjat nomi",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            if (_loading) ...[
              LinearProgressIndicator(
                value: total == 0 ? null : (_currentStep / total),
              ),
              const SizedBox(height: 8),
              Text(_status),
              const SizedBox(height: 12),
            ],

            Expanded(
              child: TextField(
                controller: _textCtrl,
                readOnly: true,
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
