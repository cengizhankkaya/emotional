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

  const VideoPlayerActive({
    required this.player,
    required this.controller,
    required this.videoFile,
    this.isMinimized = false,
  });

  VideoPlayerActive copyWith({
    Player? player,
    VideoController? controller,
    File? videoFile,
    bool? isMinimized,
  }) {
    return VideoPlayerActive(
      player: player ?? this.player,
      controller: controller ?? this.controller,
      videoFile: videoFile ?? this.videoFile,
      isMinimized: isMinimized ?? this.isMinimized,
    );
  }

  @override
  List<Object?> get props => [player, controller, videoFile, isMinimized];
}
