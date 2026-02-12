// lib/services/compress_service.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Compression levels
enum CompressionLevel { low, medium, high }

class CompressService {
  const CompressService._(); // Prevent instantiation

  // =========================
  // PUBLIC API
  // =========================

  static Future<String> compressFile(File file, CompressionLevel level) async {
    if (!await file.exists()) {
      throw FileSystemException('File does not exist', file.path);
    }

    final ext = p.extension(file.path).toLowerCase();

    if (_isImage(ext)) {
      return _compressImage(file, level);
    } else if (ext == '.pdf') {
      return _compressPdf(file, level);
    } else if (['.doc', '.docx'].contains(ext)) {
      return _compressDocument(file, level);
    }

    throw UnsupportedError('Unsupported file type: $ext');
  }

  static Future<List<String>> compressMultipleFiles(
    List<File> files,
    CompressionLevel level, {
    void Function(int current, int total)? onProgress,
  }) async {
    final results = <String>[];

    for (int i = 0; i < files.length; i++) {
      final path = await compressFile(files[i], level);
      results.add(path);
      onProgress?.call(i + 1, files.length);
    }

    return results;
  }

  static Future<CompressionStats> getCompressionStats(
    File originalFile,
    File compressedFile,
  ) async {
    final originalSize = await originalFile.length();
    final compressedSize = await compressedFile.length();

    if (originalSize == 0) {
      return CompressionStats(
        originalSize: originalSize,
        compressedSize: compressedSize,
      );
    }

    return CompressionStats(
      originalSize: originalSize,
      compressedSize: compressedSize,
    );
  }

  // =========================
  // IMAGE COMPRESSION
  // =========================

  static Future<String> _compressImage(
    File imageFile,
    CompressionLevel level,
  ) async {
    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);

    if (decoded == null) {
      throw Exception('Failed to decode image.');
    }

    final settings = _imageSettings(level);

    img.Image processed = decoded;

    if (settings.scale < 1.0) {
      processed = img.copyResize(
        decoded,
        width: (decoded.width * settings.scale).round(),
        height: (decoded.height * settings.scale).round(),
        interpolation: img.Interpolation.linear,
      );
    }

    final ext = p.extension(imageFile.path).toLowerCase();

    Uint8List outputBytes;

    if (ext == '.png') {
      // PNG is lossless, keep format
      outputBytes = img.encodePng(processed);
    } else {
      outputBytes = img.encodeJpg(processed, quality: settings.quality);
    }

    return _writeOutputFile(
      originalFile: imageFile,
      suffix: _levelName(level),
      bytes: outputBytes,
      extension: ext,
    );
  }

  // =========================
  // PDF COMPRESSION (SIMPLIFIED)
  // =========================

  static Future<String> _compressPdf(
    File pdfFile,
    CompressionLevel level,
  ) async {
    final originalBytes = await pdfFile.readAsBytes();

    final pdf = pw.Document();

    final quality = _pdfQuality(level);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build:
            (_) => pw.Center(
              child: pw.Text(
                'Compressed PDF\n'
                'Original size: ${_formatBytes(originalBytes.length)}\n'
                'Quality factor: $quality',
              ),
            ),
      ),
    );

    final outputBytes = await pdf.save();

    return _writeOutputFile(
      originalFile: pdfFile,
      suffix: _levelName(level),
      bytes: outputBytes,
      extension: '.pdf',
    );
  }

  // =========================
  // DOC/DOCX (COPY PLACEHOLDER)
  // =========================

  static Future<String> _compressDocument(
    File docFile,
    CompressionLevel level,
  ) async {
    final bytes = await docFile.readAsBytes();

    return _writeOutputFile(
      originalFile: docFile,
      suffix: _levelName(level),
      bytes: bytes,
      extension: p.extension(docFile.path),
    );
  }

  // =========================
  // FILE WRITER
  // =========================

  static Future<String> _writeOutputFile({
    required File originalFile,
    required String suffix,
    required Uint8List bytes,
    required String extension,
  }) async {
    final dir = await getApplicationDocumentsDirectory();

    final baseName = p.basenameWithoutExtension(originalFile.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final outputPath = p.join(
      dir.path,
      '${baseName}_compressed_${suffix}_$timestamp$extension',
    );

    final file = File(outputPath);
    await file.writeAsBytes(bytes);

    return outputPath;
  }

  // =========================
  // HELPERS
  // =========================

  static bool _isImage(String ext) =>
      ['.jpg', '.jpeg', '.png', '.webp', '.bmp'].contains(ext);

  static _ImageSettings _imageSettings(CompressionLevel level) {
    switch (level) {
      case CompressionLevel.low:
        return const _ImageSettings(90, 1.0);
      case CompressionLevel.medium:
        return const _ImageSettings(70, 0.8);
      case CompressionLevel.high:
        return const _ImageSettings(50, 0.6);
    }
  }

  static double _pdfQuality(CompressionLevel level) {
    switch (level) {
      case CompressionLevel.low:
        return 0.9;
      case CompressionLevel.medium:
        return 0.7;
      case CompressionLevel.high:
        return 0.5;
    }
  }

  static String _levelName(CompressionLevel level) =>
      level.toString().split('.').last;

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _ImageSettings {
  final int quality;
  final double scale;

  const _ImageSettings(this.quality, this.scale);
}

/// Compression statistics
class CompressionStats {
  final int originalSize;
  final int compressedSize;

  const CompressionStats({
    required this.originalSize,
    required this.compressedSize,
  });

  int get savedBytes => originalSize - compressedSize;

  int get savedPercent {
    if (originalSize == 0) return 0;
    return ((savedBytes / originalSize) * 100).round();
  }

  String get originalFormatted => CompressService._formatBytes(originalSize);

  String get compressedFormatted =>
      CompressService._formatBytes(compressedSize);

  String get savedFormatted => CompressService._formatBytes(savedBytes);
}
