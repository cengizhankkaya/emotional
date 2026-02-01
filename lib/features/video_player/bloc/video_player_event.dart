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
