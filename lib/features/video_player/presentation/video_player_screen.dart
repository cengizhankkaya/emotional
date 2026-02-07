import 'dart:io';

import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/video_player/bloc/video_player_bloc.dart';
import 'package:emotional/features/video_player/bloc/video_player_event.dart';
import 'package:emotional/features/video_player/bloc/video_player_state.dart';
import 'package:emotional/features/video_player/presentation/widgets/chat_panel.dart';
import 'package:emotional/features/video_player/presentation/widgets/draggable_camera_overlay.dart';
import 'package:emotional/features/video_player/presentation/widgets/video_player_landscape_view.dart';
import 'package:emotional/features/video_player/presentation/widgets/video_player_portrait_view.dart';
import 'package:emotional/features/video_player/presentation/widgets/video_player_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  bool _isChatVisible = true;
  Offset _camerasOffset = const Offset(20, 20);

  @override
  void initState() {
    super.initState();
    context.read<VideoPlayerBloc>().add(InitializePlayer(widget.videoFile));

    // Initial sync with room state if already joined
    final roomState = context.read<RoomBloc>().state;
    if (roomState is RoomJoined) {
      context.read<VideoPlayerBloc>().add(
        OnRemoteStateChanged(
          roomId: roomState.roomId,
          isPlaying: roomState.isPlaying,
          position: roomState.position,
          speed: roomState.speed,
          audioTrack: roomState.selectedAudioTrack,
          subtitleTrack: roomState.selectedSubtitleTrack,
          updatedBy: roomState.updatedBy,
          lastUpdatedAt: roomState.lastUpdatedAt,
          hostId: roomState.hostId,
          currentUserId: widget.userId,
        ),
      );
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
    return MultiBlocListener(
      listeners: [
        BlocListener<RoomBloc, RoomState>(
          listener: (context, state) {
            if (state is RoomJoined) {
              context.read<VideoPlayerBloc>().add(
                OnRemoteStateChanged(
                  roomId: state.roomId,
                  isPlaying: state.isPlaying,
                  position: state.position,
                  speed: state.speed,
                  audioTrack: state.selectedAudioTrack,
                  subtitleTrack: state.selectedSubtitleTrack,
                  updatedBy: state.updatedBy,
                  lastUpdatedAt: state.lastUpdatedAt,
                  hostId: state.hostId,
                  currentUserId: widget.userId,
                ),
              );
            } else if (state is RoomInitial) {
              Navigator.of(context).pop();
            }
          },
        ),
        BlocListener<VideoPlayerBloc, VideoPlayerState>(
          listener: (context, state) {
            if (state is VideoPlayerActive &&
                state.pendingSyncRequest != null) {
              final req = state.pendingSyncRequest!;
              context.read<RoomBloc>().add(
                SyncVideoAction(
                  roomId: req.roomId,
                  isPlaying: req.isPlaying,
                  position: req.position,
                  userId: req.userId,
                ),
              );
              // We should ideally clear the request in Bloc, but Bloc does via State copy/generation
              // typically clearing it in next state or via an ack event.
              // Our Bloc implementation uses `pendingSyncRequest` callback which is executed once?
              // `VideoSyncRequest? Function()? pendingSyncRequest` in State?
              // No, in my state definition I used `VideoSyncRequest? pendingSyncRequest`.
              // And `copyWith` usage: `pendingSyncRequest: pendingSyncRequest != null ? pendingSyncRequest() : this.pendingSyncRequest`.
              // This suggests the Bloc emits it once.
              // IF the state persists, this listener might fire again if other parts of state change?
              // `listenWhen` can help.
              // Logic: `listenWhen: (prev, current) => prev.pendingSyncRequest != current.pendingSyncRequest`.
              // But `VideoSyncRequest` supports value equality.
              // So if it's the SAME request object, it won't fire?
              // If Bloc emits a NEW State with SAME request object, Listener fires if I don't use `listenWhen`.
              // Actually `BlocListener` fires on state change.
              // If `pendingSyncRequest` is the same, I should ignore it?
              // Or Bloc should clear it?
              // Ideally Bloc emits state with request, then immediately emits state without it?
              // Or we assume `pendingSyncRequest` is a "One-off" that changes on every needed sync (timestamp/id?).
              // The request has `position`, so it changes.
              // But if position/play status is identical, we don't sync.
              // So it should be fine.
            }
          },
          listenWhen: (previous, current) {
            if (current is VideoPlayerActive && previous is VideoPlayerActive) {
              return current.pendingSyncRequest != previous.pendingSyncRequest;
            }
            return false;
          },
        ),
      ],
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
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
                          key: const ValueKey('video_player_view'),
                          isChatVisible: _isChatVisible,
                          onToggleChat: () =>
                              setState(() => _isChatVisible = !_isChatVisible),
                          onJoinCall: () => _onJoinCall(context),
                          onToggleVideo: () => _onToggleVideo(context),
                          onLeaveCall: () => _onLeaveCall(context),
                          onToggleFullscreen: _toggleFullscreen,
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
                    BlocBuilder<CallBloc, CallState>(
                      builder: (context, callState) {
                        if (callState is! CallConnected)
                          return const SizedBox.shrink();

                        return DraggableCameraOverlay(
                          constraints: constraints,
                          initialOffset: _camerasOffset,
                          isVideoEnabled: callState.isVideoEnabled,
                          localRenderer: callState.localRenderer,
                          remoteRenderers: callState.remoteRenderers,
                          activeUsers: callState.activeUsers,
                          userVideoStates: callState.userVideoStates,
                          currentUserId: context.read<CallBloc>().userId ?? '',
                          onPositionChanged: (newOffset) {
                            // No need to setState periodically if internal widget handles drag,
                            // but we keep track of it if we need to persist or handle orientation changes.
                            _camerasOffset = newOffset;
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
}
