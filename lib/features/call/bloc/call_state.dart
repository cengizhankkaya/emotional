import 'package:emotional/features/call/domain/enums/call_quality_preset.dart';
import 'package:emotional/features/call/domain/enums/call_video_size.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

abstract class CallState extends Equatable {
  const CallState();

  @override
  List<Object?> get props => [];
}

class CallInitial extends CallState {}

class CallLoading extends CallState {}

class CallConnected extends CallState {
  // Core State
  final RTCVideoRenderer localRenderer;
  final Map<String, RTCVideoRenderer> remoteRenderers;
  final Map<String, String> activeUsers;
  final Map<String, bool> userVideoStates;
  final Map<String, bool> userAudioStates;
  final bool isMuted;
  final bool isVideoEnabled;

  // New Professional Features
  final List<MediaDeviceInfo> videoInputs;
  final List<MediaDeviceInfo> audioInputs;
  final List<MediaDeviceInfo> audioOutputs;
  final CallQualityPreset currentQuality;

  final String? selectedVideoInputId;
  final String? selectedAudioInputId;
  final String? selectedAudioOutputId;
  final CallVideoSize videoSize; // Added this field

  const CallConnected({
    required this.localRenderer,
    this.remoteRenderers = const {},
    this.activeUsers = const {},
    this.userVideoStates = const {},
    this.userAudioStates = const {},
    this.isMuted = false,
    this.isVideoEnabled = true,
    this.videoInputs = const [],
    this.audioInputs = const [],
    this.audioOutputs = const [],
    this.currentQuality = CallQualityPreset.balanced,
    this.selectedVideoInputId,
    this.selectedAudioInputId,
    this.selectedAudioOutputId,
    this.videoSize = CallVideoSize.medium, // Added this to constructor
  });

  CallConnected copyWith({
    RTCVideoRenderer? localRenderer,
    Map<String, RTCVideoRenderer>? remoteRenderers,
    Map<String, String>? activeUsers,
    Map<String, bool>? userVideoStates,
    Map<String, bool>? userAudioStates,
    bool? isMuted,
    bool? isVideoEnabled,
    List<MediaDeviceInfo>? videoInputs,
    List<MediaDeviceInfo>? audioInputs,
    List<MediaDeviceInfo>? audioOutputs,
    CallQualityPreset? currentQuality,
    String? selectedVideoInputId,
    String? selectedAudioInputId,
    String? selectedAudioOutputId,
    CallVideoSize? videoSize, // Added this to copyWith signature
  }) {
    return CallConnected(
      localRenderer: localRenderer ?? this.localRenderer,
      remoteRenderers: remoteRenderers ?? this.remoteRenderers,
      activeUsers: activeUsers ?? this.activeUsers,
      userVideoStates: userVideoStates ?? this.userVideoStates,
      userAudioStates: userAudioStates ?? this.userAudioStates,
      isMuted: isMuted ?? this.isMuted,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      videoInputs: videoInputs ?? this.videoInputs,
      audioInputs: audioInputs ?? this.audioInputs,
      audioOutputs: audioOutputs ?? this.audioOutputs,
      currentQuality: currentQuality ?? this.currentQuality,
      selectedVideoInputId: selectedVideoInputId ?? this.selectedVideoInputId,
      selectedAudioInputId: selectedAudioInputId ?? this.selectedAudioInputId,
      selectedAudioOutputId:
          selectedAudioOutputId ?? this.selectedAudioOutputId,
      videoSize: videoSize ?? this.videoSize, // Added this to copyWith body
    );
  }

  @override
  List<Object?> get props => [
    localRenderer,
    remoteRenderers,
    activeUsers,
    userVideoStates,
    userAudioStates,
    isMuted,
    isVideoEnabled,
    videoInputs,
    audioInputs,
    audioOutputs,
    currentQuality,
    selectedVideoInputId,
    selectedAudioInputId,
    selectedAudioOutputId,
    videoSize, // Added this to props
  ];
}

class CallError extends CallState {
  final String message;

  const CallError(this.message);

  @override
  List<Object?> get props => [message];
}
