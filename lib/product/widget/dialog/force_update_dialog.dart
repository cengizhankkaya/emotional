import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/core/services/web_version/web_version.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/model/enum/firebase_remote_enums.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Blocks the app until it is updated: from the store on phones, by
/// reloading the page on web.
class ForceUpdateDialog extends StatelessWidget {
  const ForceUpdateDialog({super.key});

  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.esce.emoti';

  /// [context] must be below the app's Navigator.
  static Future<void> show(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ForceUpdateDialog(),
    );
  }

  /// Null when there is nowhere to send the user (iOS without the App
  /// Store link in Remote Config).
  static String? get _storeUrl => switch (defaultTargetPlatform) {
    TargetPlatform.android => _playStoreUrl,
    TargetPlatform.iOS => switch (FirebaseRemoteEnums.iosStoreUrl.valueString
        .trim()) {
      '' => null,
      final url => url,
    },
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final storeUrl = kIsWeb ? null : _storeUrl;
    final message = kIsWeb
        ? LocaleKeys.update_requiredWeb
        : storeUrl != null
        ? LocaleKeys.update_requiredStore
        : LocaleKeys.update_requiredManual;

    // Also keeps the Android back button from closing it.
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(LocaleKeys.update_title.tr()),
        content: Text(message.tr()),
        actions: [
          if (kIsWeb)
            ElevatedButton(
              onPressed: reloadApp,
              child: Text(LocaleKeys.update_reload.tr()),
            )
          else if (storeUrl != null)
            ElevatedButton(
              onPressed: () => launchUrl(
                Uri.parse(storeUrl),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(LocaleKeys.update_update.tr()),
            ),
        ],
      ),
    );
  }
}
