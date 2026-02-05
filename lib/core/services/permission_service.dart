import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

class PermissionService {
  // Singleton pattern
  static final PermissionService _instance = PermissionService._internal();

  factory PermissionService() {
    return _instance;
  }

  PermissionService._internal();

  /// Requests camera permission
  Future<bool> requestCameraPermission() async {
    final status = await ph.Permission.camera.request();
    return _handlePermissionStatus(status);
  }

  /// Requests microphone permission
  Future<bool> requestMicrophonePermission() async {
    final status = await ph.Permission.microphone.request();
    return _handlePermissionStatus(status);
  }

  /// Requests notification permission (Android 13+)
  Future<bool> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final status = await ph.Permission.notification.request();
      return _handlePermissionStatus(status);
    }
    // Notifications are typically handled differently on iOS (via APNS),
    // but permission_handler supports basic request.
    // For now assuming true or handling implicitly for iOS if not strict.
    return true;
  }

  /// Requests storage permission (for Android < 10)
  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      // On Android 13 (SDK 33) and above, permission_group.storage is deprecated.
      // Returning true because we don't need to ask for it.
      if (deviceInfo.version.sdkInt >= 33) {
        return true;
      }

      // But for downloads on old devices, it's key.
      final status = await ph.Permission.storage.request();
      return _handlePermissionStatus(status);
    }
    return true;
  }

  /// Requests both camera and microphone permissions (useful for calls)
  Future<Map<ph.Permission, bool>>
  requestCameraAndMicrophonePermissions() async {
    Map<ph.Permission, ph.PermissionStatus> statuses = await [
      ph.Permission.camera,
      ph.Permission.microphone,
    ].request();

    return {
      ph.Permission.camera: _handlePermissionStatus(
        statuses[ph.Permission.camera]!,
      ),
      ph.Permission.microphone: _handlePermissionStatus(
        statuses[ph.Permission.microphone]!,
      ),
    };
  }

  /// Check if camera permission is granted
  Future<bool> get isCameraGranted async =>
      await ph.Permission.camera.isGranted;

  /// Check if microphone permission is granted
  Future<bool> get isMicrophoneGranted async =>
      await ph.Permission.microphone.isGranted;

  /// Requests ignore battery optimizations (critical for long background downloads)
  Future<bool> requestIgnoreBatteryOptimizations() async {
    if (Platform.isAndroid) {
      final status = await ph.Permission.ignoreBatteryOptimizations.request();
      return _handlePermissionStatus(status);
    }
    return true;
  }

  /// Helper to interpret status
  bool _handlePermissionStatus(ph.PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return true;
    } else {
      // Logic for denied or permanently denied can be handled here or by the caller
      // to show specific UI (dialogs, snackbars).
      return false;
    }
  }

  /// Opens app settings
  Future<bool> openAppSettings() async {
    return await ph.openAppSettings();
  }

  /// Checks if a permission is permanently denied (requires settings to enable)
  Future<bool> isPermanentlyDenied(ph.Permission permission) async {
    return await permission.isPermanentlyDenied;
  }
}
