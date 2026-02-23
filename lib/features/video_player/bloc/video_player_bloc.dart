import 'dart:async';

import 'package:emotional/core/services/youtube_service.dart';
import 'package:emotional/features/video_player/bloc/video_player_event.dart';
import 'package:emotional/features/video_player/bloc/video_player_state.dart';
import 'package:emotional/features/video_player/data/services/video_player_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

const int _kSyncToleranceMs = 1500;

class VideoPlayerBloc extends Bloc<VideoPlayerEvent, VideoPlayerState> {
  final VideoPlayerService _videoService;
  final YouTubeService _youtubeService = YouTubeService();

  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<double>? _rateSubscription;
  StreamSubscription<bool>? _bufferingSubscription;
  StreamSubscription<Track>? _trackSubscription;

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
    // Always dispose any existing player before initializing a new one
    // This ensures we don't try to reuse a disposed player
    if (state is VideoPlayerActive) {
      await _disposePlayer();
    }

    await _videoService.initialize();
    final controller = VideoController(_videoService.player);

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

    _trackSubscription = _videoService.trackStream.listen((track) {
      add(
        OnPlayerStateChanged(
          audioTrack: _videoService.player.state.track.audio.id,
          subtitleTrack: _videoService.player.state.track.subtitle.id,
        ),
      );
    });

    String? openPath;
    if (event.url != null) {
      // Resolve YouTube URL
      emit(
        VideoPlayerActive(
          player: _videoService.player,
          controller: controller,
          youtubeUrl: event.url,
          isBuffering: true,
        ),
      );
      openPath = await _youtubeService.getStreamUrl(event.url!);
      if (openPath == null) {
        // Handle error and stop buffering state
        emit(
          VideoPlayerActive(
            player: _videoService.player,
            controller: controller,
            youtubeUrl: event.url,
            isBuffering: false,
          ),
        );
        return;
      }
    } else if (event.file != null) {
      openPath = event.file!.path;
    }

    if (openPath != null) {
      await _videoService.open(openPath);
    }

    // Subscriptions are now setup before opening video

    emit(
      VideoPlayerActive(
        player: _videoService.player,
        controller: controller,
        videoFile: event.file,
        youtubeUrl: event.url,
        isMinimized: false,
        isBuffering: _videoService.isBuffering,
      ),
    );

    // Apply saved track settings if provided
    // Wait a bit for tracks to be loaded by the player
    if (event.savedAudioTrack != null || event.savedSubtitleTrack != null) {
      await Future.delayed(const Duration(milliseconds: 500));

      if (event.savedAudioTrack != null) {
        final availableTracks = _videoService.tracks.audio;
        final savedTrack = availableTracks.firstWhere(
          (track) => track.id == event.savedAudioTrack,
          orElse: () => AudioTrack.auto(),
        );
        if (savedTrack.id == event.savedAudioTrack) {
          await _videoService.setAudioTrack(savedTrack);
        }
      }

      if (event.savedSubtitleTrack != null) {
        final availableTracks = _videoService.tracks.subtitle;
        final savedTrack = availableTracks.firstWhere(
          (track) => track.id == event.savedSubtitleTrack,
          orElse: () => SubtitleTrack.auto(),
        );
        if (savedTrack.id == event.savedSubtitleTrack) {
          await _videoService.setSubtitleTrack(savedTrack);
        }
      }
    }
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

    // CRITICAL FIX: Check if this is a real videoState update or just a usersState update
    // If the videoState timestamp hasn't changed, this is likely just a media state update
    // (mic/camera toggle) and we should NOT sync video playback
    final isVideoStateUpdate =
        currentState.lastVideoStateTimestamp == null ||
        event.lastUpdatedAt != currentState.lastVideoStateTimestamp;

    currentState = currentState.copyWith(
      roomId: event.roomId,
      hostId: event.hostId,
      currentUserId: event.currentUserId,
      lastRemoteUpdateTime: event.lastUpdatedAt,
      lastVideoStateTimestamp: event.lastUpdatedAt,
    );

    if (_lastLocalActionTime != null &&
        DateTime.now().difference(_lastLocalActionTime!).inMilliseconds <
            2000) {
      emit(currentState);
      return;
    }

    // Skip video sync if only media state changed (not videoState)
    if (!isVideoStateUpdate) {
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
    _trackSubscription?.cancel();
    await _videoService.dispose();
  }

  @override
  Future<void> close() {
    _youtubeService.dispose();
    return super.close();
  }
}
