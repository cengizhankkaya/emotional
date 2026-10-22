import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
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
///
/// While the microphone hears speech the shared sound is turned down
/// ("ducking"), so a voice stays clear over a film or music.
class ScreenAudioMixer {
  /// Without a user gesture the browser may never start the AudioContext; a
  /// suspended mix would silence the microphone, so give up instead.
  static const Duration _startTimeout = Duration(seconds: 2);

  /// The shared sound's volume while someone speaks.
  static const double duckedGain = 0.3;

  /// Microphone RMS above which it counts as speech. A voice close to the
  /// microphone is well above it; shared sound leaking in from speakers,
  /// after the microphone's noise suppression, mostly stays below.
  static const double _speechLevel = 0.02;
  static const Duration _poll = Duration(milliseconds: 50);

  /// Keeps the sound down through the short pauses between words.
  static const Duration _hold = Duration(milliseconds: 600);

  web.AudioContext? _context;
  web.GainNode? _displayGain;
  Timer? _duckTimer;

  /// The shared sound's current volume (1 = as captured).
  @visibleForTesting
  double get displayGain => _displayGain?.gain.value ?? 1;

  Future<MediaStreamTrack> mix({
    MediaStreamTrack? microphone,
    required MediaStreamTrack display,
  }) async {
    await dispose();
    final context = web.AudioContext();
    _context = context;
    final destination = context.createMediaStreamDestination();

    if (display is MediaStreamTrackWeb) {
      final gain = context.createGain();
      _displayGain = gain;
      context
          .createMediaStreamSource(web.MediaStream([display.jsTrack].toJS))
          .connect(gain);
      gain.connect(destination);
    }
    if (microphone is MediaStreamTrackWeb) {
      final source = context.createMediaStreamSource(
        web.MediaStream([microphone.jsTrack].toJS),
      );
      source.connect(destination);
      final analyser = context.createAnalyser()..fftSize = 1024;
      source.connect(analyser);
      _startDucking(context, analyser);
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

  void _startDucking(web.AudioContext context, web.AnalyserNode analyser) {
    final samples = JSFloat32Array.withLength(analyser.fftSize);
    var lastSpeech = DateTime.fromMillisecondsSinceEpoch(0);
    var ducked = false;
    _duckTimer = Timer.periodic(_poll, (_) {
      final gain = _displayGain;
      if (gain == null || _context != context) return;
      analyser.getFloatTimeDomainData(samples);
      var sum = 0.0;
      for (final sample in samples.toDart) {
        sum += sample * sample;
      }
      final now = DateTime.now();
      if (math.sqrt(sum / analyser.fftSize) > _speechLevel) lastSpeech = now;
      final speaking = now.difference(lastSpeech) < _hold;
      if (speaking == ducked) return;
      ducked = speaking;
      // Down fast so the first word is heard, back up gently.
      gain.gain.setTargetAtTime(
        speaking ? duckedGain : 1,
        context.currentTime,
        speaking ? 0.03 : 0.3,
      );
    });
  }

  Future<void> dispose() async {
    _duckTimer?.cancel();
    _duckTimer = null;
    _displayGain = null;
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
