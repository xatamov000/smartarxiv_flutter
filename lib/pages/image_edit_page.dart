// lib/pages/image_edit_page.dart
//
// Full screen image edit page
// - rotate
// - crop (mode): the crop rectangle is shown ONLY after the Crop button is
//   tapped; it disappears again once the crop is applied or cancelled.
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

  // Crop rectangle is only visible while in crop mode.
  bool _cropMode = false;
  // Re-key the Crop widget so the rectangle resets each time we enter.
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

  // Enter crop mode: show the crop rectangle.
  void _enterCropMode() {
    setState(() {
      _cropMode = true;
      _cropVersion++;
    });
  }

  // Cancel crop mode: hide the rectangle, keep the image unchanged.
  void _cancelCrop() {
    setState(() => _cropMode = false);
  }

  // Apply crop: trigger the controller; result handled in _onCropped.
  void _applyCrop() {
    setState(() => _busy = true);
    _cropController.crop();
  }

  // Crop finished -> replace the in-memory image and leave crop mode,
  // so the rectangle disappears and the cropped image is shown normally.
  void _onCropped(Uint8List cropped) {
    setState(() {
      _imageBytes = cropped;
      _cropMode = false;
      _cropVersion++;
      _busy = false;
    });
  }

  // Save the edited image to disk and return to the scan page.
  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final f = await _saveBytesToSameFile(_imageBytes);
      if (!mounted) return;
      Navigator.pop(context, ImageEditResult.updated(f));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error while saving: $e")));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Delete this image?"),
          content: const Text("This image will be removed from the list."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete"),
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
        title: Text(_cropMode ? "Crop Image" : "Edit Image"),
        leading:
            _cropMode
                ? IconButton(
                  tooltip: "Cancel",
                  icon: const Icon(Icons.close),
                  onPressed: _busy ? null : _cancelCrop,
                )
                : null,
        actions:
            _cropMode
                ? [
                  IconButton(
                    tooltip: "Apply crop",
                    icon: const Icon(Icons.check),
                    onPressed: _busy ? null : _applyCrop,
                  ),
                ]
                : [
                  IconButton(
                    tooltip: "Rotate",
                    icon: const Icon(Icons.rotate_right),
                    onPressed: _busy ? null : _rotate90,
                  ),
                  if (widget.allowCrop)
                    IconButton(
                      tooltip: "Crop",
                      icon: const Icon(Icons.crop),
                      onPressed: _busy ? null : _enterCropMode,
                    ),
                  IconButton(
                    tooltip: "Delete",
                    icon: const Icon(Icons.delete),
                    onPressed: _busy ? null : _delete,
                  ),
                  IconButton(
                    tooltip: "Save",
                    icon: const Icon(Icons.check),
                    onPressed: _busy ? null : _save,
                  ),
                ],
      ),
      body: Stack(
        children: [
          if (_cropMode)
            Crop(
              key: ValueKey("crop_$_cropVersion"),
              controller: _cropController,
              image: _imageBytes,
              onCropped: _onCropped,
              aspectRatio: null,
              fixCropRect: false,
              initialSize: 0.8,
              cornerDotBuilder:
                  (size, edgeAlignment) => Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 3),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 4),
                      ],
                    ),
                  ),
              maskColor: Colors.black.withOpacity(0.55),
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
