import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/room/presentation/widgets/video_control_sheet/call_settings_sheet.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
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
        final isVideoEnabled = state.isVideoEnabled;
        final isScreenSharing = state.isScreenSharing;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _CallControlButton(
              onPressed: () => CallSettingsSheet.show(context, state),
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
              onPressed: () =>
                  context.read<CallBloc>().add(ToggleScreenShare()),
              icon: isScreenSharing
                  ? Icons.stop_screen_share
                  : Icons.screen_share,
              label: isScreenSharing
                  ? LocaleKeys.call_stopSharing.tr()
                  : LocaleKeys.call_startSharing.tr(),
              color: isScreenSharing
                  ? Colors.orangeAccent
                  : ColorsCustom.skyBlue,
            ),
          ],
        );
      },
    );
  }
}

class _CallControlButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color color;

  const _CallControlButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
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
