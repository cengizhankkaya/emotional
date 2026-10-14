import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// [RTCVideoView] for a screen share that recreates itself whenever the
/// renderer's video size or visibility changes.
///
/// On mobile, flutter_webrtc picks between the video texture and its
/// placeholder only when the parent rebuilds, and Android can keep showing a
/// stale black texture after the incoming resolution changes, which is
/// exactly what happens when a peer switches from camera to screen share.
/// Before this, the share only appeared after something unrelated (like a
/// camera toggle) happened to rebuild the room screen.
class ScreenShareVideoView extends StatelessWidget {
  const ScreenShareVideoView(
    this.renderer, {
    super.key,
    this.objectFit = RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
  });

  final RTCVideoRenderer renderer;
  final RTCVideoViewObjectFit objectFit;

  @override
  Widget build(BuildContext context) {
    // Browsers render into a <video> element that handles size changes, and
    // recreating it would flicker.
    if (kIsWeb) return RTCVideoView(renderer, objectFit: objectFit);

    return ValueListenableBuilder<RTCVideoValue>(
      valueListenable: renderer,
      builder: (context, value, _) => RTCVideoView(
        renderer,
        key: ValueKey((
          identityHashCode(renderer),
          value.renderVideo,
          value.width,
          value.height,
        )),
        objectFit: objectFit,
      ),
    );
  }
}
