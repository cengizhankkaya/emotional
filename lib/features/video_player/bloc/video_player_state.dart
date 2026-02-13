import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

abstract class VideoPlayerState extends Equatable {
  const VideoPlayerState();

  @override
  List<Object?> get props => [];
}

class VideoPlayerInitial extends VideoPlayerState {}

class VideoPlayerActive extends VideoPlayerState {
  final Player player;
  final VideoController controller;
  final File videoFile;
  final bool isMinimized;
  final bool isBuffering;

  // Sync Status
  final bool isSyncing;
  final VideoSyncRequest? pendingSyncRequest;

  // Room Context
  final String? roomId;
  final String? hostId;
  final String? currentUserId;
  final int? lastRemoteUpdateTime;
  final int? lastVideoStateTimestamp; // Track when videoState was last updated

  const VideoPlayerActive({
    required this.player,
    required this.controller,
    required this.videoFile,
    this.isMinimized = false,
    this.isBuffering = false,
    this.isSyncing = false,
    this.pendingSyncRequest,
    this.roomId,
    this.hostId,
    this.currentUserId,
    this.lastRemoteUpdateTime,
    this.lastVideoStateTimestamp,
  });

  bool get isHost =>
      hostId != null && currentUserId != null && hostId == currentUserId;

  VideoPlayerActive copyWith({
    Player? player,
    VideoController? controller,
    File? videoFile,
    bool? isMinimized,
    bool? isBuffering,
    bool? isSyncing,
    VideoSyncRequest? Function()? pendingSyncRequest,
    String? roomId,
    String? hostId,
    String? currentUserId,
    int? lastRemoteUpdateTime,
    int? lastVideoStateTimestamp,
  }) {
    return VideoPlayerActive(
      player: player ?? this.player,
      controller: controller ?? this.controller,
      videoFile: videoFile ?? this.videoFile,
      isMinimized: isMinimized ?? this.isMinimized,
      isBuffering: isBuffering ?? this.isBuffering,
      isSyncing: isSyncing ?? this.isSyncing,
      pendingSyncRequest: pendingSyncRequest != null
          ? pendingSyncRequest()
          : this.pendingSyncRequest,
      roomId: roomId ?? this.roomId,
      hostId: hostId ?? this.hostId,
      currentUserId: currentUserId ?? this.currentUserId,
      lastRemoteUpdateTime: lastRemoteUpdateTime ?? this.lastRemoteUpdateTime,
      lastVideoStateTimestamp:
          lastVideoStateTimestamp ?? this.lastVideoStateTimestamp,
    );
  }

  @override
  List<Object?> get props => [
    player,
    controller,
    videoFile,
    isMinimized,
    isBuffering,
    isSyncing,
    pendingSyncRequest,
    roomId,
    hostId,
    currentUserId,
    lastRemoteUpdateTime,
    lastVideoStateTimestamp,
  ];
}

class VideoSyncRequest extends Equatable {
  final String roomId;
  final bool isPlaying;
  final int position;
  final String userId;
  final double? speed;
  final String? audioTrack;
  final String? subtitleTrack;

  const VideoSyncRequest({
    required this.roomId,
    required this.isPlaying,
    required this.position,
    required this.userId,
    this.speed,
    this.audioTrack,
    this.subtitleTrack,
  });

  @override
  List<Object?> get props => [
    roomId,
    isPlaying,
    position,
    userId,
    speed,
    audioTrack,
    subtitleTrack,
  ];
}
