import 'package:emotional/features/call/domain/enums/call_quality_preset.dart';
import 'package:emotional/features/call/domain/enums/call_video_size.dart';
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
class InternalIncomingStream extends CallEvent {
  final String userId;
  final MediaStream stream;
  const InternalIncomingStream(this.userId, this.stream);
}

class InternalStreamRemoved extends CallEvent {
  final String userId;
  const InternalStreamRemoved(this.userId);
}

class InternalUpdateState extends CallEvent {}

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
