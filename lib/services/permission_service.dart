// lib/services/permission_service.dart
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Camera permission
  static Future<bool> requestCamera() async {
    final status = await Permission.camera.request();

    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      // Settings ga yo'naltirish
      await openAppSettings();
    }

    return false;
  }

  /// Storage permission
  static Future<bool> requestStorage() async {
    // Android 13+ da photos permission
    if (await Permission.photos.isGranted) {
      return true;
    }

    final status = await Permission.photos.request();

    if (status.isGranted) {
      return true;
    }

    // Fallback: storage permission (eski Android)
    if (await Permission.storage.isGranted) {
      return true;
    }

    final storageStatus = await Permission.storage.request();

    if (storageStatus.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied || storageStatus.isPermanentlyDenied) {
      await openAppSettings();
    }

    return false;
  }
}
