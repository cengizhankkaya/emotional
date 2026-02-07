import 'dart:io';
import 'package:equatable/equatable.dart';

abstract class VideoPlayerEvent extends Equatable {
  const VideoPlayerEvent();

  @override
  List<Object?> get props => [];
}

class InitializePlayer extends VideoPlayerEvent {
  final File file;

  const InitializePlayer(this.file);

  @override
  List<Object?> get props => [file];
}

class ToggleMinimize extends VideoPlayerEvent {
  final bool? isMinimized;

  const ToggleMinimize({this.isMinimized});

  @override
  List<Object?> get props => [isMinimized];
}

class ClosePlayer extends VideoPlayerEvent {}

class SeekTo extends VideoPlayerEvent {
  final Duration position;

  const SeekTo(this.position);

  @override
  List<Object?> get props => [position];
}

/// Event triggering when the underlying player state changes (playing, position, etc.)
class OnPlayerStateChanged extends VideoPlayerEvent {
  final bool? isPlaying;
  final Duration? position;
  final double? rate;
  final bool? isBuffering;
  final String? audioTrack;
  final String? subtitleTrack;

  const OnPlayerStateChanged({
    this.isPlaying,
    this.position,
    this.rate,
    this.isBuffering,
    this.audioTrack,
    this.subtitleTrack,
  });

  @override
  List<Object?> get props => [
    isPlaying,
    position,
    rate,
    isBuffering,
    audioTrack,
    subtitleTrack,
  ];
}

/// Event triggering when the remote room state changes
class OnRemoteStateChanged extends VideoPlayerEvent {
  final String roomId;
  final bool isPlaying;
  final int position;
  final double speed;
  final String? audioTrack;
  final String? subtitleTrack;
  final String? updatedBy;
  final int lastUpdatedAt;
  final String hostId;
  final String currentUserId;

  const OnRemoteStateChanged({
    required this.roomId,
    required this.isPlaying,
    required this.position,
    required this.speed,
    this.audioTrack,
    this.subtitleTrack,
    this.updatedBy,
    required this.lastUpdatedAt,
    required this.hostId,
    required this.currentUserId,
  });

  @override
  List<Object?> get props => [
    roomId,
    isPlaying,
    position,
    speed,
    audioTrack,
    subtitleTrack,
    updatedBy,
    lastUpdatedAt,
    hostId,
    currentUserId,
  ];
}
