import 'dart:io';
import 'package:emotional/core/services/permission_service.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

class DownloadPermissionHelper {
  final PermissionService _permissionService;

  DownloadPermissionHelper({PermissionService? permissionService})
    : _permissionService = permissionService ?? PermissionService();

  Future<void> requestInitialPermissions() async {
    if (Platform.isAndroid) {
      await _permissionService.requestNotificationPermission();
      await _permissionService.requestStoragePermission();

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

  Future<bool> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      return await _permissionService.requestNotificationPermission();
    }
    return true;
  }
}
