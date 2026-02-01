import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/call/domain/enums/call_quality_preset.dart';
import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CallSettingsSheet extends StatelessWidget {
  const CallSettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const ProjectPadding.allMedium(),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white10),
      ),
      child: BlocBuilder<CallBloc, CallState>(
        builder: (context, state) {
          if (state is! CallConnected) return const SizedBox.shrink();

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Görüşme Ayarları',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Video Selection
              _buildDropdown<MediaDeviceInfo>(
                context: context,
                label: 'Kamera',
                value: state.videoInputs.firstWhere(
                  (d) => d.deviceId == state.selectedVideoInputId,
                  orElse: () => state.videoInputs.isNotEmpty
                      ? state.videoInputs.first
                      : MediaDeviceInfo(
                          deviceId: 'unknown',
                          label: 'unknown',
                          kind: 'unknown',
                        ),
                ),
                items: state.videoInputs,
                onChanged: (device) {
                  if (device != null) {
                    context.read<CallBloc>().add(ChangeVideoInput(device));
                  }
                },
                itemLabelBuilder: (d) => d.label.isEmpty
                    ? 'Kamera ${state.videoInputs.indexOf(d) + 1}'
                    : d.label,
              ),

              const SizedBox(height: 16),

              // Audio Input Selection
              _buildDropdown<MediaDeviceInfo>(
                context: context,
                label: 'Mikrofon',
                value: state.audioInputs.firstWhere(
                  (d) => d.deviceId == state.selectedAudioInputId,
                  orElse: () => state.audioInputs.isNotEmpty
                      ? state.audioInputs.first
                      : MediaDeviceInfo(
                          deviceId: 'unknown',
                          label: 'unknown',
                          kind: 'unknown',
                        ),
                ),
                items: state.audioInputs,
                onChanged: (device) {
                  if (device != null) {
                    context.read<CallBloc>().add(ChangeAudioInput(device));
                  }
                },
                itemLabelBuilder: (d) => d.label.isEmpty
                    ? 'Mikrofon ${state.audioInputs.indexOf(d) + 1}'
                    : d.label,
              ),

              const SizedBox(height: 16),

              // Quality Selection
              _buildDropdown<CallQualityPreset>(
                context: context,
                label: 'Görüntü Kalitesi',
                value: state.currentQuality,
                items: CallQualityPreset.values,
                onChanged: (preset) {
                  if (preset != null) {
                    context.read<CallBloc>().add(ChangeQuality(preset));
                  }
                },
                itemLabelBuilder: (q) => q.displayName,
              ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDropdown<T>({
    required BuildContext context,
    required String label,
    required T value,
    required List<T> items,
    required Function(T?) onChanged,
    required String Function(T) itemLabelBuilder,
  }) {
    // Basic null check for lists if empty
    if (items.isEmpty && label != 'Görüntü Kalitesi')
      return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const ProjectPadding.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: ProjectRadius.small(),
          ),
          child: DropdownButton<T>(
            value: items.contains(value) ? value : null, // Safety check
            isExpanded: true,
            dropdownColor: const Color(0xFF2C2C2C),
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
            style: const TextStyle(color: Colors.white),
            items: items.map((item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(
                  itemLabelBuilder(item),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
