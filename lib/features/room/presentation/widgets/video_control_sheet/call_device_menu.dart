import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Hangi cihaz menüsünün açıldığını belirtir.
enum DeviceMenuType { camera, microphone, speaker }

class CallDeviceMenu {
  CallDeviceMenu._();

  static void show({
    required BuildContext context,
    required DeviceMenuType type,
    required CallBloc callBloc,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColorsCustom.darkABlue,
      isScrollControlled: true,
      builder: (modalContext) => BlocProvider.value(
        value: callBloc,
        child: BlocBuilder<CallBloc, CallState>(
          builder: (context, state) {
            if (state is! CallConnected) return const SizedBox.shrink();

            final title = _titleForType(type);
            final devices = _devicesForType(type, state);
            final currentId = _currentIdForType(type, state);

            return _CallDeviceMenuContent(
              title: title,
              devices: devices,
              currentId: currentId,
              onSelected: (d) => callBloc.add(_eventForType(type, d)),
              callBloc: callBloc,
              state: state,
            );
          },
        ),
      ),
    );
  }

  static String _titleForType(DeviceMenuType type) {
    switch (type) {
      case DeviceMenuType.camera:
        return LocaleKeys.call_cameraSelect.tr();
      case DeviceMenuType.microphone:
        return LocaleKeys.call_microphoneSelect.tr();
      case DeviceMenuType.speaker:
        return LocaleKeys.call_speakerSelect.tr();
    }
  }

  static List<MediaDeviceInfo> _devicesForType(
    DeviceMenuType type,
    CallConnected state,
  ) {
    switch (type) {
      case DeviceMenuType.camera:
        return state.videoInputs;
      case DeviceMenuType.microphone:
        return state.audioInputs;
      case DeviceMenuType.speaker:
        return state.audioOutputs;
    }
  }

  static String? _currentIdForType(DeviceMenuType type, CallConnected state) {
    switch (type) {
      case DeviceMenuType.camera:
        return state.selectedVideoInputId;
      case DeviceMenuType.microphone:
        return state.selectedAudioInputId;
      case DeviceMenuType.speaker:
        return state.selectedAudioOutputId;
    }
  }

  static dynamic _eventForType(DeviceMenuType type, MediaDeviceInfo device) {
    switch (type) {
      case DeviceMenuType.camera:
        return ChangeVideoInput(device);
      case DeviceMenuType.microphone:
        return ChangeAudioInput(device);
      case DeviceMenuType.speaker:
        return ChangeAudioOutput(device);
    }
  }
}

class _CallDeviceMenuContent extends StatelessWidget {
  final String title;
  final List<MediaDeviceInfo> devices;
  final String? currentId;
  final void Function(MediaDeviceInfo) onSelected;
  final CallBloc callBloc;
  final CallConnected state;

  const _CallDeviceMenuContent({
    required this.title,
    required this.devices,
    required this.currentId,
    required this.onSelected,
    required this.callBloc,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context),
          const SizedBox(height: 10),
          if (devices.isEmpty) _buildEmptyState(),
          Flexible(child: _buildDeviceList()),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        LocaleKeys.call_deviceNotFound.tr(),
        style: const TextStyle(color: Colors.white60),
      ),
    );
  }

  Widget _buildDeviceList() {
    return ListView(
      shrinkWrap: true,
      children: devices.map((d) {
        final isSelected = d.deviceId == currentId;
        return ListTile(
          leading: Icon(
            isSelected ? Icons.check_circle : Icons.circle_outlined,
            color: isSelected ? ColorsCustom.cream : Colors.white30,
          ),
          title: Text(
            d.label.isEmpty ? LocaleKeys.call_unknownDevice.tr() : d.label,
            style: TextStyle(
              color: isSelected ? ColorsCustom.cream : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          onTap: () {
            debugPrint(
              '[CallDeviceMenu] Device selected: ${d.label} (${d.deviceId})',
            );
            onSelected(d);
          },
        );
      }).toList(),
    );
  }
}
