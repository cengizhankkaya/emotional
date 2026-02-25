import 'dart:io';
import 'package:emotional/core/services/permission_service.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:device_info_plus/device_info_plus.dart';

class DownloadPermissionHelper {
  final PermissionService _permissionService;

  DownloadPermissionHelper({PermissionService? permissionService})
    : _permissionService = permissionService ?? PermissionService();

  Future<void> requestInitialPermissions() async {
    if (Platform.isAndroid) {
      await _permissionService.requestNotificationPermission();

      // Storage permissions
      if (await _isAndroid13OrHigher()) {
        // Android 13+ treat Photos and Videos separately
        await _permissionService.requestVideoPermission();
        await _permissionService.requestPhotoPermission();
      } else {
        await _permissionService.requestStoragePermission();
      }

      // Critical for Android 14+: Battery optimizations must be disabled for long background tasks
      bool isOptimizing =
          await ph.Permission.ignoreBatteryOptimizations.isDenied;
      debugPrint(
        'DownloadManager: Battery optimization is ${isOptimizing ? "ENABLED (Bad for background)" : "DISABLED (Good)"}',
      );

      if (isOptimizing) {
        await _permissionService.requestIgnoreBatteryOptimizations();
      }
    }
  }

  Future<bool> _isAndroid13OrHigher() async {
    // SDK 33 is Android 13
    if (Platform.isAndroid) {
      // Simple check using device info or just trusting permission_handler's adaptation
      // permission_handler handles SDK checks internally usually, but 'videos' only exists on 13+
      // To be safe and explicit:
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      return androidInfo.version.sdkInt >= 33;
    }
    return false;
  }

  Future<bool> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      return await _permissionService.requestNotificationPermission();
    }
    return true;
  }
}
