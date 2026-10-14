import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/core/manager/cache_manager.dart';
import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/call/domain/screen_share/screen_share_options.dart';
import 'package:emotional/features/call/service/screen_share/browser_screen_capture.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:emotional/product/widget/selectable_pill.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Entry point for the "share screen" button.
///
/// On web, starting a share first asks what is being shared so the capture,
/// encoder and audio can be tuned for it. Stopping, and mobile, toggle
/// directly as before.
abstract final class ScreenShareLauncher {
  static Future<void> toggle(BuildContext context) async {
    final callBloc = context.read<CallBloc>();
    final state = callBloc.state;
    final isSharing = state is CallConnected && state.isScreenSharing;
    if (!kIsWeb || isSharing) {
      callBloc.add(const ToggleScreenShare());
      return;
    }

    final capabilities = BrowserScreenCapture.capabilities;
    if (!capabilities.isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.call_screenShare_notSupported.tr())),
      );
      return;
    }

    final options = await ScreenShareSheet.show(context, capabilities);
    if (options != null) callBloc.add(ToggleScreenShare(options: options));
  }
}

class ScreenShareSheet extends StatefulWidget {
  const ScreenShareSheet._({
    required this.initialOptions,
    required this.capabilities,
  });

  final ScreenShareOptions initialOptions;
  final ScreenShareCapabilities capabilities;

  /// Returns the chosen options, or null if the sheet was dismissed.
  static Future<ScreenShareOptions?> show(
    BuildContext context,
    ScreenShareCapabilities capabilities,
  ) async {
    final saved = await CacheManager().getScreenShareOptions();
    if (!context.mounted) return null;
    // Drop remembered choices this browser can't honour.
    final initial = saved.copyWith(
      shareAudio: saved.shareAudio && capabilities.canShareAudio,
      preferredSurface: capabilities.canPreferSurface
          ? saved.preferredSurface
          : ScreenShareSurface.any,
    );
    return showModalBottomSheet<ScreenShareOptions>(
      context: context,
      backgroundColor: ColorsCustom.darkABlue,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ScreenShareSheet._(
        initialOptions: initial,
        capabilities: capabilities,
      ),
    );
  }

  @override
  State<ScreenShareSheet> createState() => _ScreenShareSheetState();
}

class _ScreenShareSheetState extends State<ScreenShareSheet> {
  late ScreenShareOptions _options = widget.initialOptions;

  void _start() {
    unawaited(CacheManager().saveScreenShareOptions(_options));
    // Pop straight away: getDisplayMedia must run while this tap still counts
    // as a user gesture.
    Navigator.of(context).pop(_options);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _DragHandle(),
            const SizedBox(height: 16),
            const _Header(),
            const SizedBox(height: 24),
            ScreenShareOptionsForm(
              options: _options,
              capabilities: widget.capabilities,
              onChanged: (options) => setState(() => _options = options),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.screen_share),
                label: Text(
                  LocaleKeys.call_screenShare_start.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorsCustom.cream,
                  foregroundColor: ColorsCustom.darkBlue,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: ProjectRadius.medium(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Content type, source and audio choices for a browser screen share. Used
/// by the share sheet and by the web call settings (as defaults).
class ScreenShareOptionsForm extends StatelessWidget {
  const ScreenShareOptionsForm({
    super.key,
    required this.options,
    required this.capabilities,
    required this.onChanged,
  });

  final ScreenShareOptions options;
  final ScreenShareCapabilities capabilities;
  final ValueChanged<ScreenShareOptions> onChanged;

  void _setAudio(bool enabled) {
    onChanged(
      options.copyWith(
        shareAudio: enabled,
        // Browsers capture audio from tabs, so steer the picker there.
        preferredSurface:
            enabled &&
                capabilities.canPreferSurface &&
                options.preferredSurface == ScreenShareSurface.any
            ? ScreenShareSurface.browser
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(LocaleKeys.call_screenShare_contentType.tr()),
        for (final profile in ScreenShareProfile.values)
          _ProfileTile(
            profile: profile,
            selected: options.profile == profile,
            onTap: () => onChanged(options.copyWith(profile: profile)),
          ),
        if (capabilities.canPreferSurface) ...[
          const SizedBox(height: 16),
          _SectionLabel(LocaleKeys.call_screenShare_source.tr()),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final surface in ScreenShareSurface.values)
                _SurfaceChip(
                  surface: surface,
                  selected: options.preferredSurface == surface,
                  onSelected: () =>
                      onChanged(options.copyWith(preferredSurface: surface)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _AudioTile(
          value: options.shareAudio,
          supported: capabilities.canShareAudio,
          onChanged: _setAudio,
        ),
      ],
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ColorsCustom.skyBlue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.screen_share, color: ColorsCustom.skyBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LocaleKeys.call_screenShare_title.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                LocaleKeys.call_screenShare_subtitle.tr(),
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  final ScreenShareProfile profile;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (profile) {
    ScreenShareProfile.detail => Icons.article_outlined,
    ScreenShareProfile.motion => Icons.movie_outlined,
    ScreenShareProfile.balanced => Icons.tune,
  };

  @override
  Widget build(BuildContext context) {
    final accent = selected ? ColorsCustom.skyBlue : Colors.white54;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? ColorsCustom.skyBlue.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? ColorsCustom.skyBlue : ColorsCustom.white10,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(_icon, color: accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile.description,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: accent,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SurfaceChip extends StatelessWidget {
  const _SurfaceChip({
    required this.surface,
    required this.selected,
    required this.onSelected,
  });

  final ScreenShareSurface surface;
  final bool selected;
  final VoidCallback onSelected;

  IconData get _icon => switch (surface) {
    ScreenShareSurface.any => Icons.auto_awesome_outlined,
    ScreenShareSurface.browser => Icons.tab_outlined,
    ScreenShareSurface.window => Icons.web_asset_outlined,
    ScreenShareSurface.monitor => Icons.desktop_windows_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return SelectablePill(
      icon: _icon,
      label: surface.title,
      selected: selected,
      onTap: onSelected,
    );
  }
}

class _AudioTile extends StatelessWidget {
  const _AudioTile({
    required this.value,
    required this.supported,
    required this.onChanged,
  });

  final bool value;
  final bool supported;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorsCustom.white10),
      ),
      child: Row(
        children: [
          Icon(
            supported ? Icons.volume_up_outlined : Icons.volume_off_outlined,
            color: supported ? Colors.white70 : Colors.white38,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleKeys.call_screenShare_shareAudio.tr(),
                  style: TextStyle(
                    color: supported ? Colors.white : Colors.white38,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  supported
                      ? LocaleKeys.call_screenShare_shareAudioDesc.tr()
                      : LocaleKeys.call_screenShare_shareAudioUnsupported.tr(),
                  style: TextStyle(
                    color: supported ? Colors.white60 : Colors.orangeAccent,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: supported ? onChanged : null,
            activeThumbColor: ColorsCustom.skyBlue,
            inactiveThumbColor: Colors.white54,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
            trackOutlineColor: const WidgetStatePropertyAll(
              ColorsCustom.white10,
            ),
          ),
        ],
      ),
    );
  }
}
