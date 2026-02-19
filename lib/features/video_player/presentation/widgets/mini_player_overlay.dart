import 'dart:io';
import 'package:emotional/features/app.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/video_player/bloc/video_player_bloc.dart';
import 'package:emotional/features/video_player/bloc/video_player_event.dart';
import 'package:emotional/features/video_player/bloc/video_player_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:emotional/features/video_player/presentation/video_player_screen.dart';
import 'package:media_kit_video/media_kit_video.dart';

class MiniPlayerOverlay extends StatefulWidget {
  final Widget child;

  const MiniPlayerOverlay({super.key, required this.child});

  @override
  State<MiniPlayerOverlay> createState() => _MiniPlayerOverlayState();
}

class _MiniPlayerOverlayState extends State<MiniPlayerOverlay> {
  Offset _offset = const Offset(20, 100); // Initial position
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main App Content
        widget.child,

        // Mini Player
        BlocBuilder<VideoPlayerBloc, VideoPlayerState>(
          builder: (context, state) {
            if (state is VideoPlayerActive && state.isMinimized) {
              return AnimatedPositioned(
                duration: _isDragging
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: _offset.dx,
                top: _offset.dy,
                child: _buildMiniPlayerContent(context, state),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  void _onPanEnd(DragEndDetails details) {
    final size = MediaQuery.of(context).size;
    const width = 220.0;
    const height = 123.75;
    const padding = 16.0;

    double targetX = _offset.dx;
    double targetY = _offset.dy;

    if (_offset.dx + width / 2 < size.width / 2) {
      targetX = padding;
    } else {
      targetX = size.width - width - padding;
    }

    targetY = targetY.clamp(padding, size.height - height - padding - 40);

    setState(() {
      _isDragging = false;
      _offset = Offset(targetX, targetY);
    });
  }

  Widget _buildMiniPlayerContent(
    BuildContext context,
    VideoPlayerActive state,
  ) {
    // We'll use a GestureDetector for custom dragging which is usually smoother for this use case
    // than the draggable widget behavior for PIP.
    return GestureDetector(
      onPanStart: (_) => setState(() => _isDragging = true),
      onPanUpdate: (details) {
        setState(() {
          _offset += details.delta;
        });
      },
      onPanEnd: _onPanEnd,
      child: AnimatedContainer(
        duration: _isDragging
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: 220,
        height: 123.75,
        decoration: BoxDecoration(
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
          ],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Video
              Video(controller: state.controller, controls: NoVideoControls),
              // Controls Overlay
              // Play/Pause Button (Center)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: IconButton(
                  onPressed: () => state.player.playOrPause(),
                  icon: StreamBuilder<bool>(
                    stream: state.player.stream.playing,
                    builder: (context, snapshot) {
                      final isPlaying = snapshot.data ?? false;
                      return Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 36,
                      );
                    },
                  ),
                ),
              ),

              // Close Button (Top-Right)
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () =>
                      context.read<VideoPlayerBloc>().add(ClosePlayer()),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),

              // Maximize Button (Bottom-Right)
              Positioned(
                bottom: 12,
                right: 6,
                child: GestureDetector(
                  onTap: () {
                    final roomState = context.read<RoomBloc>().state;
                    String roomId = '';
                    String userId = '';

                    if (roomState is RoomJoined) {
                      roomId = roomState.roomId;
                      userId = roomState.userId;
                    } else if (roomState is RoomCreated) {
                      roomId = roomState.roomId;
                      userId = roomState.userId;
                    }

                    context.read<VideoPlayerBloc>().add(
                      const ToggleMinimize(isMinimized: false),
                    );
                    MyApp.navigatorKey.currentState?.push(
                      MaterialPageRoute(
                        builder: (_) => VideoPlayerScreen(
                          videoFile: state.videoFile ?? File(''),
                          youtubeUrl: state.youtubeUrl,
                          roomId: roomId,
                          userId: userId,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.fullscreen_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),

              // Progress Bar (Bottom)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: StreamBuilder<Duration>(
                  stream: state.player.stream.position,
                  builder: (context, posSnap) {
                    return StreamBuilder<Duration>(
                      stream: state.player.stream.duration,
                      builder: (context, durSnap) {
                        final pos = posSnap.data ?? Duration.zero;
                        final dur = durSnap.data ?? Duration.zero;
                        final value = dur.inMilliseconds > 0
                            ? (pos.inMilliseconds / dur.inMilliseconds).clamp(
                                0.0,
                                1.0,
                              )
                            : 0.0;
                        return LinearProgressIndicator(
                          value: value,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.redAccent,
                          ),
                          minHeight: 3,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
