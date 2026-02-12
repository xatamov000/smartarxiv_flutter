// lib/services/google_drive_service.dart
// ☁️ Google Drive ga fayl yuklash xizmati

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class GoogleDriveService {
  static const _scopes = [drive.DriveApi.driveFileScope];

  drive.DriveApi? _driveApi;
  AutoRefreshingAuthClient? _authClient;

  /// Google Drive autentifikatsiya
  ///
  /// [credentialsJson] - Google Cloud Console'dan olingan credentials
  Future<bool> authenticate(String credentialsJson) async {
    try {
      final credentials = ServiceAccountCredentials.fromJson(
        json.decode(credentialsJson),
      );

      final client = http.Client();
      _authClient = await clientViaServiceAccount(credentials, _scopes);
      _driveApi = drive.DriveApi(_authClient!);

      return true;
    } catch (e) {
      print("❌ Drive auth xatolik: $e");
      return false;
    }
  }

  /// Faylni Google Drive ga yuklash
  ///
  /// [file] - Yuklanishi kerak bo'lgan fayl
  /// [folderName] - Drive'dagi papka nomi (ixtiyoriy)
  /// Returns: Yuklangan faylning Drive ID si
  Future<String> uploadFile(File file, {String? folderName}) async {
    if (_driveApi == null) {
      throw Exception(
        "Google Drive ga ulanilmagan. Avval authenticate() chaqiring.",
      );
    }

    try {
      String? folderId;

      // Agar papka nomi berilgan bo'lsa, papka yaratish yoki topish
      if (folderName != null) {
        folderId = await _getOrCreateFolder(folderName);
      }

      // Fayl metadata
      final driveFile =
          drive.File()
            ..name = path.basename(file.path)
            ..mimeType = _getMimeType(file.path);

      // Agar papka ID bor bo'lsa, qo'shish
      if (folderId != null) {
        driveFile.parents = [folderId];
      }

      // Faylni yuklash
      final media = drive.Media(file.openRead(), file.lengthSync());
      final response = await _driveApi!.files.create(
        driveFile,
        uploadMedia: media,
      );

      return response.id ?? '';
    } catch (e) {
      throw Exception("Drive ga yuklash xatolik: $e");
    }
  }

  /// Bir nechta faylni yuklash
  Future<List<String>> uploadFiles(
    List<File> files, {
    String? folderName,
    Function(int current, int total)? onProgress,
  }) async {
    final uploadedIds = <String>[];

    for (int i = 0; i < files.length; i++) {
      final id = await uploadFile(files[i], folderName: folderName);
      uploadedIds.add(id);

      if (onProgress != null) {
        onProgress(i + 1, files.length);
      }
    }

    return uploadedIds;
  }

  /// Papka yaratish yoki mavjud papkani topish
  Future<String> _getOrCreateFolder(String folderName) async {
    if (_driveApi == null) {
      throw Exception("Drive API initialized emas");
    }

    try {
      // Avval papka borligini tekshirish
      final query =
          "name='$folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false";
      final fileList = await _driveApi!.files.list(q: query, spaces: 'drive');

      // Agar papka topilsa
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id!;
      }

      // Agar yo'q bo'lsa, yangi papka yaratish
      final folder =
          drive.File()
            ..name = folderName
            ..mimeType = 'application/vnd.google-apps.folder';

      final createdFolder = await _driveApi!.files.create(folder);
      return createdFolder.id!;
    } catch (e) {
      throw Exception("Papka yaratish xatolik: $e");
    }
  }

  /// Fayl MIME type ni aniqlash
  String _getMimeType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();

    switch (ext) {
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.zip':
        return 'application/zip';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  /// Drive dan faylni o'chirish
  Future<bool> deleteFile(String fileId) async {
    if (_driveApi == null) {
      throw Exception("Drive API initialized emas");
    }

    try {
      await _driveApi!.files.delete(fileId);
      return true;
    } catch (e) {
      print("❌ Drive delete xatolik: $e");
      return false;
    }
  }

  /// Barcha fayllar ro'yxatini olish
  Future<List<drive.File>> listFiles({
    String? folderId,
    int maxResults = 100,
  }) async {
    if (_driveApi == null) {
      throw Exception("Drive API initialized emas");
    }

    try {
      String query = "trashed=false";

      if (folderId != null) {
        query += " and '$folderId' in parents";
      }

      final fileList = await _driveApi!.files.list(
        q: query,
        pageSize: maxResults,
        orderBy: 'modifiedTime desc',
        $fields: 'files(id, name, mimeType, size, modifiedTime)',
      );

      return fileList.files ?? [];
    } catch (e) {
      throw Exception("Drive list xatolik: $e");
    }
  }

  /// Ulanishni yopish
  void dispose() {
    _authClient?.close();
  }

  /// Public link olish
  Future<String> getShareableLink(String fileId) async {
    if (_driveApi == null) {
      throw Exception("Drive API initialized emas");
    }

    try {
      // Faylni public qilish
      final permission =
          drive.Permission()
            ..type = 'anyone'
            ..role = 'reader';

      await _driveApi!.permissions.create(permission, fileId);

      // Link olish
      final file =
          await _driveApi!.files.get(fileId, $fields: 'webViewLink')
              as drive.File;

      return file.webViewLink ?? '';
    } catch (e) {
      throw Exception("Link olish xatolik: $e");
    }
  }
}
