import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/core/services/browser_media_permission/browser_media_permission.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Camera and microphone permission for the browser build.
///
/// The explanation is shown once per browser. After that a room action asks
/// the browser directly, because Safari forgets the choice on every visit
/// and showing our dialog each time would add a pointless extra step. A
/// blocked permission always gets the dialog with the steps to unblock it.
abstract final class WebCallPermissions {
  static const String _introSeenKey = 'web_permission_intro_seen';

  /// Resolves to true when the user can enter a call.
  static Future<bool> ensure(BuildContext context) async {
    final state = await queryBrowserMediaPermission();
    if (state == BrowserMediaPermission.granted) return true;
    if (!context.mounted) return false;

    if (state == BrowserMediaPermission.denied) {
      await _show(context, blocked: true);
      return false;
    }

    if (!await _introSeen()) {
      if (!context.mounted) return false;
      return await _show(context, blocked: false);
    }

    final result = await requestBrowserMediaPermission();
    if (!context.mounted) return false;
    return _handleResult(context, result);
  }

  /// Explains the permission on the first visit, before any room action.
  static Future<void> introduceOnce(BuildContext context) async {
    if (await _introSeen()) return;
    final state = await queryBrowserMediaPermission();
    if (state != BrowserMediaPermission.prompt || !context.mounted) return;
    await _show(context, blocked: false);
  }

  static Future<bool> _introSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_introSeenKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _markIntroSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_introSeenKey, true);
    } catch (_) {
      // Only means the explanation shows again next time.
    }
  }

  static Future<bool> _show(BuildContext context, {required bool blocked}) {
    if (!blocked) _markIntroSeen();
    return showDialog<bool>(
      context: context,
      builder: (_) => _WebPermissionDialog(startBlocked: blocked),
    ).then((granted) => granted ?? false);
  }

  static Future<bool> _handleResult(
    BuildContext context,
    BrowserMediaPermission result,
  ) async {
    switch (result) {
      case BrowserMediaPermission.granted:
        return true;
      case BrowserMediaPermission.noDevice:
        // Watching still works without a camera or microphone.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocaleKeys.web_permNoDevice.tr())),
        );
        return true;
      case BrowserMediaPermission.denied:
        await _show(context, blocked: true);
        return false;
      case BrowserMediaPermission.prompt:
        // The prompt was dismissed without a choice.
        return false;
    }
  }
}

class _WebPermissionDialog extends StatefulWidget {
  const _WebPermissionDialog({required this.startBlocked});

  final bool startBlocked;

  @override
  State<_WebPermissionDialog> createState() => _WebPermissionDialogState();
}

class _WebPermissionDialogState extends State<_WebPermissionDialog> {
  late bool _blocked = widget.startBlocked;
  bool _requesting = false;

  Future<void> _allow() async {
    setState(() => _requesting = true);
    final result = await requestBrowserMediaPermission();
    if (!mounted) return;
    switch (result) {
      case BrowserMediaPermission.granted:
        Navigator.of(context).pop(true);
      case BrowserMediaPermission.noDevice:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocaleKeys.web_permNoDevice.tr())),
        );
        Navigator.of(context).pop(true);
      case BrowserMediaPermission.denied:
        setState(() {
          _requesting = false;
          _blocked = true;
        });
      case BrowserMediaPermission.prompt:
        setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ColorsCustom.darkABlue,
      insetPadding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(maxWidth: 460),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: ColorsCustom.white10),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: _blocked ? _buildBlocked() : _buildIntro(),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: _DeviceBadges()),
        const SizedBox(height: 20),
        _Title(LocaleKeys.web_permTitle.tr()),
        const SizedBox(height: 8),
        _Body(LocaleKeys.web_permSubtitle.tr()),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _FeatureCard(
                icon: Icons.videocam_outlined,
                title: LocaleKeys.web_permCameraTitle.tr(),
                description: LocaleKeys.web_permCameraDesc.tr(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FeatureCard(
                icon: Icons.mic_none_rounded,
                title: LocaleKeys.web_permMicTitle.tr(),
                description: LocaleKeys.web_permMicDesc.tr(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Note(
          icon: Icons.touch_app_outlined,
          text: LocaleKeys.web_permBrowserHint.tr(),
        ),
        const SizedBox(height: 8),
        _Note(
          icon: Icons.lock_outline_rounded,
          text: LocaleKeys.web_permPrivacy.tr(),
        ),
        const SizedBox(height: 24),
        _Actions(
          secondaryLabel: LocaleKeys.web_permLater.tr(),
          onSecondary: _requesting
              ? null
              : () => Navigator.of(context).pop(false),
          primary: FilledButton.icon(
            onPressed: _requesting ? null : _allow,
            style: _primaryStyle,
            icon: _requesting
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 20),
            label: Text(
              _requesting
                  ? LocaleKeys.web_permWaiting.tr()
                  : LocaleKeys.web_permAllow.tr(),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlocked() {
    final steps = [
      isSafariBrowser
          ? LocaleKeys.web_permDeniedSafariStep1.tr()
          : LocaleKeys.web_permDeniedStep1.tr(),
      LocaleKeys.web_permDeniedStep2.tr(),
      LocaleKeys.web_permDeniedStep3.tr(),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.videocam_off_outlined,
              color: Colors.orangeAccent,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 20),
        _Title(LocaleKeys.web_permDeniedTitle.tr()),
        const SizedBox(height: 8),
        _Body(LocaleKeys.web_permDeniedDesc.tr()),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (final (index, step) in steps.indexed) ...[
                if (index > 0) const SizedBox(height: 12),
                _Step(number: index + 1, text: step),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        _Actions(
          secondaryLabel: LocaleKeys.button_close.tr(),
          onSecondary: () => Navigator.of(context).pop(false),
          primary: FilledButton.icon(
            onPressed: reloadPage,
            style: _primaryStyle,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: Text(LocaleKeys.web_permReload.tr()),
          ),
        ),
      ],
    );
  }

  static final ButtonStyle _primaryStyle = FilledButton.styleFrom(
    backgroundColor: ColorsCustom.skyBlue,
    foregroundColor: ColorsCustom.darkBlue,
    disabledBackgroundColor: ColorsCustom.skyBlue.withValues(alpha: 0.35),
    disabledForegroundColor: Colors.white70,
    minimumSize: const Size(0, 48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
  );
}

/// Camera and microphone icons side by side.
class _DeviceBadges extends StatelessWidget {
  const _DeviceBadges();

  @override
  Widget build(BuildContext context) {
    Widget badge(IconData icon) => Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: ColorsCustom.darkABlue,
        shape: BoxShape.circle,
        border: Border.all(color: ColorsCustom.darkABlue, width: 4),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: ColorsCustom.skyBlue.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: ColorsCustom.skyBlue, size: 26),
      ),
    );

    return SizedBox(
      width: 104,
      height: 60,
      child: Stack(
        children: [
          Positioned(left: 0, child: badge(Icons.videocam_rounded)),
          Positioned(right: 0, child: badge(Icons.mic_rounded)),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.45),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorsCustom.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ColorsCustom.skyBlue, size: 22),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: const TextStyle(color: Colors.white54, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: Colors.white38),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ColorsCustom.skyBlue.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              color: ColorsCustom.skyBlue,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.secondaryLabel,
    required this.onSecondary,
    required this.primary,
  });

  final String secondaryLabel;
  final VoidCallback? onSecondary;
  final Widget primary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TextButton(
          onPressed: onSecondary,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white70,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: Text(secondaryLabel),
        ),
        const SizedBox(width: 8),
        Expanded(child: primary),
      ],
    );
  }
}
