// lib/pages/image_edit_page.dart
//
// Full screen image edit page
// - crop (optional, faqat camera)
// - rotate
// - delete (confirm)
// Returns ImageEditResult (updated/deleted)
// NO OCR / NO DOCX here

import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../config/app_colors.dart';

class ImageEditResult {
  final File? file;
  final bool deleted;

  const ImageEditResult._({this.file, required this.deleted});

  factory ImageEditResult.updated(File f) =>
      ImageEditResult._(file: f, deleted: false);

  factory ImageEditResult.deleted() => const ImageEditResult._(deleted: true);
}

class ImageEditPage extends StatefulWidget {
  final File imageFile;
  final bool allowCrop;

  const ImageEditPage({
    super.key,
    required this.imageFile,
    required this.allowCrop,
  });

  @override
  State<ImageEditPage> createState() => _ImageEditPageState();
}

class _ImageEditPageState extends State<ImageEditPage> {
  final CropController _cropController = CropController();

  late Uint8List _imageBytes;
  bool _busy = false;

  // Crop widget refresh uchun (rotate qilganda crop overlay reset bo‘lsin)
  int _cropVersion = 0;

  @override
  void initState() {
    super.initState();
    _imageBytes = widget.imageFile.readAsBytesSync();
  }

  void _rotate90() {
    final decoded = img.decodeImage(_imageBytes);
    if (decoded == null) return;

    final rotated = img.copyRotate(decoded, angle: 90);
    final bytes = Uint8List.fromList(img.encodeJpg(rotated, quality: 95));

    setState(() {
      _imageBytes = bytes;
      _cropVersion++; // crop view reset
    });
  }

  Future<File> _saveBytesToSameFile(Uint8List bytes) async {
    return widget.imageFile.writeAsBytes(bytes, flush: true);
  }

  Future<void> _saveNoCrop() async {
    setState(() => _busy = true);
    try {
      final f = await _saveBytesToSameFile(_imageBytes);
      if (!mounted) return;
      Navigator.pop(context, ImageEditResult.updated(f));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Saqlashda xatolik: $e")));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startCrop() {
    // crop bosilganda busy qo'yamiz, cropped callbackda tushiramiz
    setState(() => _busy = true);
    _cropController.crop();
  }

  Future<void> _onCropped(Uint8List cropped) async {
    try {
      final f = await _saveBytesToSameFile(cropped);
      if (!mounted) return;
      Navigator.pop(context, ImageEditResult.updated(f));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Crop/Save xatolik: $e")));
      setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Rasm o‘chirilsinmi?"),
          content: const Text("Bu rasm ro‘yxatdan olib tashlanadi."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Bekor"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("O‘chirish"),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    if (!mounted) return;
    Navigator.pop(context, ImageEditResult.deleted());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text("Rasmni tahrirlash"),
        actions: [
          IconButton(
            tooltip: "Burish",
            icon: const Icon(Icons.rotate_right),
            onPressed: _busy ? null : _rotate90,
          ),
          if (widget.allowCrop)
            IconButton(
              tooltip: "Kesish",
              icon: const Icon(Icons.crop),
              onPressed: _busy ? null : _startCrop,
            ),
          IconButton(
            tooltip: "O‘chirish",
            icon: const Icon(Icons.delete),
            onPressed: _busy ? null : _delete,
          ),
          IconButton(
            tooltip: "Saqlash",
            icon: const Icon(Icons.check),
            // Crop bo'lmasa — oddiy save
            onPressed: _busy ? null : (widget.allowCrop ? null : _saveNoCrop),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (widget.allowCrop)
            Crop(
              key: ValueKey("crop_$_cropVersion"),
              controller: _cropController,
              image: _imageBytes,
              onCropped: _onCropped,
              maskColor: Colors.black.withOpacity(0.6),
              baseColor: Colors.black,
            )
          else
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Image.memory(_imageBytes, fit: BoxFit.contain),
              ),
            ),

          if (_busy) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
