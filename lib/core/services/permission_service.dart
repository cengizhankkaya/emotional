import 'dart:async';
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

  // Lock to prevent concurrent permission requests
  bool _isRequesting = false;
  Completer<void>? _currentRequest;

  Future<void> _waitForLock() async {
    while (_isRequesting) {
      _currentRequest ??= Completer<void>();
      await _currentRequest!.future;
    }
    _isRequesting = true;
  }

  void _releaseLock() {
    _isRequesting = false;
    _currentRequest?.complete();
    _currentRequest = null;
  }

  /// Requests camera permission
  Future<bool> requestCameraPermission() async {
    await _waitForLock();
    try {
      final status = await ph.Permission.camera.request();
      return _handlePermissionStatus(status);
    } finally {
      _releaseLock();
    }
  }

  /// Requests microphone permission
  Future<bool> requestMicrophonePermission() async {
    await _waitForLock();
    try {
      final status = await ph.Permission.microphone.request();
      return _handlePermissionStatus(status);
    } finally {
      _releaseLock();
    }
  }

  /// Requests notification permission (Android 13+)
  Future<bool> requestNotificationPermission() async {
    await _waitForLock();
    try {
      final status = await ph.Permission.notification.request();
      return _handlePermissionStatus(status);
    } finally {
      _releaseLock();
    }
  }

  /// Requests storage permission (for Android < 10)
  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      if (deviceInfo.version.sdkInt >= 33) {
        return true;
      }

      await _waitForLock();
      try {
        final status = await ph.Permission.storage.request();
        return _handlePermissionStatus(status);
      } finally {
        _releaseLock();
      }
    }
    return true;
  }

  /// Requests both camera and microphone permissions (useful for calls)
  Future<Map<ph.Permission, bool>>
  requestCameraAndMicrophonePermissions() async {
    await _waitForLock();
    try {
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
    } finally {
      _releaseLock();
    }
  }

  /// Check if camera permission is granted
  Future<bool> get isCameraGranted async =>
      await ph.Permission.camera.isGranted;

  /// Check if microphone permission is granted
  Future<bool> get isMicrophoneGranted async =>
      await ph.Permission.microphone.isGranted;

  /// Both camera AND microphone are granted
  Future<bool> get areCallPermissionsGranted async {
    final cam = await ph.Permission.camera.isGranted;
    final mic = await ph.Permission.microphone.isGranted;
    return cam && mic;
  }

  /// Kamera veya mikrofon kalıcı olarak reddedilmiş mi?
  Future<bool> get isCameraOrMicPermanentlyDenied async {
    final cam = await ph.Permission.camera.isPermanentlyDenied;
    final mic = await ph.Permission.microphone.isPermanentlyDenied;
    return cam || mic;
  }

  /// Batarya optimizasyon izni isteği devre dışı bırakıldı.
  /// Kullanıcıya sistem diyalogu gösterilmez.
  Future<bool> requestIgnoreBatteryOptimizations() async {
    return false;
  }

  /// Requests video permission (Android 13+)
  Future<bool> requestVideoPermission() async {
    if (Platform.isAndroid) {
      await _waitForLock();
      try {
        final status = await ph.Permission.videos.request();
        return _handlePermissionStatus(status);
      } finally {
        _releaseLock();
      }
    }
    return true;
  }

  /// Requests photo permission (Android 13+)
  Future<bool> requestPhotoPermission() async {
    if (Platform.isAndroid) {
      await _waitForLock();
      try {
        final status = await ph.Permission.photos.request();
        return _handlePermissionStatus(status);
      } finally {
        _releaseLock();
      }
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
