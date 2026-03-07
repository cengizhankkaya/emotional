import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/core/init/core_localize.dart';
import 'package:emotional/core/services/permission_service.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
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
      'camera': await _permissionService.isCameraGranted,
      'microphone': await _permissionService.isMicrophoneGranted,
      'notification': await Permission.notification.isGranted,
      'gallery': await Permission.photos.isGranted,
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
      case 'camera':
        result = await _permissionService.requestCameraPermission();
        break;
      case 'microphone':
        result = await _permissionService.requestMicrophonePermission();
        break;
      case 'notification':
        result = await _permissionService.requestNotificationPermission();
        break;
      case 'gallery':
        result = await _permissionService.requestPhotoPermission();
        break;
    }

    if (result) {
      await _checkPermissions();
    } else if (mounted) {
      final permission = key == 'camera'
          ? Permission.camera
          : key == 'microphone'
          ? Permission.microphone
          : key == 'notification'
          ? Permission.notification
          : Permission.photos;
      if (await permission.isPermanentlyDenied && mounted) {
        _showSettingsSnackBar();
      }
    }
  }

  void _showRevokeSettingsSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(LocaleKeys.home_feedback_revokeTitle.tr()),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: LocaleKeys.home_permissions_openSettings.tr(),
          onPressed: () => _permissionService.openAppSettings(),
        ),
      ),
    );
  }

  void _showSettingsSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(LocaleKeys.home_feedback_permanentlyDenied.tr()),
        action: SnackBarAction(
          label: LocaleKeys.home_permissions_openSettings.tr(),
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
                            // ── Dil Seçimi ──────────────────────────────
                            _buildLanguageTile(context),
                            const Divider(color: Colors.white12, height: 24),
                            // ── İzinler ─────────────────────────────────
                            _buildPermissionTile(
                              LocaleKeys.settings_camera.tr(),
                              LocaleKeys.settings_cameraSubtitle.tr(),
                              Icons.camera_alt_rounded,
                              _permissionStatuses['camera'] ?? false,
                              (val) => _handlePermissionChange('camera', val),
                            ),
                            _buildPermissionTile(
                              LocaleKeys.settings_microphone.tr(),
                              LocaleKeys.settings_microphoneSubtitle.tr(),
                              Icons.mic_rounded,
                              _permissionStatuses['microphone'] ?? false,
                              (val) =>
                                  _handlePermissionChange('microphone', val),
                            ),
                            _buildPermissionTile(
                              LocaleKeys.settings_notifications.tr(),
                              LocaleKeys.settings_notificationsSubtitle.tr(),
                              Icons.notifications_active_rounded,
                              _permissionStatuses['notification'] ?? false,
                              (val) =>
                                  _handlePermissionChange('notification', val),
                            ),
                            _buildPermissionTile(
                              LocaleKeys.settings_gallery.tr(),
                              LocaleKeys.settings_gallerySubtitle.tr(),
                              Icons.photo_library_rounded,
                              _permissionStatuses['gallery'] ?? false,
                              (val) => _handlePermissionChange('gallery', val),
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
          LocaleKeys.settings_title.tr(),
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

  /// Dil seçimi tile'ı — Türkçe / İngilizce toggle
  Widget _buildLanguageTile(BuildContext context) {
    final currentLocale = context.locale;
    final isTurkish = currentLocale.languageCode == 'tr';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorsCustom.skyBlue.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: const Icon(
          Icons.language_rounded,
          color: ColorsCustom.skyBlue,
        ),
        title: Text(
          LocaleKeys.language_sectionTitle.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          LocaleKeys.language_subtitle.tr(),
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLangButton(
                label: '🇹🇷 TR',
                isSelected: isTurkish,
                onTap: () => _changeLocale(context, AppLocale.tr.locale),
              ),
              _buildLangButton(
                label: '🇺🇸 EN',
                isSelected: !isTurkish,
                onTap: () => _changeLocale(context, AppLocale.en.locale),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLangButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? ColorsCustom.skyBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? ColorsCustom.darkBlue : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _changeLocale(BuildContext context, Locale locale) {
    context.setLocale(locale);
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
        activeThumbColor: ColorsCustom.skyBlue,
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
            child: Text(LocaleKeys.settings_systemSettings.tr()),
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
            child: Text(
              LocaleKeys.button_close.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
