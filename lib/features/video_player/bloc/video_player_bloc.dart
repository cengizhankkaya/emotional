import 'dart:async';

import 'package:emotional/features/video_player/bloc/video_player_event.dart';
import 'package:emotional/features/video_player/bloc/video_player_state.dart';
import 'package:emotional/features/video_player/data/services/video_player_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

const int _kSyncToleranceMs = 1500;

class VideoPlayerBloc extends Bloc<VideoPlayerEvent, VideoPlayerState> {
  final VideoPlayerService _videoService;

  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<double>? _rateSubscription;
  StreamSubscription<bool>? _bufferingSubscription;

  DateTime? _lastLocalActionTime;

  VideoPlayerBloc({VideoPlayerService? videoService})
    : _videoService = videoService ?? MediaKitVideoPlayerService(),
      super(VideoPlayerInitial()) {
    on<InitializePlayer>(_onInitializePlayer);
    on<ToggleMinimize>(_onToggleMinimize);
    on<ClosePlayer>(_onClosePlayer);
    on<OnPlayerStateChanged>(_onPlayerStateChanged);
    on<OnRemoteStateChanged>(_onRemoteStateChanged);
    on<SeekTo>(_onSeekTo);
  }

  Future<void> _onSeekTo(SeekTo event, Emitter<VideoPlayerState> emit) async {
    if (state is! VideoPlayerActive) return;
    final currentState = state as VideoPlayerActive;

    // Explicit user action
    _lastLocalActionTime = DateTime.now();

    await _videoService.seek(event.position);

    if (currentState.roomId != null &&
        currentState.currentUserId != null &&
        currentState.isHost) {
      emit(
        currentState.copyWith(
          pendingSyncRequest: () => VideoSyncRequest(
            roomId: currentState.roomId!,
            isPlaying: _videoService.isPlaying,
            position: event.position.inMilliseconds,
            userId: currentState.currentUserId!,
            speed: _videoService.rate,
            audioTrack: _videoService.track.audio.id,
            subtitleTrack: _videoService.track.subtitle.id,
          ),
        ),
      );
    }
  }

  Future<void> _onInitializePlayer(
    InitializePlayer event,
    Emitter<VideoPlayerState> emit,
  ) async {
    if (state is VideoPlayerActive) {
      final activeState = state as VideoPlayerActive;
      if (activeState.videoFile.path == event.file.path) {
        emit(activeState.copyWith(isMinimized: false));
        return;
      } else {
        await _disposePlayer();
      }
    }

    await _videoService.initialize();
    final controller = VideoController(_videoService.player);
    await _videoService.open(event.file.path);

    _playingSubscription = _videoService.playingStream.listen((playing) {
      add(OnPlayerStateChanged(isPlaying: playing));
    });

    _positionSubscription = _videoService.positionStream.listen((position) {
      add(OnPlayerStateChanged(position: position));
    });

    _rateSubscription = _videoService.rateStream.listen((rate) {
      add(OnPlayerStateChanged(rate: rate));
    });

    _bufferingSubscription = _videoService.bufferingStream.listen((buffering) {
      add(OnPlayerStateChanged(isBuffering: buffering));
    });

    _videoService.trackStream.listen((track) {
      add(
        OnPlayerStateChanged(
          audioTrack: _videoService.player.state.track.audio.id,
          subtitleTrack: _videoService.player.state.track.subtitle.id,
        ),
      );
    });

    emit(
      VideoPlayerActive(
        player: _videoService.player,
        controller: controller,
        videoFile: event.file,
        isMinimized: false,
        isBuffering: _videoService.isBuffering,
      ),
    );
  }

  Future<void> _onPlayerStateChanged(
    OnPlayerStateChanged event,
    Emitter<VideoPlayerState> emit,
  ) async {
    if (state is! VideoPlayerActive) {
      return;
    }
    final currentState = state as VideoPlayerActive;

    // Update local state for UI (buffering)
    if (event.isBuffering != null) {
      emit(currentState.copyWith(isBuffering: event.isBuffering));
      // Buffering state might not need sync to remote unless we implement "smart pause"
      // avoiding return here to allow other logic if needed, but usually we just return after emit if no sync needed.
      return;
    }

    if (currentState.isSyncing) {
      return;
    }
    if (currentState.roomId == null || currentState.currentUserId == null) {
      return;
    }
    if (!currentState.isHost) {
      return;
    }

    if (_lastLocalActionTime != null &&
        DateTime.now().difference(_lastLocalActionTime!).inMilliseconds <
            1000) {
      // Debounce
    }

    bool needsSync = false;

    // Check Play/Pause
    if (event.isPlaying != null) {
      needsSync = true;
    }

    // SEEK WHILE PAUSED Logic:
    if (event.position != null) {
      if (!_videoService.isPlaying) {
        // Seeking while paused
        needsSync = true;
      }
    }

    // Track Change Logic:
    if (event.audioTrack != null || event.subtitleTrack != null) {
      needsSync = true;
    }

    if (needsSync) {
      _lastLocalActionTime = DateTime.now();

      emit(
        currentState.copyWith(
          pendingSyncRequest: () => VideoSyncRequest(
            roomId: currentState.roomId!,
            isPlaying: _videoService.isPlaying,
            position: _videoService.position.inMilliseconds,
            userId: currentState.currentUserId!,
            speed: _videoService.rate,
            audioTrack: _videoService.track.audio.id,
            subtitleTrack: _videoService.track.subtitle.id,
          ),
        ),
      );
    }
  }

  Future<void> _onRemoteStateChanged(
    OnRemoteStateChanged event,
    Emitter<VideoPlayerState> emit,
  ) async {
    if (state is! VideoPlayerActive) return;
    var currentState = state as VideoPlayerActive;

    currentState = currentState.copyWith(
      roomId: event.roomId,
      hostId: event.hostId,
      currentUserId: event.currentUserId,
      lastRemoteUpdateTime: event.lastUpdatedAt,
    );

    if (_lastLocalActionTime != null &&
        DateTime.now().difference(_lastLocalActionTime!).inMilliseconds <
            2000) {
      emit(currentState);
      return;
    }

    bool localActionTaken = false;

    // Sync Play/Pause
    if (event.isPlaying != _videoService.isPlaying) {
      if (event.isPlaying) {
        await _videoService.play();
      } else {
        await _videoService.pause();
      }
      localActionTaken = true;
    }

    // Sync Seek
    int currentPos = _videoService.position.inMilliseconds;
    if ((currentPos - event.position).abs() > _kSyncToleranceMs) {
      await _videoService.seek(Duration(milliseconds: event.position));
      localActionTaken = true;
    }

    // Sync Speed
    if ((_videoService.rate - event.speed).abs() > 0.1) {
      await _videoService.setRate(event.speed);
    }

    // Sync Audio Track
    if (event.audioTrack != null &&
        event.audioTrack != _videoService.track.audio.id) {
      final track = _videoService.tracks.audio.firstWhere(
        (t) => t.id == event.audioTrack,
        orElse: () => AudioTrack.auto(),
      );
      await _videoService.setAudioTrack(track);
    }

    // Sync Subtitle Track
    if (event.subtitleTrack != null &&
        event.subtitleTrack != _videoService.track.subtitle.id) {
      final track = _videoService.tracks.subtitle.firstWhere(
        (t) => t.id == event.subtitleTrack,
        orElse: () => SubtitleTrack.auto(),
      );
      await _videoService.setSubtitleTrack(track);
    }

    if (localActionTaken) {
      emit(currentState.copyWith(isSyncing: true));
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!isClosed) {
        if (state is VideoPlayerActive) {
          emit((state as VideoPlayerActive).copyWith(isSyncing: false));
        }
      }
    } else {
      emit(currentState);
    }
  }

  Future<void> _onToggleMinimize(
    ToggleMinimize event,
    Emitter<VideoPlayerState> emit,
  ) async {
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
    await _disposePlayer();
    emit(VideoPlayerInitial());
  }

  Future<void> _disposePlayer() async {
    _playingSubscription?.cancel();
    _positionSubscription?.cancel();
    _rateSubscription?.cancel();
    _bufferingSubscription?.cancel();
    await _videoService.dispose();
  }
}
