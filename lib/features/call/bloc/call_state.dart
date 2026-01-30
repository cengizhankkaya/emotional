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
  final RTCVideoRenderer localRenderer;
  final Map<String, RTCVideoRenderer> remoteRenderers;
  final Map<String, String> activeUsers;
  final Map<String, bool> userVideoStates;
  final bool isMuted;
  final bool isVideoEnabled;

  const CallConnected({
    required this.localRenderer,
    this.remoteRenderers = const {},
    this.activeUsers = const {},
    this.userVideoStates = const {},
    this.isMuted = false,
    this.isVideoEnabled = true,
  });

  CallConnected copyWith({
    RTCVideoRenderer? localRenderer,
    Map<String, RTCVideoRenderer>? remoteRenderers,
    Map<String, String>? activeUsers,
    Map<String, bool>? userVideoStates,
    bool? isMuted,
    bool? isVideoEnabled,
  }) {
    return CallConnected(
      localRenderer: localRenderer ?? this.localRenderer,
      remoteRenderers: remoteRenderers ?? this.remoteRenderers,
      activeUsers: activeUsers ?? this.activeUsers,
      userVideoStates: userVideoStates ?? this.userVideoStates,
      isMuted: isMuted ?? this.isMuted,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
    );
  }

  @override
  List<Object?> get props => [
    localRenderer,
    localRenderer,
    localRenderer,
    remoteRenderers,
    activeUsers,
    userVideoStates,
    isMuted,
    isVideoEnabled,
  ];
}

class CallError extends CallState {
  final String message;

  const CallError(this.message);

  @override
  List<Object?> get props => [message];
}
