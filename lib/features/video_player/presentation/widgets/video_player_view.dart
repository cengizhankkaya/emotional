import 'package:emotional/features/video_player/bloc/video_player_bloc.dart';
import 'package:emotional/features/video_player/bloc/video_player_state.dart';
import 'package:emotional/features/video_player/presentation/widgets/custom_video_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoPlayerView extends StatefulWidget {
  final bool isChatVisible;
  final VoidCallback onToggleChat;
  final VoidCallback onJoinCall;
  final VoidCallback onToggleVideo;
  final VoidCallback onLeaveCall;
  final VoidCallback onToggleFullscreen;

  const VideoPlayerView({
    super.key,
    required this.isChatVisible,
    required this.onToggleChat,
    required this.onJoinCall,
    required this.onToggleVideo,
    required this.onLeaveCall,
    required this.onToggleFullscreen,
  });

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VideoPlayerBloc, VideoPlayerState>(
      listener: (context, state) {},
      builder: (context, vpState) {
        if (vpState is VideoPlayerInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (vpState is VideoPlayerActive) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Video(
                  controller: vpState.controller,
                  controls: NoVideoControls,
                ),
              ),
              CustomVideoControls(
                controller: vpState.controller,
                onToggleFullscreen: widget.onToggleFullscreen,
                onToggleChat: widget.onToggleChat,
                onJoinCall: widget.onJoinCall,
                onToggleVideo: widget.onToggleVideo,
                isChatVisible: widget.isChatVisible,
              ),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
