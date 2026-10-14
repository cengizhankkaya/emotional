import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:dart_webrtc/dart_webrtc.dart' show MediaStreamTrackWeb;
import 'package:emotional/features/call/domain/screen_share/screen_share_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web/web.dart' as web;

abstract final class BrowserScreenCapture {
  static ScreenShareCapabilities? _capabilities;

  static ScreenShareCapabilities get capabilities =>
      _capabilities ??= _detectCapabilities();

  static ScreenShareCapabilities _detectCapabilities() {
    final mediaDevices = web.window.navigator.mediaDevices;
    if (!mediaDevices.has('getDisplayMedia')) {
      return ScreenShareCapabilities.none;
    }
    final supported = mediaDevices.getSupportedConstraints();
    return ScreenShareCapabilities(
      isSupported: true,
      canPreferSurface: _isTrue(supported, 'displaySurface'),
      // Only Chromium captures tab/system audio, and it is also the only
      // engine that knows this constraint.
      canShareAudio: _isTrue(supported, 'suppressLocalAudioPlayback'),
    );
  }

  static bool _isTrue(JSObject object, String property) =>
      object.getProperty<JSAny?>(property.toJS)?.dartify() == true;

  /// Tells the encoder whether to protect sharpness ('detail') or frame rate
  /// ('motion') when bandwidth drops. Applies to every peer automatically.
  static void applyContentHint(MediaStreamTrack track, String hint) {
    if (hint.isEmpty || track is! MediaStreamTrackWeb) return;
    track.jsTrack.contentHint = hint;
  }

  /// What the user actually picked in the browser dialog.
  static ScreenShareSurface surfaceOf(MediaStreamTrack track) {
    if (track is! MediaStreamTrackWeb) return ScreenShareSurface.any;
    final value = track.jsTrack
        .getSettings()
        .getProperty<JSAny?>('displaySurface'.toJS)
        ?.dartify();
    return ScreenShareSurface.fromDisplaySurface(value as String?);
  }
}

/// Mixes the microphone with the shared tab's audio into one track.
///
/// Peers have a single audio sender, so sending one mixed track works with
/// every client (including the mobile apps) without renegotiation. Muting
/// still works: a disabled microphone track feeds silence into the mix.
class ScreenAudioMixer {
  /// Without a user gesture the browser may never start the AudioContext; a
  /// suspended mix would silence the microphone, so give up instead.
  static const Duration _startTimeout = Duration(seconds: 2);

  web.AudioContext? _context;

  Future<MediaStreamTrack> mix({
    MediaStreamTrack? microphone,
    required MediaStreamTrack display,
  }) async {
    await dispose();
    final context = web.AudioContext();
    _context = context;
    final destination = context.createMediaStreamDestination();

    for (final track in [microphone, display]) {
      if (track is! MediaStreamTrackWeb) continue;
      context
          .createMediaStreamSource(web.MediaStream([track.jsTrack].toJS))
          .connect(destination);
    }

    final started = await context
        .resume()
        .toDart
        .then((_) => true)
        .timeout(_startTimeout, onTimeout: () => false);
    final state = context.state;
    if (!started || state != 'running') {
      await dispose();
      throw StateError('AudioContext could not start (state: $state)');
    }
    return MediaStreamTrackWeb(
      destination.stream.getAudioTracks().toDart.first,
    );
  }

  Future<void> dispose() async {
    final context = _context;
    _context = null;
    if (context == null) return;
    try {
      await context.close().toDart;
    } catch (e) {
      debugPrint('[ScreenAudioMixer] Failed to close AudioContext: $e');
    }
  }
}
