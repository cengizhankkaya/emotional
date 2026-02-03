import 'dart:ui';
import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/video_player/bloc/video_player_bloc.dart';
import 'package:emotional/features/video_player/bloc/video_player_event.dart';
import 'package:emotional/features/video_player/bloc/video_player_state.dart';
import 'package:emotional/features/video_player/presentation/widgets/video_settings_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
          return MaterialVideoControlsTheme(
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
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                ),
                const Spacer(),
                BlocBuilder<CallBloc, CallState>(
                  builder: (context, callState) {
                    final isConnected = callState is CallConnected;
                    if (!isConnected) {
                      return MaterialCustomButton(
                        onPressed: widget.onJoinCall,
                        icon: const Icon(Icons.videocam, color: Colors.white),
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
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                ),
                const Spacer(),
                BlocBuilder<CallBloc, CallState>(
                  builder: (context, callState) {
                    final isConnected = callState is CallConnected;
                    if (!isConnected) {
                      return MaterialCustomButton(
                        onPressed: widget.onJoinCall,
                        icon: const Icon(Icons.videocam, color: Colors.white),
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
            child: Center(
              child: Video(
                controller: vpState.controller,
                controls: MaterialVideoControls,
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
