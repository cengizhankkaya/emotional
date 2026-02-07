import 'dart:async';

import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/video_player/bloc/video_player_bloc.dart';

import 'package:emotional/features/video_player/bloc/video_player_event.dart';
import 'package:emotional/features/video_player/bloc/video_player_state.dart';
import 'package:emotional/features/video_player/presentation/widgets/video_settings_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit_video/media_kit_video.dart';

class CustomVideoControls extends StatefulWidget {
  final VideoController controller;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onToggleChat;
  final VoidCallback onJoinCall;
  final VoidCallback onToggleVideo;
  final bool isChatVisible;

  const CustomVideoControls({
    super.key,
    required this.controller,
    required this.onToggleFullscreen,
    required this.onToggleChat,
    required this.onJoinCall,
    required this.onToggleVideo,
    required this.isChatVisible,
  });

  @override
  State<CustomVideoControls> createState() => _CustomVideoControlsState();
}

class _CustomVideoControlsState extends State<CustomVideoControls>
    with SingleTickerProviderStateMixin {
  bool _isVisible = true;
  Timer? _hideTimer;
  late AnimationController _playPauseAnimController;

  @override
  void initState() {
    super.initState();
    _playPauseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _playPauseAnimController.dispose();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isVisible = false;
        });
      }
    });
  }

  void _toggleVisibility() {
    setState(() {
      _isVisible = !_isVisible;
    });
    if (_isVisible) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _onTap() {
    _toggleVisibility();
  }

  void _onDoubleTapSeek(bool forward) {
    final state = context.read<VideoPlayerBloc>().state;
    if (state is VideoPlayerActive) {
      final currentPos = state.player.state.position;
      final newPos = forward
          ? currentPos + const Duration(seconds: 10)
          : currentPos - const Duration(seconds: 10);

      // Bloc will handle the seek via service call or we can dispatch event?
      // Actually Bloc listens to Remote events. Local actions usually go via `controller` or we dispatch event.
      // Since we want to SYNC this, we should probably update player directly,
      // then `positionStream` fires `OnPlayerStateChanged`, which triggers Sync.
      // MediaKit player.seek triggers position update.

      context.read<VideoPlayerBloc>().add(SeekTo(newPos));

      // Show visual feedback (Ripple/Text) - omitted for brevity, can add overlay later

      _resetHideTimer();
    }
  }

  void _resetHideTimer() {
    if (_isVisible) _startHideTimer();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      onDoubleTapDown: (details) {
        final width = MediaQuery.of(context).size.width;
        if (details.globalPosition.dx < width / 2) {
          _onDoubleTapSeek(false); // Rewind
        } else {
          _onDoubleTapSeek(true); // Forward
        }
      },
      onVerticalDragUpdate: (details) {
        // Implement Volume/Brightness later
      },
      child: Container(
        color: Colors.transparent, // Capture taps
        child: Stack(
          children: [
            // Controls Overlay
            AnimatedOpacity(
              opacity: _isVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black54,
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black54,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.2, 0.8, 1.0],
                  ),
                ),
                child: Column(
                  children: [
                    // Top Bar
                    _buildTopBar(),

                    // Center Area (Play/Pause/Buffering)
                    Expanded(child: _buildCenterArea()),

                    // Bottom Bar
                    _buildBottomBar(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const Expanded(
              child: Text(
                'Video Title',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            BlocBuilder<CallBloc, CallState>(
              builder: (context, callState) {
                final isConnected = callState is CallConnected;
                if (!isConnected) {
                  return IconButton(
                    onPressed: widget.onJoinCall,
                    icon: const Icon(Icons.videocam, color: Colors.white),
                    tooltip: 'Odaya Katıl',
                  );
                } else {
                  final isVideoEnabled = callState.isVideoEnabled;
                  final isMuted = callState.isMuted;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () =>
                            context.read<CallBloc>().add(ToggleMute()),
                        icon: Icon(
                          isMuted ? Icons.mic_off : Icons.mic,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        onPressed: widget.onToggleVideo,
                        icon: Icon(
                          isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
            IconButton(
              icon: Icon(
                widget.isChatVisible
                    ? Icons.chat_bubble
                    : Icons.chat_bubble_outline,
                color: Colors.white,
              ),
              onPressed: () {
                widget.onToggleChat();
                _resetHideTimer();
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: () {
                VideoSettingsModal.show(context, widget.controller.player);
                _resetHideTimer();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterArea() {
    return BlocBuilder<VideoPlayerBloc, VideoPlayerState>(
      buildWhen: (previous, current) {
        if (current is VideoPlayerActive && previous is VideoPlayerActive) {
          return current.isBuffering != previous.isBuffering;
        }
        return false;
      },
      builder: (context, state) {
        if (state is! VideoPlayerActive) return const SizedBox.shrink();

        if (state.isBuffering) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 300;
            final double mainIconSize = isSmall ? 40 : 52;
            final double sideIconSize = isSmall ? 28 : 36;
            final double gap = isSmall ? 12 : 24;

            return Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: sideIconSize,
                    icon: const Icon(Icons.replay_10, color: Colors.white),
                    onPressed: () {
                      _onDoubleTapSeek(false);
                      _resetHideTimer();
                    },
                  ),
                  SizedBox(width: gap),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                    child: StreamBuilder<bool>(
                      stream: state.player.stream.playing,
                      builder: (context, snapshot) {
                        final isPlaying =
                            snapshot.data ?? state.player.state.playing;
                        return IconButton(
                          iconSize: mainIconSize,
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            if (isPlaying) {
                              state.player.pause();
                            } else {
                              state.player.play();
                            }
                            _resetHideTimer();
                          },
                        );
                      },
                    ),
                  ),
                  SizedBox(width: gap),
                  IconButton(
                    iconSize: sideIconSize,
                    icon: const Icon(Icons.forward_10, color: Colors.white),
                    onPressed: () {
                      _onDoubleTapSeek(true);
                      _resetHideTimer();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return BlocBuilder<VideoPlayerBloc, VideoPlayerState>(
      builder: (context, state) {
        if (state is! VideoPlayerActive) return const SizedBox.shrink();

        // We need a stream builder for position/buffer updates to keep slider smooth
        return StreamBuilder<Duration>(
          stream: state.player.stream.position,
          builder: (context, snapshot) {
            final position = snapshot.data ?? Duration.zero;
            final duration = state.player.state.duration;

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          _formatDuration(position),
                          style: const TextStyle(color: Colors.white),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14,
                              ),
                              activeTrackColor: Colors.purpleAccent,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: Colors.white,
                            ),
                            child: Slider(
                              value: position.inMilliseconds.toDouble().clamp(
                                0,
                                duration.inMilliseconds.toDouble(),
                              ),
                              min: 0,
                              max: duration.inMilliseconds.toDouble(),
                              onChanged: (value) {
                                _resetHideTimer();
                                context.read<VideoPlayerBloc>().add(
                                  SeekTo(Duration(milliseconds: value.toInt())),
                                );
                              },
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(duration),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Speed Indicator?
                        Text(
                          "Speed: ${state.player.state.rate}x",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.fullscreen,
                            color: Colors.white,
                          ),
                          onPressed: widget.onToggleFullscreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
