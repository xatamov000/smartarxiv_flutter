import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum CompressionLevel { low, medium, high }

class CompressService {
  const CompressService._();

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

  // 🔥 PARALLEL + PROGRESS VERSION
  static Future<List<String>> compressMultipleFiles(
    List<File> files,
    CompressionLevel level, {
    void Function(int current, int total)? onProgress,
    int maxParallel = 3,
  }) async {
    final results = <String>[];
    int completed = 0;

    // Parallel limit (CPU overload oldini olish)
    final chunks = <List<File>>[];
    for (int i = 0; i < files.length; i += maxParallel) {
      chunks.add(
        files.sublist(
          i,
          i + maxParallel > files.length ? files.length : i + maxParallel,
        ),
      );
    }

    for (final chunk in chunks) {
      final futures = chunk.map((f) => compressFile(f, level)).toList();

      final compressed = await Future.wait(futures);

      results.addAll(compressed);

      completed += chunk.length;
      onProgress?.call(completed, files.length);
    }

    return results;
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
        interpolation: img.Interpolation.average, // 🔥 tezroq
      );
    }

    final ext = p.extension(imageFile.path).toLowerCase();

    Uint8List outputBytes;

    if (ext == '.png') {
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
  // PDF COMPRESSION (BACKEND)
  // =========================

  static Future<String> _compressPdf(
    File pdfFile,
    CompressionLevel level,
  ) async {
    final uri = Uri.parse("http://10.163.30.170:8000/compress-pdf");

    final request = http.MultipartRequest("POST", uri);

    request.fields['level'] = _levelName(level);

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        pdfFile.path,
        contentType: MediaType('application', 'pdf'),
      ),
    );

    final response = await request.send();

    if (response.statusCode != 200) {
      final errorText = await response.stream.bytesToString();
      throw Exception("Server error: $errorText");
    }

    final bytes = await response.stream.toBytes();

    final dir = await getApplicationDocumentsDirectory();
    final outputPath = p.join(
      dir.path,
      "${p.basenameWithoutExtension(pdfFile.path)}_compressed_${_levelName(level)}_${DateTime.now().millisecondsSinceEpoch}.pdf",
    );

    final outFile = File(outputPath);
    await outFile.writeAsBytes(bytes);

    return outputPath;
  }

  // =========================
  // DOC/DOCX (PLACEHOLDER)
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

  static String _levelName(CompressionLevel level) =>
      level.toString().split('.').last;
}

class _ImageSettings {
  final int quality;
  final double scale;
  const _ImageSettings(this.quality, this.scale);
}
