import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';

class VideoPlayerPortraitView extends StatelessWidget {
  final Widget videoPlayer;
  final Widget? chatPanel;
  final bool isChatVisible;

  const VideoPlayerPortraitView({
    super.key,
    required this.videoPlayer,
    this.chatPanel,
    required this.isChatVisible,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isChatVisible) ...[
          SizedBox(height: context.dynamicHeight(0.40), child: videoPlayer),
          Container(height: context.dynamicHeight(0.02), color: Colors.black),
          const Divider(height: 1, color: Colors.white24),
        ] else
          Expanded(child: videoPlayer),
        if (isChatVisible && chatPanel != null) Expanded(child: chatPanel!),
      ],
    );
  }
}
