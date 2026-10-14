import 'package:emotional/features/call/domain/enums/call_quality_preset.dart';
import 'package:emotional/features/call/domain/enums/call_video_size.dart';
import 'package:emotional/features/call/domain/screen_share/screen_share_options.dart';
import 'package:emotional/features/call/domain/client_platform.dart';
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

  /// Where each participant joined from, as far as their app says; see
  /// [platformOf] for one participant, you included.
  final Map<String, ClientPlatform> userPlatforms;

  /// Sharers' cameras, shown next to their screen (see [shareCameraOf]).
  final Map<String, RTCVideoRenderer> shareCameraRenderers;
  final Map<String, bool> userShareCameraStates;

  /// Your own camera while you share your screen ([localRenderer] shows
  /// the screen then).
  final RTCVideoRenderer? localShareCameraRenderer;
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

  /// Details of the live share on web; null when not sharing or on mobile.
  final ActiveScreenShare? activeScreenShare;

  /// The last camera/microphone problem to tell the user about; with
  /// [mediaIssueCount] so the same issue twice is reported twice.
  final MediaIssue? mediaIssue;
  final int mediaIssueCount;

  /// During a share [isVideoEnabled] means "sending video" (the screen) and
  /// stays true, as peers and older app versions expect; this is whether the
  /// camera comes back when the share ends.
  final bool cameraAfterShare;

  /// Where [userId] joined from; this device for [localUserId].
  ClientPlatform? platformOf(String userId, {required String localUserId}) =>
      userId == localUserId ? ClientPlatform.current : userPlatforms[userId];

  /// [userId]'s camera while they share their screen, if it's on.
  RTCVideoRenderer? shareCameraOf(
    String userId, {
    required String localUserId,
  }) {
    if (userId == localUserId) {
      return isScreenSharing && cameraAfterShare
          ? localShareCameraRenderer
          : null;
    }
    if (userShareCameraStates[userId] != true) return null;
    if (userScreenSharingStates[userId] != true) return null;
    return shareCameraRenderers[userId];
  }

  /// What camera buttons show: the camera now, or after the share.
  bool get isCameraOn => isScreenSharing ? cameraAfterShare : isVideoEnabled;

  const CallConnected({
    required this.localRenderer,
    this.remoteRenderers = const {},
    this.activeUsers = const {},
    this.userVideoStates = const {},
    this.userAudioStates = const {},
    this.userScreenSharingStates = const {},
    this.userPlatforms = const {},
    this.shareCameraRenderers = const {},
    this.userShareCameraStates = const {},
    this.localShareCameraRenderer,
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
    this.activeScreenShare,
    this.mediaIssue,
    this.mediaIssueCount = 0,
    this.cameraAfterShare = false,
  });

  CallConnected copyWith({
    RTCVideoRenderer? localRenderer,
    Map<String, RTCVideoRenderer>? remoteRenderers,
    Map<String, String>? activeUsers,
    Map<String, bool>? userVideoStates,
    Map<String, bool>? userAudioStates,
    Map<String, bool>? userScreenSharingStates,
    Map<String, ClientPlatform>? userPlatforms,
    Map<String, RTCVideoRenderer>? shareCameraRenderers,
    Map<String, bool>? userShareCameraStates,
    Object? localShareCameraRenderer = _sentinel,
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
    Object? activeScreenShare = _sentinel,
    MediaIssue? mediaIssue,
    int? mediaIssueCount,
    bool? cameraAfterShare,
  }) {
    return CallConnected(
      localRenderer: localRenderer ?? this.localRenderer,
      remoteRenderers: remoteRenderers ?? this.remoteRenderers,
      activeUsers: activeUsers ?? this.activeUsers,
      userVideoStates: userVideoStates ?? this.userVideoStates,
      userAudioStates: userAudioStates ?? this.userAudioStates,
      userScreenSharingStates:
          userScreenSharingStates ?? this.userScreenSharingStates,
      userPlatforms: userPlatforms ?? this.userPlatforms,
      shareCameraRenderers: shareCameraRenderers ?? this.shareCameraRenderers,
      userShareCameraStates:
          userShareCameraStates ?? this.userShareCameraStates,
      localShareCameraRenderer: localShareCameraRenderer == _sentinel
          ? this.localShareCameraRenderer
          : localShareCameraRenderer as RTCVideoRenderer?,
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
      activeScreenShare: activeScreenShare == _sentinel
          ? this.activeScreenShare
          : activeScreenShare as ActiveScreenShare?,
      mediaIssue: mediaIssue ?? this.mediaIssue,
      mediaIssueCount: mediaIssueCount ?? this.mediaIssueCount,
      cameraAfterShare: cameraAfterShare ?? this.cameraAfterShare,
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
    userPlatforms,
    shareCameraRenderers,
    userShareCameraStates,
    localShareCameraRenderer,
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
    activeScreenShare,
    mediaIssue,
    mediaIssueCount,
    cameraAfterShare,
  ];
}

enum MediaIssue {
  /// The app was refused camera access (phones).
  cameraPermissionDenied,

  /// No camera, it's busy, or the browser blocked it.
  cameraUnavailable,

  /// The camera went away mid-call (unplugged); it's now off.
  cameraLost,

  /// The microphone went away; the call moved to the default one.
  microphoneSwitched,

  /// The microphone went away and there is no other one.
  microphoneLost,
}

class CallError extends CallState {
  final String message;

  const CallError(this.message);

  @override
  List<Object?> get props => [message];
}
