import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/call/domain/enums/call_quality_preset.dart';
import 'package:emotional/features/room/presentation/widgets/video_control_sheet/call_device_menu.dart';
import 'package:emotional/features/room/presentation/widgets/video_control_sheet/call_quality_menu.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CallSettingsSheet {
  CallSettingsSheet._();

  static void show(BuildContext context, CallConnected state) {
    final callBloc = context.read<CallBloc>();
    showModalBottomSheet(
      context: context,
      backgroundColor: ColorsCustom.darkABlue,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) => BlocProvider.value(
        value: callBloc,
        child: BlocBuilder<CallBloc, CallState>(
          builder: (context, state) {
            if (state is! CallConnected) return const SizedBox.shrink();
            return _CallSettingsContent(state: state, callBloc: callBloc);
          },
        ),
      ),
    );
  }
}

class _CallSettingsContent extends StatelessWidget {
  final CallConnected state;
  final CallBloc callBloc;

  const _CallSettingsContent({required this.state, required this.callBloc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDragHandle(),
          const SizedBox(height: 16),
          Text(
            LocaleKeys.call_callSettings.tr(),
            style: TextStyle(
              color: Colors.white,
              fontSize: context.dynamicValue(18),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          _SettingsListTile(
            icon: Icons.high_quality_outlined,
            title: LocaleKeys.call_streamQuality.tr(),
            subtitle: state.currentQuality.displayName,
            onTap: () => CallQualityMenu.show(context, callBloc),
          ),
          _SettingsListTile(
            icon: Icons.videocam_outlined,
            title: LocaleKeys.call_camera.tr(),
            subtitle: _deviceLabel(
              state.videoInputs,
              state.selectedVideoInputId,
            ),
            onTap: () => CallDeviceMenu.show(
              context: context,
              type: DeviceMenuType.camera,
              callBloc: callBloc,
            ),
          ),
          _SettingsListTile(
            icon: Icons.mic_none_outlined,
            title: LocaleKeys.call_microphone.tr(),
            subtitle: _deviceLabel(
              state.audioInputs,
              state.selectedAudioInputId,
            ),
            onTap: () => CallDeviceMenu.show(
              context: context,
              type: DeviceMenuType.microphone,
              callBloc: callBloc,
            ),
          ),
          _SettingsListTile(
            icon: Icons.speaker_outlined,
            title: LocaleKeys.call_speaker.tr(),
            subtitle: _deviceLabel(
              state.audioOutputs,
              state.selectedAudioOutputId,
            ),
            onTap: () => CallDeviceMenu.show(
              context: context,
              type: DeviceMenuType.speaker,
              callBloc: callBloc,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _deviceLabel(List devices, String? selectedId) {
    return (devices.where((d) => d.deviceId == selectedId).firstOrNull?.label
            as String?) ??
        LocaleKeys.call_default.tr();
  }

  Widget _buildDragHandle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _SettingsListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: ColorsCustom.skyBlue),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.white30),
      onTap: onTap,
    );
  }
}
