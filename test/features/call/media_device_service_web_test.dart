@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:dart_webrtc/dart_webrtc.dart' show MediaStreamTrackWeb;
import 'package:emotional/features/call/domain/enums/call_quality_preset.dart';
import 'package:emotional/features/call/service/media_device_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web/web.dart' as web;

/// MediaDeviceService against real browser devices: Chrome's fake camera
/// and microphone (tool/chrome_with_fake_media.sh).
void main() {
  late MediaDeviceService media;

  setUp(() => media = MediaDeviceService());
  tearDown(() => media.dispose());

  Future<bool> devicesAvailable() async {
    try {
      final probe = await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
          .toDart;
      for (final track in probe.getTracks().toDart) {
        track.stop();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  const needsDevices =
      'Needs a camera and microphone: run with '
      'CHROME_EXECUTABLE=tool/chrome_with_fake_media.sh';

  /// Makes the browser end [track] as if the device was unplugged.
  void unplug(MediaStreamTrack track) =>
      (track as MediaStreamTrackWeb).jsTrack.dispatchEvent(web.Event('ended'));

  String? readyState(MediaStreamTrack track) =>
      (track as MediaStreamTrackWeb).jsTrack.readyState;

  MediaStreamTrack microphone() => media.localStream!.getAudioTracks().single;

  test('a call starts with the microphone only', () async {
    if (!await devicesAvailable()) return markTestSkipped(needsDevices);
    await media.initialize(enableVideo: false);

    expect(media.localStream!.getAudioTracks(), hasLength(1));
    expect(media.localStream!.getVideoTracks(), isEmpty);
    expect(readyState(microphone()), 'live');
    expect(microphone().enabled, isTrue);
  });

  test('turning the camera on keeps the same microphone running', () async {
    if (!await devicesAvailable()) return markTestSkipped(needsDevices);
    await media.initialize(enableVideo: false);
    final micId = microphone().id;

    final camera = await media.startCamera();

    expect(camera, isNotNull);
    expect(readyState(camera!), 'live');
    expect(media.localStream!.getVideoTracks().single.id, camera.id);
    expect(microphone().id, micId, reason: 'no new microphone');
    expect(readyState(microphone()), 'live');

    final again = await media.startCamera();
    expect(again?.id, camera.id, reason: 'no second camera');
    expect(media.localStream!.getVideoTracks(), hasLength(1));
  });

  test('turning the camera off releases it, not the microphone', () async {
    if (!await devicesAvailable()) return markTestSkipped(needsDevices);
    var lost = 0;
    media.onCameraLost = () => lost++;
    await media.initialize(enableVideo: false);
    final camera = (await media.startCamera())!;

    await media.stopCamera();

    expect(media.localStream!.getVideoTracks(), isEmpty);
    expect(readyState(camera), 'ended', reason: 'the camera light goes off');
    expect(readyState(microphone()), 'live');
    expect(lost, 0, reason: 'our own stop is not a lost camera');
  });

  test('mute disables the microphone without stopping it', () async {
    if (!await devicesAvailable()) return markTestSkipped(needsDevices);
    await media.initialize(enableVideo: false);

    media.toggleMute(true);
    expect(microphone().enabled, isFalse);
    expect(readyState(microphone()), 'live');

    media.toggleMute(false);
    expect(microphone().enabled, isTrue);
  });

  test('quality and camera changes leave a camera that is off, off', () async {
    if (!await devicesAvailable()) return markTestSkipped(needsDevices);
    await media.initialize(enableVideo: false);

    await media.setQuality(CallQualityPreset.low);
    expect(media.localStream!.getVideoTracks(), isEmpty);

    final cameras = await media.getVideoInputs();
    expect(cameras, isNotEmpty);
    await media.selectVideoInput(cameras.first);
    expect(media.localStream!.getVideoTracks(), isEmpty);
    expect(media.selectedVideoDeviceId, cameras.first.deviceId);

    // With the camera on, a quality change keeps it on.
    await media.startCamera();
    await media.setQuality(CallQualityPreset.balanced);
    expect(media.localStream!.getVideoTracks(), hasLength(1));
    expect(media.localStream!.getAudioTracks(), hasLength(1));
  });

  test('the picked quality opens the camera at that size and stays', () async {
    if (!await devicesAvailable()) return markTestSkipped(needsDevices);
    (int?, int?, String?) camera() {
      final track =
          (media.localStream!.getVideoTracks().single as MediaStreamTrackWeb)
              .jsTrack;
      final settings = track.getSettings();
      return (settings.width, settings.height, track.contentHint);
    }

    await media.initialize(enableVideo: false);
    await media.setQuality(CallQualityPreset.high);
    await media.startCamera();
    expect(camera(), (1280, 720, 'detail'));

    // Reopening, as after a screen share, keeps the pick.
    await media.initialize(enableVideo: true);
    expect(media.currentQuality, CallQualityPreset.high);
    expect(camera(), (1280, 720, 'detail'));

    await media.setQuality(CallQualityPreset.low);
    expect(camera(), (480, 360, 'detail'));
  });

  test('a quality change resizes the camera, leaving the microphone', () async {
    if (!await devicesAvailable()) return markTestSkipped(needsDevices);
    await media.initialize(enableVideo: false);
    final camera = (await media.startCamera())!;
    final micId = microphone().id;

    await media.setQuality(CallQualityPreset.low);

    expect(microphone().id, micId, reason: 'no gap in the sound');
    expect(readyState(microphone()), 'live');
    expect(media.localStream!.getVideoTracks().single.id, camera.id);
    final settings = (camera as MediaStreamTrackWeb).jsTrack.getSettings();
    expect((settings.width, settings.height), (480, 360));
  });

  test(
    'switching camera keeps the microphone, and the other way round',
    () async {
      if (!await devicesAvailable()) return markTestSkipped(needsDevices);
      await media.initialize(enableVideo: false);
      final camera = (await media.startCamera())!;
      final micId = microphone().id;

      await media.selectVideoInput((await media.getVideoInputs()).first);
      final newCamera = media.localStream!.getVideoTracks().single;
      expect(newCamera.id, isNot(camera.id));
      expect(readyState(camera), 'ended', reason: 'old camera released');
      expect(microphone().id, micId);

      await media.selectAudioInput((await media.getAudioInputs()).first);
      expect(microphone().id, isNot(micId));
      expect(readyState(microphone()), 'live');
      expect(media.localStream!.getVideoTracks().single.id, newCamera.id);
    },
  );

  test('a camera that is off is not opened by a camera choice', () async {
    if (!await devicesAvailable()) return markTestSkipped(needsDevices);
    await media.initialize(enableVideo: false);
    final micId = microphone().id;

    await media.selectVideoInput((await media.getVideoInputs()).first);

    expect(media.localStream!.getVideoTracks(), isEmpty);
    expect(microphone().id, micId);
  });

  test('speakers come from the browser only', () async {
    if (!await devicesAvailable()) return markTestSkipped(needsDevices);
    await media.initialize(enableVideo: false);
    final outputs = await media.getAudioOutputs();
    expect(
      outputs.map((d) => d.deviceId),
      isNot(anyOf(contains('speaker'), contains('earpiece'))),
      reason: 'the phone placeholders do nothing in a browser',
    );
  });

  test('device lists include the camera and microphone', () async {
    if (!await devicesAvailable()) return markTestSkipped(needsDevices);
    await media.initialize(enableVideo: false);
    expect(await media.getVideoInputs(), isNotEmpty);
    expect(await media.getAudioInputs(), isNotEmpty);
  });

  group('a device going away mid-call', () {
    test('a lost microphone is reported and replaced', () async {
      if (!await devicesAvailable()) return markTestSkipped(needsDevices);
      var lost = 0;
      media.onMicrophoneLost = () => lost++;
      await media.initialize(enableVideo: false);
      final camera = (await media.startCamera())!;
      final old = microphone();

      unplug(old);
      expect(lost, 1);

      final replacement = await media.restartMicrophone();
      expect(replacement, isNotNull);
      expect(replacement!.id, isNot(old.id));
      expect(media.localStream!.getAudioTracks().single.id, replacement.id);
      expect(readyState(replacement), 'live');
      expect(
        media.localStream!.getVideoTracks().single.id,
        camera.id,
        reason: 'the camera stays',
      );
      expect(media.selectedAudioDeviceId, isNull, reason: 'default device');

      // The replacement is watched too.
      unplug(replacement);
      expect(lost, 2);
    });

    test('a lost camera is reported', () async {
      if (!await devicesAvailable()) return markTestSkipped(needsDevices);
      var lost = 0;
      media.onCameraLost = () => lost++;
      await media.initialize(enableVideo: false);
      final camera = (await media.startCamera())!;

      unplug(camera);
      expect(lost, 1);
    });

    test('tracks we already replaced are not reported', () async {
      if (!await devicesAvailable()) return markTestSkipped(needsDevices);
      var lost = 0;
      media.onMicrophoneLost = () => lost++;
      await media.initialize(enableVideo: false);
      final old = microphone();
      await media.restartMicrophone();

      unplug(old);
      expect(lost, 0);
    });
  });
}
