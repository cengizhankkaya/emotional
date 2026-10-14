import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/call/domain/screen_share/screen_share_options.dart';
import 'package:emotional/features/call/presentation/screen_share/screen_share_sheet.dart';
import 'package:emotional/features/call/presentation/web_call_settings_dialog.dart';
import 'package:emotional/features/call/presentation/screen_share/screen_share_status.dart';
import 'package:emotional/features/room/presentation/widgets/video_control_sheet/call_settings_sheet.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CallControlsBar extends StatelessWidget {
  const CallControlsBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CallBloc, CallState>(
      builder: (context, state) {
        if (state is! CallConnected) return const SizedBox.shrink();

        final isMuted = state.isMuted;
        final isVideoEnabled = state.isCameraOn;
        final isScreenSharing = state.isScreenSharing;
        final activeShare = state.activeScreenShare;

        final controls = Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _CallControlButton(
              // Browsers get one settings dialog; phones keep the sheets.
              onPressed: () => kIsWeb
                  ? WebCallSettingsDialog.show(context)
                  : CallSettingsSheet.show(context, state),
              icon: Icons.settings_outlined,
              label: LocaleKeys.call_settings.tr(),
              color: Colors.white70,
            ),
            _CallControlButton(
              onPressed: () => context.read<CallBloc>().add(ToggleMute()),
              icon: isMuted ? Icons.mic_off : Icons.mic,
              label: isMuted
                  ? LocaleKeys.call_unmute.tr()
                  : LocaleKeys.call_mute.tr(),
              color: isMuted ? Colors.redAccent : Colors.greenAccent,
            ),
            _CallControlButton(
              onPressed: () => context.read<CallBloc>().add(ToggleVideo()),
              icon: isVideoEnabled ? Icons.videocam : Icons.videocam_off,
              label: isVideoEnabled
                  ? LocaleKeys.call_cameraOff.tr()
                  : LocaleKeys.call_cameraOn.tr(),
              color: isVideoEnabled ? Colors.blueAccent : Colors.grey,
            ),
            _CallControlButton(
              onPressed: () => ScreenShareLauncher.toggle(context),
              icon: isScreenSharing
                  ? Icons.stop_screen_share
                  : Icons.screen_share,
              label: isScreenSharing
                  ? LocaleKeys.call_stopSharing.tr()
                  : LocaleKeys.call_startSharing.tr(),
              color: isScreenSharing
                  ? Colors.orangeAccent
                  : ColorsCustom.skyBlue,
              // The full status only peeks in briefly; the dot and the
              // tooltip keep it reachable afterwards.
              showLiveDot: activeShare != null,
              tooltip: activeShare == null
                  ? null
                  : ScreenShareStatus.summary(activeShare),
            ),
          ],
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ShareStatusPeek(share: activeShare),
            controls,
          ],
        );
      },
    );
  }
}

/// Shows the share status for a few seconds when a share starts or changes,
/// then folds away so it doesn't sit on top of the shared screen.
class _ShareStatusPeek extends StatefulWidget {
  const _ShareStatusPeek({required this.share});

  final ActiveScreenShare? share;

  @override
  State<_ShareStatusPeek> createState() => _ShareStatusPeekState();
}

class _ShareStatusPeekState extends State<_ShareStatusPeek> {
  static const _visibleFor = Duration(seconds: 5);

  Timer? _hideTimer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (widget.share != null) _peek();
  }

  @override
  void didUpdateWidget(_ShareStatusPeek oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.share == oldWidget.share) return;
    if (widget.share == null) {
      _hideTimer?.cancel();
      _visible = false;
    } else {
      _peek();
    }
  }

  void _peek() {
    _visible = true;
    _hideTimer?.cancel();
    _hideTimer = Timer(_visibleFor, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final share = widget.share;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignment: Alignment.bottomCenter,
      child: _visible && share != null
          ? Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ScreenShareStatus(share: share),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _CallControlButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color color;
  final bool showLiveDot;
  final String? tooltip;

  const _CallControlButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
    this.showLiveDot = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: onPressed,
              tooltip: tooltip,
              icon: Icon(icon),
              color: color,
              style: IconButton.styleFrom(
                backgroundColor: color.withValues(alpha: 0.1),
                padding: const EdgeInsets.all(10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: color.withValues(alpha: 0.2)),
                ),
              ),
            ),
            if (showLiveDot)
              const Positioned(
                top: 2,
                right: 2,
                child: IgnorePointer(child: LiveDot(size: 9)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: context.dynamicValue(10),
          ),
        ),
      ],
    );
  }
}
