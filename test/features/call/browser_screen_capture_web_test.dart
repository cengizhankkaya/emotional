@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:dart_webrtc/dart_webrtc.dart' show MediaStreamTrackWeb;
import 'package:emotional/features/call/domain/screen_share/screen_share_options.dart';
import 'package:emotional/features/call/service/screen_share/browser_screen_capture.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

import 'support/call_test_support.dart';

/// A live video track without camera or screen permissions.
MediaStreamTrackWeb _canvasTrack() {
  final canvas = web.HTMLCanvasElement()
    ..width = 64
    ..height = 64;
  return MediaStreamTrackWeb(
    canvas.captureStream().getVideoTracks().toDart.first,
  );
}

/// A live audio track without microphone permissions.
MediaStreamTrackWeb _toneTrack(web.AudioContext context) {
  final destination = context.createMediaStreamDestination();
  context.createOscillator()
    ..connect(destination)
    ..start();
  return MediaStreamTrackWeb(destination.stream.getAudioTracks().toDart.first);
}

void main() {
  test('detects screen share support in Chromium', () {
    final capabilities = BrowserScreenCapture.capabilities;

    expect(capabilities.isSupported, isTrue);
    expect(capabilities.canPreferSurface, isTrue);
    expect(capabilities.canShareAudio, isTrue);
  });

  test('applies the profile content hint to the track', () {
    final track = _canvasTrack();

    BrowserScreenCapture.applyContentHint(track, 'detail');

    expect(track.jsTrack.contentHint, 'detail');
  });

  test('an empty hint leaves the track untouched', () {
    final track = _canvasTrack();

    BrowserScreenCapture.applyContentHint(track, '');

    expect(track.jsTrack.contentHint, '');
  });

  test('reports an unknown surface for non-display tracks', () {
    expect(
      BrowserScreenCapture.surfaceOf(_canvasTrack()),
      ScreenShareSurface.any,
    );
  });

  // Whether audio may start depends on the browser's autoplay policy (the
  // app always mixes after a click). Either way the mixer must settle fast:
  // a live mixed track, or a StateError so the call keeps the plain mic.
  Future<void> expectMixSettles({required bool withMicrophone}) async {
    final sources = web.AudioContext();
    final mixer = ScreenAudioMixer();
    try {
      final mixed =
          await mixer.mix(
                microphone: withMicrophone ? _toneTrack(sources) : null,
                display: _toneTrack(sources),
              )
              as MediaStreamTrackWeb;
      expect(mixed.kind, 'audio');
      expect(mixed.jsTrack.readyState, 'live');
      debugPrint('mixer: audio started, mixed track is live');
    } on StateError catch (e) {
      debugPrint('mixer: audio blocked by autoplay policy ($e)');
    } finally {
      await mixer.dispose();
      await sources.close().toDart;
    }
  }

  test(
    'mixes microphone and screen audio into one live track',
    () => expectMixSettles(withMicrophone: true),
    timeout: const Timeout(Duration(seconds: 5)),
  );

  test(
    'mixes screen audio alone when there is no microphone',
    () => expectMixSettles(withMicrophone: false),
    timeout: const Timeout(Duration(seconds: 5)),
  );

  test('turns the shared sound down while someone speaks', () async {
    if (!await audioCanRun()) return markTestSkipped(needsAutoplay);
    final sources = web.AudioContext();
    final mixer = ScreenAudioMixer();
    try {
      final microphone = _toneTrack(sources);
      await mixer.mix(microphone: microphone, display: _toneTrack(sources));

      // The tone is far louder than speech needs to be.
      await waitFor(
        () => mixer.displayGain < ScreenAudioMixer.duckedGain + 0.1,
        'the shared sound to go down',
      );

      // Muted (or silent), the shared sound comes back.
      microphone.enabled = false;
      await waitFor(
        () => mixer.displayGain > 0.9,
        'the shared sound to come back',
      );
    } finally {
      await mixer.dispose();
      await sources.close().toDart;
    }
  });

  test('without a microphone the shared sound stays as it is', () async {
    if (!await audioCanRun()) return markTestSkipped(needsAutoplay);
    final sources = web.AudioContext();
    final mixer = ScreenAudioMixer();
    try {
      await mixer.mix(display: _toneTrack(sources));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(mixer.displayGain, 1);
    } finally {
      await mixer.dispose();
      await sources.close().toDart;
    }
  });
}
