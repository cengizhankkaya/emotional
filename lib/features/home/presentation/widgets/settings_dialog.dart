import 'dart:ui';
import 'package:emotional/core/services/permission_service.dart';
import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const SettingsDialog(),
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog>
    with WidgetsBindingObserver {
  final _permissionService = PermissionService();

  Map<String, bool> _permissionStatuses = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final statuses = {
      'Kamera': await _permissionService.isCameraGranted,
      'Mikrofon': await _permissionService.isMicrophoneGranted,
      'Bildirim': await Permission.notification.isGranted,
      'Pil': await Permission.ignoreBatteryOptimizations.isGranted,
      'Galeri': await Permission.photos.isGranted,
    };

    if (mounted) {
      setState(() {
        _permissionStatuses = statuses;
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePermissionChange(String key, bool value) async {
    if (value == false) {
      _showRevokeSettingsSnackBar();
      return;
    }

    bool result = false;
    switch (key) {
      case 'Kamera':
        result = await _permissionService.requestCameraPermission();
        break;
      case 'Mikrofon':
        result = await _permissionService.requestMicrophonePermission();
        break;
      case 'Bildirim':
        result = await _permissionService.requestNotificationPermission();
        break;
      case 'Pil':
        result = await _permissionService.requestIgnoreBatteryOptimizations();
        break;
      case 'Galeri':
        result = await _permissionService.requestPhotoPermission();
        break;
    }

    if (result) {
      await _checkPermissions();
    } else if (mounted) {
      Permission p;
      switch (key) {
        case 'Kamera':
          p = Permission.camera;
          break;
        case 'Mikrofon':
          p = Permission.microphone;
          break;
        case 'Bildirim':
          p = Permission.notification;
          break;
        case 'Pil':
          p = Permission.ignoreBatteryOptimizations;
          break;
        case 'Galeri':
          p = Permission.photos;
          break;
        default:
          return;
      }

      if (await p.isPermanentlyDenied && mounted) {
        _showSettingsSnackBar();
      }
    }
  }

  void _showRevokeSettingsSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'İzinleri iptal etmek için sistem ayarlarını kullanmanız gerekir.',
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Ayarlar',
          onPressed: () => _permissionService.openAppSettings(),
        ),
      ),
    );
  }

  void _showSettingsSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Bu izin kalıcı olarak reddedilmiş. Ayarlardan açmanız gerekiyor.',
        ),
        action: SnackBarAction(
          label: 'Ayarlar',
          onPressed: () => _permissionService.openAppSettings(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            constraints: BoxConstraints(maxHeight: context.dynamicHeight(0.8)),
            decoration: BoxDecoration(
              color: ColorsCustom.darkBlue.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const ProjectPadding.allLarge(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(context),
                  const Divider(color: Colors.white12, height: 32),
                  if (_isLoading)
                    const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildPermissionTile(
                              'Kamera',
                              'Görüntülü görüşmeler için',
                              Icons.camera_alt_rounded,
                              _permissionStatuses['Kamera'] ?? false,
                              (val) => _handlePermissionChange('Kamera', val),
                            ),
                            _buildPermissionTile(
                              'Mikrofon',
                              'Sesli görüşmeler için',
                              Icons.mic_rounded,
                              _permissionStatuses['Mikrofon'] ?? false,
                              (val) => _handlePermissionChange('Mikrofon', val),
                            ),
                            _buildPermissionTile(
                              'Bildirimler',
                              'İndirme durumları için',
                              Icons.notifications_active_rounded,
                              _permissionStatuses['Bildirim'] ?? false,
                              (val) => _handlePermissionChange('Bildirim', val),
                            ),
                            _buildPermissionTile(
                              'Galeri Erişimi',
                              'Video seçimi için',
                              Icons.photo_library_rounded,
                              _permissionStatuses['Galeri'] ?? false,
                              (val) => _handlePermissionChange('Galeri', val),
                            ),
                            _buildPermissionTile(
                              'Pil Optimizasyonu',
                              'Kesintisiz arka plan işlemleri',
                              Icons.battery_saver_rounded,
                              _permissionStatuses['Pil'] ?? false,
                              (val) => _handlePermissionChange('Pil', val),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  _buildFooterActions(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.settings_outlined,
          color: ColorsCustom.skyBlue,
          size: 28,
        ),
        const SizedBox(width: 12),
        Text(
          'Ayarlar',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildPermissionTile(
    String title,
    String subtitle,
    IconData icon,
    bool isGranted,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.2),
        ),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: isGranted ? Colors.green : Colors.white70),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
        value: isGranted,
        onChanged: onChanged,
        activeColor: ColorsCustom.skyBlue,
        activeTrackColor: ColorsCustom.skyBlue.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildFooterActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _permissionService.openAppSettings(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Sistem Ayarları'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorsCustom.skyBlue,
              foregroundColor: ColorsCustom.darkBlue,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Kapat',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
