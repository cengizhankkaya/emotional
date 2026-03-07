import 'package:emotional/features/call/domain/enums/call_quality_preset.dart';
import 'package:emotional/features/call/domain/enums/call_video_size.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

const Object _sentinel = Object();

abstract class CallState extends Equatable {
  const CallState();

  @override
  List<Object?> get props => [];
}

class CallInitial extends CallState {
  const CallInitial();
}

class CallLoading extends CallState {
  const CallLoading();
}

class CallConnected extends CallState {
  // Core State
  final RTCVideoRenderer localRenderer;
  final Map<String, RTCVideoRenderer> remoteRenderers;
  final Map<String, String> activeUsers;
  final Map<String, bool> userVideoStates;
  final Map<String, bool> userAudioStates;
  final Map<String, bool> userScreenSharingStates;
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
  final String? activeSpeakerId; // New field
  final CallVideoSize videoSize;
  final bool isScreenSharing;

  const CallConnected({
    required this.localRenderer,
    this.remoteRenderers = const {},
    this.activeUsers = const {},
    this.userVideoStates = const {},
    this.userAudioStates = const {},
    this.userScreenSharingStates = const {},
    this.isMuted = false,
    this.isVideoEnabled = false,
    this.videoInputs = const [],
    this.audioInputs = const [],
    this.audioOutputs = const [],
    this.currentQuality = CallQualityPreset.balanced,
    this.selectedVideoInputId,
    this.selectedAudioInputId,
    this.selectedAudioOutputId,
    this.activeSpeakerId, // Added to constructor
    this.videoSize = CallVideoSize.medium,
    this.isScreenSharing = false,
  });

  CallConnected copyWith({
    RTCVideoRenderer? localRenderer,
    Map<String, RTCVideoRenderer>? remoteRenderers,
    Map<String, String>? activeUsers,
    Map<String, bool>? userVideoStates,
    Map<String, bool>? userAudioStates,
    Map<String, bool>? userScreenSharingStates,
    bool? isMuted,
    bool? isVideoEnabled,
    List<MediaDeviceInfo>? videoInputs,
    List<MediaDeviceInfo>? audioInputs,
    List<MediaDeviceInfo>? audioOutputs,
    CallQualityPreset? currentQuality,
    Object? selectedVideoInputId = _sentinel,
    Object? selectedAudioInputId = _sentinel,
    Object? selectedAudioOutputId = _sentinel,
    Object? activeSpeakerId = _sentinel,
    CallVideoSize? videoSize,
    bool? isScreenSharing,
  }) {
    return CallConnected(
      localRenderer: localRenderer ?? this.localRenderer,
      remoteRenderers: remoteRenderers ?? this.remoteRenderers,
      activeUsers: activeUsers ?? this.activeUsers,
      userVideoStates: userVideoStates ?? this.userVideoStates,
      userAudioStates: userAudioStates ?? this.userAudioStates,
      userScreenSharingStates:
          userScreenSharingStates ?? this.userScreenSharingStates,
      isMuted: isMuted ?? this.isMuted,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      videoInputs: videoInputs ?? this.videoInputs,
      audioInputs: audioInputs ?? this.audioInputs,
      audioOutputs: audioOutputs ?? this.audioOutputs,
      currentQuality: currentQuality ?? this.currentQuality,
      selectedVideoInputId: selectedVideoInputId == _sentinel
          ? this.selectedVideoInputId
          : selectedVideoInputId as String?,
      selectedAudioInputId: selectedAudioInputId == _sentinel
          ? this.selectedAudioInputId
          : selectedAudioInputId as String?,
      selectedAudioOutputId: selectedAudioOutputId == _sentinel
          ? this.selectedAudioOutputId
          : selectedAudioOutputId as String?,
      activeSpeakerId: activeSpeakerId == _sentinel
          ? this.activeSpeakerId
          : activeSpeakerId as String?,
      videoSize: videoSize ?? this.videoSize,
      isScreenSharing: isScreenSharing ?? this.isScreenSharing,
    );
  }

  @override
  List<Object?> get props => [
    localRenderer,
    remoteRenderers,
    activeUsers,
    userVideoStates,
    userAudioStates,
    userScreenSharingStates,
    isMuted,
    isVideoEnabled,
    videoInputs,
    audioInputs,
    audioOutputs,
    currentQuality,
    selectedVideoInputId,
    selectedAudioInputId,
    selectedAudioOutputId,
    activeSpeakerId, // Added to props
    videoSize,
    isScreenSharing,
  ];
}

class CallError extends CallState {
  final String message;

  const CallError(this.message);

  @override
  List<Object?> get props => [message];
}
