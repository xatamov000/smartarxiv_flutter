// lib/pages/scan_page.dart
//
// Export UX final:
// - Camera/Gallery/File: faqat ro'yxatga qo'shadi (editga avtomatik ketmaydi)
// - Katta rasm bosilsa: full screen edit (ImageEditPage)
// - Crop faqat camera rasmlarida
// - Export tanlovi: PDF (scan) yoki DOCX (OCR)
// - PDF: offline yaratadi (rasmlar sahifalarga joylanadi)
// - DOCX: OcrPage ga o'tadi (keyin DocumentService bilan to'liq bog'laymiz)

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
// Open/Share
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
// PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../config/app_colors.dart';
import '../services/permission_service.dart';
import 'image_edit_page.dart';
import 'ocr_page.dart';
import 'widgets/bottom_nav.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanItem {
  File file;
  final bool allowCrop; // camera = true, boshqa = false

  _ScanItem({required this.file, required this.allowCrop});
}

class _ScanPageState extends State<ScanPage> {
  final List<_ScanItem> _pages = [];
  final ImagePicker _picker = ImagePicker();
  int _currentIndex = 0;

  bool _exporting = false;

  _ScanItem? get _currentItem =>
      _pages.isEmpty ? null : _pages[_currentIndex.clamp(0, _pages.length - 1)];

  // ============================================================
  // Camera (crop allowed) — faqat qo'shadi
  // ============================================================
  Future<void> _addFromCamera() async {
    final ok = await PermissionService.requestCamera();
    if (!ok) return;

    final img = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (img == null) return;

    setState(() {
      _pages.add(_ScanItem(file: File(img.path), allowCrop: true));
      _currentIndex = _pages.length - 1;
    });
  }

  // ============================================================
  // Gallery (no crop) — faqat qo'shadi
  // ============================================================
  Future<void> _pickGalleryImages() async {
    final ok = await PermissionService.requestStorage();
    if (!ok) return;

    final images = await _picker.pickMultiImage(imageQuality: 85);
    if (images.isEmpty) return;

    setState(() {
      for (final x in images) {
        _pages.add(_ScanItem(file: File(x.path), allowCrop: false));
      }
      _currentIndex = _pages.length - 1;
    });
  }

  // ============================================================
  // File picker (no crop) — faqat qo'shadi
  // ============================================================
  Future<void> _pickFiles() async {
    final ok = await PermissionService.requestStorage();
    if (!ok) return;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ["jpg", "jpeg", "png"],
    );
    if (result == null) return;

    final paths = result.paths.whereType<String>().toList();
    if (paths.isEmpty) return;

    setState(() {
      for (final p in paths) {
        _pages.add(_ScanItem(file: File(p), allowCrop: false));
      }
      _currentIndex = _pages.length - 1;
    });
  }

  // ============================================================
  // Open editor (preview bosilganda)
  // ============================================================
  Future<void> _openEditor(int index) async {
    if (index < 0 || index >= _pages.length) return;

    final item = _pages[index];

    final result = await Navigator.push<ImageEditResult?>(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
                ImageEditPage(imageFile: item.file, allowCrop: item.allowCrop),
      ),
    );

    if (!mounted || result == null) return;

    if (result.deleted) {
      setState(() {
        _pages.removeAt(index);
        if (_pages.isEmpty) {
          _currentIndex = 0;
        } else {
          _currentIndex = _currentIndex.clamp(0, _pages.length - 1);
        }
      });
      return;
    }

    if (result.file != null) {
      setState(() {
        _pages[index].file = result.file!;
      });
    }
  }

  // ============================================================
  // EXPORT UI (PDF / DOCX)
  // ============================================================
  void _showExportSheet() {
    if (_pages.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Qaysi formatda yaratamiz?",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),

                // PDF
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: const Text("PDF (scan ko‘rinish)"),
                  subtitle: const Text(
                    "Rasmlar sahifalarga joylanadi. Ko‘rinish 100% saqlanadi.",
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _exportAsPdf();
                  },
                ),

                // DOCX
                ListTile(
                  leading: const Icon(Icons.description, color: Colors.blue),
                  title: const Text("Word (DOCX)"),
                  subtitle: const Text(
                    "OCR orqali matn ajratiladi va DOCX yaratiladi.",
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _exportAsDocxFlow();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportAsDocxFlow() async {
    final files = _pages.map((e) => e.file).toList();

    // Hozircha DOCX oqimi OcrPage orqali.
    // Keyingi bosqichda DocumentService bilan to'liq bog'laymiz:
    // - OCR -> text
    // - DOCX builder
    // - file save + Documents listga qo'shish
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OcrPage(images: files)),
    );
  }

  Future<void> _exportAsPdf() async {
    if (_exporting) return;

    setState(() => _exporting = true);

    try {
      final pdf = pw.Document();

      for (final item in _pages) {
        final Uint8List bytes = await item.file.readAsBytes();
        final img = pw.MemoryImage(bytes);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(18),
            build: (_) {
              return pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain));
            },
          ),
        );
      }

      final dir = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final name =
          "scan_${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}${_two(now.second)}.pdf";
      final outFile = File("${dir.path}/$name");

      final bytes = await pdf.save();
      await outFile.writeAsBytes(bytes, flush: true);

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text("✅ PDF tayyor"),
            content: Text("Fayl saqlandi:\n${outFile.path}"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Yopish"),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await OpenFile.open(outFile.path);
                },
                child: const Text("Ochish"),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await Share.shareXFiles([
                    XFile(outFile.path),
                  ], text: "📄 PDF fayl");
                },
                child: const Text("Ulashish"),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ PDF yaratishda xatolik: $e")));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const BottomNav(currentIndex: 1),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: AppColors.primary,
          statusBarIconBrightness: Brightness.light,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 30),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _pages.isEmpty ? _buildEmptyUI() : _buildPreviewUI(),
                _buildTips(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Skaynerlash ⚡",
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Hujjatni skanerlash yoki yuklash",
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyUI() {
    return Column(
      children: [
        GestureDetector(onTap: _addFromCamera, child: _mainScanCard()),
        const SizedBox(height: 20),
        const Text("yoki"),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            GestureDetector(
              onTap: _pickFiles,
              child: _uploadOption(
                icon: Icons.upload_file,
                label: "Fayldan yuklash",
                color: Colors.greenAccent,
              ),
            ),
            GestureDetector(
              onTap: _pickGalleryImages,
              child: _uploadOption(
                icon: Icons.image,
                label: "Galereyadan",
                color: Colors.pinkAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildPreviewUI() {
    final current = _currentItem;

    return Column(
      children: [
        if (current != null)
          GestureDetector(
            onTap: () => _openEditor(_currentIndex),
            child: Container(
              width: double.infinity,
              height: 360,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                image: DecorationImage(
                  image: FileImage(current.file),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        const SizedBox(height: 18),

        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _pages.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return GestureDetector(
                  onTap: _addFromCamera,
                  child: _addButton(),
                );
              }

              final item = _pages[index - 1];
              final active = index - 1 == _currentIndex;

              return GestureDetector(
                onTap: () => setState(() => _currentIndex = index - 1),
                onLongPress: () => _openEditor(index - 1),
                child: _thumbnail(item.file, active),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // EXPORT button (PDF / DOCX)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _pages.isEmpty || _exporting ? null : _showExportSheet,
              icon:
                  _exporting
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.download),
              label: Text(
                _exporting ? "Yaratilmoqda..." : "Yaratish (PDF / DOCX)",
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

        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildTips() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Maslahatlar:",
            style: TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 10),
          Text("✓ Hujjat to‘liq ko‘rinishda bo‘lsin"),
          SizedBox(height: 6),
          Text("✓ Yoruqlik yetarli bo‘lsin"),
          SizedBox(height: 6),
          Text("✓ Telefonni barqaror ushlang"),
          SizedBox(height: 6),
          Text("✓ Hujjat tekis joyda bo‘lsin"),
        ],
      ),
    );
  }

  // UI components
  Widget _mainScanCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.camera_alt, color: Colors.white, size: 60),
          const SizedBox(height: 16),
          const Text(
            "Hujjatni skanerlash",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Kamera orqali yuqori sifatli skan",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: _addFromCamera,
            child: const Text("Kamerani ochish"),
          ),
        ],
      ),
    );
  }

  Widget _uploadOption({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: color.withOpacity(.25),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 34),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _addButton() {
    return Container(
      width: 70,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary),
      ),
      child: const Center(child: Icon(Icons.add, color: AppColors.primary)),
    );
  }

  Widget _thumbnail(File file, bool active) {
    return Container(
      width: 70,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
        image: DecorationImage(image: FileImage(file), fit: BoxFit.cover),
      ),
    );
  }
}
