import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';

class VideoSyncManager {
  final Player player;
  final BuildContext context;
  bool isSyncing = false;
  DateTime? _lastLocalActionTime;

  VideoSyncManager({required this.player, required this.context});

  Future<void> syncWithRoomState() async {
    if (!context.mounted) return;
    isSyncing = true;
    final state = context.read<RoomBloc>().state;
    if (state is RoomJoined) {
      if (state.isPlaying) {
        await player.play();
      } else {
        await player.pause();
      }
      await player.seek(Duration(milliseconds: state.position));

      // Initial Settings Sync
      if ((player.state.rate - state.speed).abs() > 0.1) {
        await player.setRate(state.speed);
      }

      // Allow player to stabilize
      await Future.delayed(const Duration(milliseconds: 1000));
      isSyncing = false;
    } else {
      isSyncing = false;
    }
  }

  void onPlayerStateUpdate({bool? isPlaying, Duration? position}) {
    if (isSyncing) return;

    final state = context.read<RoomBloc>().state;
    if (state is RoomJoined) {
      final currentIsPlaying = isPlaying ?? player.state.playing;
      final currentPosition =
          position?.inMilliseconds ?? player.state.position.inMilliseconds;

      final stateIsPlaying = state.isPlaying;
      final statePosition = state.position;
      final diff = (currentPosition - statePosition).abs();

      if (currentIsPlaying != stateIsPlaying || (diff > 2000)) {
        final authState = context.read<AuthBloc>().state;
        String userId = '';
        if (authState is AuthAuthenticated) {
          userId = authState.user.uid;
        }
        if (userId.isEmpty) return;

        // debugPrint(
        //   'DEBUG: Sync Trigger [Local: $currentIsPlaying] [Remote: $stateIsPlaying] Diff: $diff',
        // );

        if (state.updatedBy != null && state.updatedBy != userId) {
          if (!state.isPlaying) {
            final now = DateTime.now().millisecondsSinceEpoch;
            if ((now - state.lastUpdatedAt).abs() < 2000) {
              debugPrint(
                'DEBUG: Blocked by Guard! Recent update by ${state.updatedBy}',
              );
              return;
            }
          }
        }

        // debugPrint(
        //   'DEBUG: Sending SyncVideoAction (isPlaying: $currentIsPlaying)',
        // );

        // Check if user is Host
        if (state.hostId == userId) {
          if (currentIsPlaying != stateIsPlaying) {
            _lastLocalActionTime = DateTime.now();
            context.read<RoomBloc>().add(
              SyncVideoAction(
                roomId: state.roomId,
                isPlaying: currentIsPlaying,
                position: currentPosition,
                userId: userId,
              ),
            );
          } else if (diff > 2000) {
            _lastLocalActionTime = DateTime.now();
            context.read<RoomBloc>().add(
              SyncVideoAction(
                roomId: state.roomId,
                isPlaying: currentIsPlaying,
                position: currentPosition,
                userId: userId,
              ),
            );
          }
        } else {
          // debugPrint('DEBUG: User is NOT host. Sync skipped.');
        }
      }
    }
  }

  Future<void> onRoomStateChanged(RoomState state) async {
    if (_lastLocalActionTime != null &&
        DateTime.now().difference(_lastLocalActionTime!).inMilliseconds <
            2000) {
      // debugPrint('DEBUG: Ignoring incoming update (Debounce active)');
      return;
    }

    if (state is RoomJoined) {
      bool localActionTaken = false;
      final currentPlayerState = player.state.playing;

      debugPrint(
        'DEBUG: Remote Update Received [Remote: ${state.isPlaying}] [Local: $currentPlayerState]',
      );

      // Sync Play/Pause
      if (state.isPlaying && !currentPlayerState) {
        debugPrint('DEBUG: Executing Remote PLAY');
        isSyncing = true;
        await player.play();
        localActionTaken = true;
      } else if (!state.isPlaying && currentPlayerState) {
        debugPrint('DEBUG: Executing Remote PAUSE');
        isSyncing = true;
        await player.pause();
        localActionTaken = true;
      }

      // Sync Seek
      final currentPos = player.state.position.inMilliseconds;
      if ((currentPos - state.position).abs() > 2000) {
        // debugPrint('DEBUG: Executing Remote SEEK to ${state.position}');
        isSyncing = true;
        await player.seek(Duration(milliseconds: state.position));
        localActionTaken = true;
      }

      if (localActionTaken) {
        await Future.delayed(const Duration(milliseconds: 500));
        isSyncing = false;
      }

      // Sync Speed
      if ((player.state.rate - state.speed).abs() > 0.1) {
        await player.setRate(state.speed);
      }

      // Sync Audio
      if (state.selectedAudioTrack != null &&
          state.selectedAudioTrack != player.state.track.audio.id) {
        final track = player.state.tracks.audio.firstWhere(
          (t) => t.id == state.selectedAudioTrack,
          orElse: () => AudioTrack.auto(),
        );
        if (track.id != 'auto') {
          await player.setAudioTrack(track);
        }
      }

      // Sync Subtitle
      if (state.selectedSubtitleTrack != null &&
          state.selectedSubtitleTrack != player.state.track.subtitle.id) {
        final track = player.state.tracks.subtitle.firstWhere(
          (t) => t.id == state.selectedSubtitleTrack,
          orElse: () => SubtitleTrack.auto(),
        );
        await player.setSubtitleTrack(track);
      }
    }
  }
}
