import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/core/manager/cache_manager.dart';
import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/call/domain/enums/call_quality_preset.dart';
import 'package:emotional/features/call/domain/screen_share/screen_share_options.dart';
import 'package:emotional/features/call/presentation/screen_share/screen_share_sheet.dart';
import 'package:emotional/features/call/presentation/screen_share/screen_share_status.dart';
import 'package:emotional/features/call/service/screen_share/browser_screen_capture.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:emotional/product/widget/selectable_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum _Section { audio, video, screenShare }

/// Call settings for the browser: one centred dialog with sections on the
/// left and every choice visible on the right, instead of the phone's chain
/// of bottom sheets.
class WebCallSettingsDialog extends StatefulWidget {
  const WebCallSettingsDialog._();

  static Future<void> show(BuildContext context) {
    final callBloc = context.read<CallBloc>();
    return showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: callBloc,
        child: const WebCallSettingsDialog._(),
      ),
    );
  }

  @override
  State<WebCallSettingsDialog> createState() => _WebCallSettingsDialogState();
}

class _WebCallSettingsDialogState extends State<WebCallSettingsDialog> {
  static const double _maxWidth = 760;
  static const double _maxHeight = 560;
  static const double _navMinWidth = 600;

  _Section _section = _Section.audio;
  ScreenShareOptions? _shareDefaults;

  @override
  void initState() {
    super.initState();
    CacheManager().getScreenShareOptions().then((options) {
      if (mounted) setState(() => _shareDefaults = options);
    });
  }

  void _updateShareDefaults(ScreenShareOptions options) {
    setState(() => _shareDefaults = options);
    unawaited(CacheManager().saveScreenShareOptions(options));
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Dialog(
      backgroundColor: ColorsCustom.darkABlue,
      insetPadding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(maxWidth: _maxWidth),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: ColorsCustom.white10),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        // Fixed height so switching sections doesn't make the dialog jump.
        height: (height - 48).clamp(320.0, _maxHeight),
        child: BlocBuilder<CallBloc, CallState>(
          builder: (context, state) {
            if (state is! CallConnected) return const SizedBox.shrink();
            return Column(
              children: [
                _buildHeader(context),
                const Divider(height: 1, color: ColorsCustom.white10),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final content = SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: _buildSection(context, state),
                      );
                      if (constraints.maxWidth < _navMinWidth) {
                        return Column(
                          children: [
                            _buildTopNav(),
                            Expanded(child: content),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: 210, child: _buildSideNav()),
                          const VerticalDivider(
                            width: 1,
                            color: ColorsCustom.white10,
                          ),
                          Expanded(child: content),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 12, 16),
      child: Row(
        children: [
          const Icon(Icons.tune, color: ColorsCustom.skyBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              LocaleKeys.call_callSettings.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  // ─── Navigation ───────────────────────────────────────────────────────────

  (IconData, String) _navItem(_Section section) => switch (section) {
    _Section.audio => (Icons.mic_none, LocaleKeys.call_settingsAudio.tr()),
    _Section.video => (
      Icons.videocam_outlined,
      LocaleKeys.call_settingsVideo.tr(),
    ),
    _Section.screenShare => (
      Icons.screen_share_outlined,
      LocaleKeys.call_settingsScreenShare.tr(),
    ),
  };

  Widget _buildSideNav() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final section in _Section.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _NavTile(
              icon: _navItem(section).$1,
              label: _navItem(section).$2,
              selected: _section == section,
              onTap: () => setState(() => _section = section),
            ),
          ),
      ],
    );
  }

  Widget _buildTopNav() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          for (final section in _Section.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SelectablePill(
                icon: _navItem(section).$1,
                label: _navItem(section).$2,
                selected: _section == section,
                onTap: () => setState(() => _section = section),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Sections ─────────────────────────────────────────────────────────────

  Widget _buildSection(BuildContext context, CallConnected state) {
    final callBloc = context.read<CallBloc>();
    return switch (_section) {
      _Section.audio => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Field(
            label: LocaleKeys.call_microphone.tr(),
            child: _DeviceSelect(
              icon: Icons.mic_none,
              devices: state.audioInputs,
              selectedId: state.selectedAudioInputId,
              onSelected: (d) => callBloc.add(ChangeAudioInput(d)),
            ),
          ),
          const SizedBox(height: 24),
          _Field(
            label: LocaleKeys.call_speaker.tr(),
            // Safari has no speaker choice: say so instead of "not found".
            child: state.audioOutputs.isEmpty
                ? _Hint(LocaleKeys.call_speakerFollowsSystem.tr())
                : _DeviceSelect(
                    icon: Icons.volume_up_outlined,
                    devices: state.audioOutputs,
                    selectedId: state.selectedAudioOutputId,
                    onSelected: (d) => callBloc.add(ChangeAudioOutput(d)),
                  ),
          ),
        ],
      ),
      _Section.video => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Field(
            label: LocaleKeys.call_camera.tr(),
            child: _DeviceSelect(
              icon: Icons.videocam_outlined,
              devices: state.videoInputs,
              selectedId: state.selectedVideoInputId,
              onSelected: (d) => callBloc.add(ChangeVideoInput(d)),
            ),
          ),
          const SizedBox(height: 24),
          _Field(
            label: LocaleKeys.call_streamQuality.tr(),
            hint: LocaleKeys.call_qualityHint.tr(),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in CallQualityPreset.values)
                  SelectablePill(
                    label: preset.displayName,
                    selected: state.currentQuality == preset,
                    onTap: () => callBloc.add(ChangeQuality(preset)),
                  ),
              ],
            ),
          ),
        ],
      ),
      _Section.screenShare => _buildScreenShareSection(state),
    };
  }

  Widget _buildScreenShareSection(CallConnected state) {
    final capabilities = BrowserScreenCapture.capabilities;
    final defaults = _shareDefaults;
    if (!capabilities.isSupported) {
      return _Hint(LocaleKeys.call_screenShare_notSupported.tr());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.activeScreenShare case final share?) ...[
          _Field(
            label: LocaleKeys.call_currentShare.tr(),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ScreenShareStatus(share: share),
            ),
          ),
          const SizedBox(height: 24),
        ],
        _Hint(LocaleKeys.call_screenShareDefaultsHint.tr()),
        const SizedBox(height: 16),
        if (defaults == null)
          const Center(child: CircularProgressIndicator())
        else
          ScreenShareOptionsForm(
            options: defaults,
            capabilities: capabilities,
            onChanged: _updateShareDefaults,
          ),
      ],
    );
  }
}

// ─── Building blocks ────────────────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? ColorsCustom.skyBlue.withValues(alpha: 0.14)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? ColorsCustom.skyBlue : Colors.white60,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child, this.hint});

  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (hint != null) ...[const SizedBox(height: 4), _Hint(hint!)],
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white54, fontSize: 12.5),
    );
  }
}

/// Dropdown-style device picker; the menu opens under the field at its
/// width, like a native select.
class _DeviceSelect extends StatelessWidget {
  const _DeviceSelect({
    required this.icon,
    required this.devices,
    required this.selectedId,
    required this.onSelected,
  });

  final IconData icon;
  final List<MediaDeviceInfo> devices;
  final String? selectedId;
  final ValueChanged<MediaDeviceInfo> onSelected;

  String _label(MediaDeviceInfo device) =>
      device.label.isEmpty ? LocaleKeys.call_unknownDevice.tr() : device.label;

  @override
  Widget build(BuildContext context) {
    final selected = devices.where((d) => d.deviceId == selectedId).firstOrNull;
    final enabled = devices.isNotEmpty;
    final text = !enabled
        ? LocaleKeys.call_deviceNotFound.tr()
        : selected != null
        ? _label(selected)
        : LocaleKeys.call_default.tr();

    return LayoutBuilder(
      builder: (context, constraints) => PopupMenuButton<MediaDeviceInfo>(
        enabled: enabled,
        tooltip: '',
        position: PopupMenuPosition.under,
        color: ColorsCustom.darkBlue,
        constraints: BoxConstraints(
          minWidth: constraints.maxWidth,
          maxWidth: constraints.maxWidth,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: ColorsCustom.white10),
        ),
        onSelected: onSelected,
        itemBuilder: (_) => [
          for (final device in devices)
            PopupMenuItem(
              value: device,
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: device.deviceId == selectedId
                        ? const Icon(
                            Icons.check,
                            size: 18,
                            color: ColorsCustom.skyBlue,
                          )
                        : null,
                  ),
                  Expanded(
                    child: Text(
                      _label(device),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ColorsCustom.white10),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.white60),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled ? Colors.white : Colors.white38,
                  ),
                ),
              ),
              Icon(
                Icons.expand_more,
                color: enabled ? Colors.white60 : Colors.white24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
