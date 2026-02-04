import 'dart:async';
import 'dart:io';

import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/video_player/bloc/video_player_bloc.dart';
import 'package:emotional/features/video_player/bloc/video_player_event.dart';
import 'package:emotional/features/video_player/presentation/logic/video_sync_manager.dart';
import 'package:emotional/features/video_player/presentation/widgets/video_player_landscape_view.dart';
import 'package:emotional/features/video_player/presentation/widgets/video_player_portrait_view.dart';
import 'package:emotional/features/video_player/presentation/widgets/video_player_view.dart';
import 'package:emotional/features/video_player/presentation/widgets/chat_panel.dart';
import 'package:emotional/features/video_player/presentation/widgets/floating_camera_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';

class VideoPlayerScreen extends StatefulWidget {
  final File videoFile;
  final String roomId;
  final String userId;

  const VideoPlayerScreen({
    super.key,
    required this.videoFile,
    required this.roomId,
    required this.userId,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  // late final Player _player; // Removed local player
  // late final VideoController _controller; // Removed local controller
  VideoSyncManager? _syncManager; // Nullable now as we wait for player
  bool _isChatVisible = true;
  Offset _camerasOffset = const Offset(20, 20);

  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    // Initialize global player
    context.read<VideoPlayerBloc>().add(InitializePlayer(widget.videoFile));
  }

  void _initializeSyncManager(Player player) {
    if (_syncManager != null) return;
    _syncManager = VideoSyncManager(player: player, context: context);
    _setupListeners(player);
    _syncManager!.syncWithRoomState();
  }

  void _setupListeners(Player player) {
    _playingSubscription = player.stream.playing.listen((isPlaying) {
      _syncManager?.onPlayerStateUpdate(isPlaying: isPlaying);
    });

    _positionSubscription = player.stream.position.listen((position) {
      _syncManager?.onPlayerStateUpdate(position: position);
    });
  }

  @override
  void dispose() {
    // Reset orientation to portrait when leaving
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    _playingSubscription?.cancel();
    _positionSubscription?.cancel();
    // Do NOT dispose _player here, as it is global now.
    // The Bloc handles disposal on ClosePlayer event.
    super.dispose();
  }

  void _toggleFullscreen() {
    final orientation = MediaQuery.of(context).orientation;
    if (orientation == Orientation.portrait) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  void _onJoinCall(BuildContext context) {
    if (widget.roomId.isNotEmpty && widget.userId.isNotEmpty) {
      context.read<CallBloc>().add(
        JoinCall(roomId: widget.roomId, userId: widget.userId),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot join call: User/Room info missing'),
        ),
      );
    }
  }

  void _onToggleVideo(BuildContext context) {
    context.read<CallBloc>().add(ToggleVideo());
  }

  void _onLeaveCall(BuildContext context) {
    context.read<CallBloc>().add(LeaveCall());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RoomBloc, RoomState>(
      listener: (context, state) {
        _syncManager?.onRoomStateChanged(state);
        if (state is RoomInitial) {
          Navigator.of(context).pop();
        }
      },
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            // User popped the screen (Back button or Navigator.pop)
            // Stop and Close the player instead of minimizing
            context.read<VideoPlayerBloc>().add(ClosePlayer());
          }
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.black,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    OrientationBuilder(
                      builder: (context, orientation) {
                        final isLandscape =
                            orientation == Orientation.landscape;

                        final videoPlayer = VideoPlayerView(
                          key: const ValueKey(
                            'video_player_view',
                          ), // Added key for state persistence
                          isChatVisible: _isChatVisible,
                          onToggleChat: () =>
                              setState(() => _isChatVisible = !_isChatVisible),
                          onJoinCall: () => _onJoinCall(context),
                          onToggleVideo: () => _onToggleVideo(context),
                          onLeaveCall: () => _onLeaveCall(context),
                          onToggleFullscreen: _toggleFullscreen,
                          onPlayerActive: _initializeSyncManager,
                        );

                        final chatPanel = ChatPanel(
                          isLandscape: isLandscape,
                          onClose: () => setState(() => _isChatVisible = false),
                        );

                        return isLandscape
                            ? VideoPlayerLandscapeView(
                                videoPlayer: videoPlayer,
                                chatPanel: chatPanel,
                                isChatVisible: _isChatVisible,
                              )
                            : VideoPlayerPortraitView(
                                videoPlayer: videoPlayer,
                                chatPanel: chatPanel,
                                isChatVisible: _isChatVisible,
                              );
                      },
                    ),
                    // Full-Screen Floating Participant Cameras
                    BlocBuilder<CallBloc, CallState>(
                      builder: (context, callState) {
                        if (callState is! CallConnected)
                          return const SizedBox.shrink();

                        return FloatingCameraOverlay(
                          constraints: constraints,
                          offset: _camerasOffset,
                          isVideoEnabled: callState.isVideoEnabled,
                          localRenderer: callState.localRenderer,
                          remoteRenderers: callState.remoteRenderers,
                          activeUsers: callState.activeUsers,
                          userVideoStates: callState.userVideoStates,
                          currentUserId: context.read<CallBloc>().userId ?? '',
                          onPositionChanged: (newOffset) {
                            setState(() {
                              _camerasOffset = newOffset;
                            });
                          },
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  bool isChatVisible(BuildContext context) => _isChatVisible;
}
