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

class IncomingOffer extends CallEvent {
  final String userId;
  final RTCSessionDescription description;

  const IncomingOffer({required this.userId, required this.description});
}

class IncomingAnswer extends CallEvent {
  final String userId;
  final RTCSessionDescription description;

  const IncomingAnswer({required this.userId, required this.description});
}

class IncomingIceCandidate extends CallEvent {
  final String userId;
  final RTCIceCandidate candidate;

  const IncomingIceCandidate({required this.userId, required this.candidate});
}

class ToggleMute extends CallEvent {}

class ToggleVideo extends CallEvent {}

class SwitchCamera extends CallEvent {}
