import 'package:emotional/features/call/domain/enums/call_quality_preset.dart';
import 'package:emotional/features/call/domain/enums/call_video_size.dart';
import 'package:emotional/features/call/domain/screen_share/screen_share_options.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

abstract class CallEvent extends Equatable {
  const CallEvent();

  @override
  List<Object?> get props => [];
}

class JoinCall extends CallEvent {
  final String roomId;
  final String userId;

  const JoinCall({required this.roomId, required this.userId});

  @override
  List<Object?> get props => [roomId, userId];
}

class LeaveCall extends CallEvent {}

// Internal Events from Services
class InternalUpdateActiveSpeaker extends CallEvent {
  final String? speakerId;
  const InternalUpdateActiveSpeaker(this.speakerId);
  @override
  List<Object?> get props => [speakerId];
}

class InternalIncomingStream extends CallEvent {
  final String userId;
  final MediaStream stream;
  const InternalIncomingStream(this.userId, this.stream);
}

/// A sharer's camera, sent next to their screen.
class InternalShareCameraStream extends CallEvent {
  final String userId;
  final MediaStream stream;
  const InternalShareCameraStream(this.userId, this.stream);
}

class InternalStreamRemoved extends CallEvent {
  final String userId;
  const InternalStreamRemoved(this.userId);
}

class InternalUpdateState extends CallEvent {}

/// The microphone stopped on its own (unplugged, headset disconnected).
class InternalMicrophoneLost extends CallEvent {
  const InternalMicrophoneLost();
}

/// The camera stopped on its own.
class InternalCameraLost extends CallEvent {
  const InternalCameraLost();
}

/// A camera, microphone or speaker was plugged in or removed.
class InternalDevicesChanged extends CallEvent {
  const InternalDevicesChanged();
}

// Device and Quality Management Events
class ChangeVideoInput extends CallEvent {
  final MediaDeviceInfo device;
  const ChangeVideoInput(this.device);
}

class ChangeAudioInput extends CallEvent {
  final MediaDeviceInfo device;
  const ChangeAudioInput(this.device);
}

class ChangeAudioOutput extends CallEvent {
  final MediaDeviceInfo device;
  const ChangeAudioOutput(this.device);
}

class ChangeQuality extends CallEvent {
  final CallQualityPreset preset;
  const ChangeQuality(this.preset);
}

class ChangeVideoSize extends CallEvent {
  final CallVideoSize size;
  const ChangeVideoSize(this.size);
}

class FetchDevices extends CallEvent {}

// Camera/Mic Toggles
class ToggleMute extends CallEvent {}

class ToggleVideo extends CallEvent {}

class SwitchCamera extends CallEvent {} // Acts as "Next Camera" legacy support

class SuspendMedia extends CallEvent {}

class ResumeMedia extends CallEvent {}

class ToggleScreenShare extends CallEvent {
  final bool fromNotification;

  /// Capture options picked in the web share sheet; ignored when stopping.
  final ScreenShareOptions? options;

  const ToggleScreenShare({this.fromNotification = false, this.options});

  @override
  List<Object?> get props => [fromNotification, options];
}

/// The browser ended the share on its own, e.g. the user clicked the
/// browser's "Stop sharing" bar or closed the shared tab.
class ScreenShareEnded extends CallEvent {
  const ScreenShareEnded();
}
