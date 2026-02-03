import 'dart:ui';
import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/video_player/bloc/video_player_bloc.dart';
import 'package:emotional/features/video_player/bloc/video_player_event.dart';
import 'package:emotional/features/video_player/bloc/video_player_state.dart';
import 'package:emotional/features/video_player/presentation/widgets/video_settings_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoPlayerView extends StatefulWidget {
  final bool isChatVisible;
  final VoidCallback onToggleChat;
  final VoidCallback onJoinCall;
  final VoidCallback onToggleVideo;
  final VoidCallback onLeaveCall;
  final VoidCallback onToggleFullscreen;
  final Function(Player) onPlayerActive;

  const VideoPlayerView({
    super.key,
    required this.isChatVisible,
    required this.onToggleChat,
    required this.onJoinCall,
    required this.onToggleVideo,
    required this.onLeaveCall,
    required this.onToggleFullscreen,
    required this.onPlayerActive,
  });

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  final Map<String, Offset> _participantPositions = {};
  Offset? _localUserPosition;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VideoPlayerBloc, VideoPlayerState>(
      listener: (context, state) {
        if (state is VideoPlayerActive) {
          widget.onPlayerActive(state.player);
        }
      },
      builder: (context, vpState) {
        if (vpState is VideoPlayerInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (vpState is VideoPlayerActive) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  MaterialVideoControlsTheme(
                    normal: MaterialVideoControlsThemeData(
                      padding: const EdgeInsets.only(
                        bottom: 20,
                        left: 10,
                        right: 10,
                        top: 10,
                      ),
                      bottomButtonBar: [
                        const MaterialPositionIndicator(),
                        const Spacer(),
                        MaterialCustomButton(
                          onPressed: widget.onToggleFullscreen,
                          icon: const Icon(Icons.fullscreen),
                        ),
                      ],
                      topButtonBar: [
                        TextButton.icon(
                          onPressed: () {
                            context.read<VideoPlayerBloc>().add(
                              const ToggleMinimize(isMinimized: true),
                            );
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 20,
                          ),
                          label: const Text(
                            "Odaya Dön",
                            style: TextStyle(color: Colors.white),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        BlocBuilder<CallBloc, CallState>(
                          builder: (context, callState) {
                            final isConnected = callState is CallConnected;
                            if (!isConnected) {
                              return MaterialCustomButton(
                                onPressed: widget.onJoinCall,
                                icon: const Icon(
                                  Icons.videocam,
                                  color: Colors.white,
                                ),
                              );
                            } else {
                              final isVideoEnabled = callState.isVideoEnabled;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  MaterialCustomButton(
                                    onPressed: widget.onToggleVideo,
                                    icon: Icon(
                                      isVideoEnabled
                                          ? Icons.videocam
                                          : Icons.videocam_off,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              );
                            }
                          },
                        ),
                        MaterialCustomButton(
                          onPressed: widget.onToggleChat,
                          icon: Icon(
                            widget.isChatVisible
                                ? Icons.chat_bubble
                                : Icons.chat_bubble_outline,
                            color: Colors.white,
                          ),
                        ),
                        MaterialCustomButton(
                          onPressed: () =>
                              VideoSettingsModal.show(context, vpState.player),
                          icon: const Icon(Icons.settings, color: Colors.white),
                        ),
                      ],
                    ),
                    fullscreen: MaterialVideoControlsThemeData(
                      padding: const EdgeInsets.only(
                        bottom: 24,
                        left: 16,
                        right: 16,
                        top: 16,
                      ),
                      bottomButtonBar: [
                        const MaterialPositionIndicator(),
                        const Spacer(),
                        MaterialCustomButton(
                          onPressed: widget.onToggleFullscreen,
                          icon: const Icon(Icons.fullscreen_exit),
                        ),
                      ],
                      topButtonBar: [
                        TextButton.icon(
                          onPressed: () {
                            context.read<VideoPlayerBloc>().add(
                              const ToggleMinimize(isMinimized: true),
                            );
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 20,
                          ),
                          label: const Text(
                            "Odaya Dön",
                            style: TextStyle(color: Colors.white),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        BlocBuilder<CallBloc, CallState>(
                          builder: (context, callState) {
                            final isConnected = callState is CallConnected;
                            if (!isConnected) {
                              return MaterialCustomButton(
                                onPressed: widget.onJoinCall,
                                icon: const Icon(
                                  Icons.videocam,
                                  color: Colors.white,
                                ),
                              );
                            } else {
                              final isVideoEnabled = callState.isVideoEnabled;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  MaterialCustomButton(
                                    onPressed: widget.onToggleVideo,
                                    icon: Icon(
                                      isVideoEnabled
                                          ? Icons.videocam
                                          : Icons.videocam_off,
                                      color: Colors.white,
                                    ),
                                  ),
                                  MaterialCustomButton(
                                    onPressed: widget.onLeaveCall,
                                    icon: const Icon(
                                      Icons.call_end,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              );
                            }
                          },
                        ),
                        MaterialCustomButton(
                          onPressed: widget.onToggleChat,
                          icon: Icon(
                            widget.isChatVisible
                                ? Icons.chat_bubble
                                : Icons.chat_bubble_outline,
                            color: Colors.white,
                          ),
                        ),
                        MaterialCustomButton(
                          onPressed: () =>
                              VideoSettingsModal.show(context, vpState.player),
                          icon: const Icon(Icons.settings, color: Colors.white),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Video(
                        controller: vpState.controller,
                        controls: MaterialVideoControls,
                      ),
                    ),
                  ),
                  // Floating Draggable Participant Cameras
                  BlocBuilder<CallBloc, CallState>(
                    builder: (context, callState) {
                      if (callState is! CallConnected)
                        return const SizedBox.shrink();

                      final currentUserId = context.read<CallBloc>().userId;
                      final activeUsers = callState.activeUsers.entries
                          .toList();

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Local Camera - Only show if video is enabled
                          if (callState.isVideoEnabled)
                            _buildDraggableCamera(
                              id: 'local',
                              name: 'Ben',
                              hasVideo: true,
                              renderer: callState.localRenderer,
                              isLocal: true,
                              position:
                                  _localUserPosition ?? const Offset(20, 20),
                              constraints: constraints,
                              onPositionChanged: (newOffset) {
                                setState(() => _localUserPosition = newOffset);
                              },
                            ),
                          // Remote Cameras - Only show if video is enabled
                          ...activeUsers
                              .where((entry) {
                                final userId = entry.key;
                                if (userId == currentUserId) return false;
                                return callState.userVideoStates[userId] ??
                                    false;
                              })
                              .map((entry) {
                                final userId = entry.key;
                                final userName = entry.value;
                                final renderer =
                                    callState.remoteRenderers[userId];

                                return _buildDraggableCamera(
                                  id: userId,
                                  name: userName,
                                  hasVideo: true,
                                  renderer: renderer,
                                  isLocal: false,
                                  position:
                                      _participantPositions[userId] ??
                                      Offset(
                                        20,
                                        120 +
                                            (activeUsers.indexOf(entry) * 110),
                                      ),
                                  constraints: constraints,
                                  onPositionChanged: (newOffset) {
                                    setState(
                                      () => _participantPositions[userId] =
                                          newOffset,
                                    );
                                  },
                                );
                              }),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildDraggableCamera({
    required String id,
    required String name,
    required bool hasVideo,
    required bool isLocal,
    RTCVideoRenderer? renderer,
    required Offset position,
    required BoxConstraints constraints,
    required Function(Offset) onPositionChanged,
  }) {
    const double width = 120;
    const double height = 90;

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          final newX = (position.dx + details.delta.dx).clamp(
            0.0,
            constraints.maxWidth - width,
          );
          final newY = (position.dy + details.delta.dy).clamp(
            0.0,
            constraints.maxHeight - height,
          );
          onPositionChanged(Offset(newX, newY));
        },
        child: _buildCameraContainer(
          name,
          hasVideo,
          renderer,
          isLocal,
          false,
          width,
          height,
        ),
      ),
    );
  }

  Widget _buildCameraContainer(
    String name,
    bool hasVideo,
    RTCVideoRenderer? renderer,
    bool isLocal,
    bool isFeedback,
    double width,
    double height,
  ) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // Video or Placeholder
            hasVideo && renderer != null
                ? RTCVideoView(
                    renderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    mirror: isLocal,
                  )
                : Container(
                    color: Colors.white.withOpacity(0.05),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
            // Glass Effect Overlay
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.transparent,
                        Colors.black.withOpacity(0.2),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Name Tag
            Positioned(
              bottom: 4,
              left: 8,
              right: 8,
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
