import 'package:flutter/material.dart';

class VideoPlayerLandscapeView extends StatelessWidget {
  final Widget videoPlayer;
  final Widget? chatPanel;
  final bool isChatVisible;

  const VideoPlayerLandscapeView({
    super.key,
    required this.videoPlayer,
    this.chatPanel,
    required this.isChatVisible,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: videoPlayer),
        if (isChatVisible && chatPanel != null) chatPanel!,
      ],
    );
  }
}
