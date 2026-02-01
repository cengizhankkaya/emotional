import 'package:emotional/features/video_player/bloc/video_player_event.dart';
import 'package:emotional/features/video_player/bloc/video_player_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoPlayerBloc extends Bloc<VideoPlayerEvent, VideoPlayerState> {
  VideoPlayerBloc() : super(VideoPlayerInitial()) {
    on<InitializePlayer>(_onInitializePlayer);
    on<ToggleMinimize>(_onToggleMinimize);
    on<ClosePlayer>(_onClosePlayer);
  }

  Future<void> _onInitializePlayer(
    InitializePlayer event,
    Emitter<VideoPlayerState> emit,
  ) async {
    // If already playing the same file, just ensure it's not minimized (or maybe keep state?)
    // For now, let's reset if it's a new request, or we could handle "resume" logic.
    if (state is VideoPlayerActive) {
      final activeState = state as VideoPlayerActive;
      if (activeState.videoFile.path == event.file.path) {
        // Same file, just ensure maxmized
        emit(activeState.copyWith(isMinimized: false));
        return;
      } else {
        // Different file, dispose old one properly
        await activeState.player.dispose();
      }
    }

    final player = Player();
    final controller = VideoController(player);

    await player.open(Media(event.file.path), play: true);

    emit(
      VideoPlayerActive(
        player: player,
        controller: controller,
        videoFile: event.file,
        isMinimized: false,
      ),
    );
  }

  void _onToggleMinimize(ToggleMinimize event, Emitter<VideoPlayerState> emit) {
    if (state is VideoPlayerActive) {
      final activeState = state as VideoPlayerActive;
      emit(
        activeState.copyWith(
          isMinimized: event.isMinimized ?? !activeState.isMinimized,
        ),
      );
    }
  }

  Future<void> _onClosePlayer(
    ClosePlayer event,
    Emitter<VideoPlayerState> emit,
  ) async {
    if (state is VideoPlayerActive) {
      final activeState = state as VideoPlayerActive;
      await activeState.player.dispose();
      emit(VideoPlayerInitial());
    }
  }
}
