// lib/services/permission_service.dart
//
// Kamera va galereya uchun ruxsat so'rash servisi.

import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  // Kameraga ruxsat so'rash
  static Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  // Galereyadan rasm tanlash uchun ruxsat
  static Future<bool> requestStorage() async {
    // Android 13+ uchun "photos" permission
    final status = await Permission.photos.request();

    // Agar bu yetarli bo'lmasa, storage permission so'raymiz (eski Android)
    if (!status.isGranted) {
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }

    return status.isGranted;
  }
}
