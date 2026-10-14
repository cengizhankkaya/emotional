import 'package:emotional/features/call/domain/screen_share/screen_share_options.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

abstract final class BrowserScreenCapture {
  static ScreenShareCapabilities get capabilities =>
      ScreenShareCapabilities.none;

  static void applyContentHint(MediaStreamTrack track, String hint) {}

  static ScreenShareSurface surfaceOf(MediaStreamTrack track) =>
      ScreenShareSurface.any;
}

class ScreenAudioMixer {
  /// Throws [StateError] if the browser won't start audio processing.
  Future<MediaStreamTrack> mix({
    MediaStreamTrack? microphone,
    required MediaStreamTrack display,
  }) => throw UnsupportedError('Screen audio mixing is only available on web');

  Future<void> dispose() async {}
}
