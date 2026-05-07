import 'dart:async';
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:path/path.dart' as path;

class GoogleDriveService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  drive.DriveApi? _driveApi;

  Future<bool> signIn() async {
    try {
      // eski sessionni o'chiramiz
      await _googleSignIn.signOut();

      final account = await _googleSignIn.signIn();

      if (account == null) return false;

      final auth.AuthClient? client = await _googleSignIn.authenticatedClient();

      if (client == null) return false;

      _driveApi = drive.DriveApi(client);

      return true;
    } catch (e) {
      print("Drive signIn error: $e");
      return false;
    }
  }

  Future<String> _getOrCreateFolder(String folderName) async {
    final query =
        "name='$folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false";

    final fileList = await _driveApi!.files.list(q: query);

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      return fileList.files!.first.id!;
    }

    final folder =
        drive.File()
          ..name = folderName
          ..mimeType = 'application/vnd.google-apps.folder';

    final created = await _driveApi!.files.create(folder);

    return created.id!;
  }

  /// UPLOAD WITH PROGRESS
  Future<String?> uploadFile(
    File file,
    Function(double progress) onProgress,
  ) async {
    if (_driveApi == null) throw Exception("Drive ulanmagan");

    final folderId = await _getOrCreateFolder("SmartArchive");

    final totalBytes = await file.length();
    int uploaded = 0;

    final stream = file.openRead().transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (data, sink) {
          uploaded += data.length;

          final progress = uploaded / totalBytes;
          onProgress(progress);

          sink.add(data);
        },
      ),
    );

    final driveFile =
        drive.File()
          ..name = path.basename(file.path)
          ..parents = [folderId];

    final media = drive.Media(stream, totalBytes);

    final uploadedFile = await _driveApi!.files.create(
      driveFile,
      uploadMedia: media,
    );

    return uploadedFile.id;
  }

  Future<String?> getShareableLink(String fileId) async {
    final permission =
        drive.Permission()
          ..type = 'anyone'
          ..role = 'reader';

    await _driveApi!.permissions.create(permission, fileId);

    final file =
        await _driveApi!.files.get(fileId, $fields: "webViewLink")
            as drive.File;

    return file.webViewLink;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}

