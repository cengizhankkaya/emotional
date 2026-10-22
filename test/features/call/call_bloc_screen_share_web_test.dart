@TestOn('browser')
library;

import 'package:dart_webrtc/dart_webrtc.dart' show MediaStreamTrackWeb;
import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/call/domain/enums/call_quality_preset.dart';
import 'package:emotional/features/call/domain/screen_share/screen_share_options.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web/web.dart' as web;

import 'support/call_bloc_harness.dart';
import 'support/call_test_support.dart';

/// Screen sharing through the whole call stack, on Chrome's fake screen
/// (tool/chrome_with_fake_media.sh answers the browser's picker).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(mockCallPlugins);

  late CallHarness harness;
  setUp(() => harness = CallHarness());
  tearDown(() => harness.dispose());

  Future<void> settle(
    CallBloc bloc,
    bool Function(CallConnected) condition,
    String what,
  ) => waitFor(() {
    final state = bloc.state;
    return state is CallConnected && condition(state);
  }, what);

  CallConnected stateOf(CallBloc bloc) => bloc.state as CallConnected;

  Future<void> startShare(
    CallUser user, {
    ScreenShareProfile profile = ScreenShareProfile.detail,
    bool shareAudio = false,
  }) async {
    user.bloc.add(
      ToggleScreenShare(
        options: ScreenShareOptions(profile: profile, shareAudio: shareAudio),
      ),
    );
    await settle(user.bloc, (s) => s.isScreenSharing, 'the share to start');
  }

  Future<void> stopShare(CallUser user) async {
    user.bloc.add(const ToggleScreenShare());
    await settle(user.bloc, (s) => !s.isScreenSharing, 'the share to end');
  }

  MediaStreamTrack screenTrack(CallUser user) =>
      user.media.screenStream!.getVideoTracks().single;

  /// The track each connection of [user] sends as [kind], once settled
  /// (the browser applies replaceTrack a moment later).
  Future<void> waitForSent(
    CallUser user,
    String peer,
    String kind,
    String? trackId,
    String what,
  ) => waitForAsync(() async {
    final senders = await user.rtc.peerConnectionFor(peer)!.getSenders();
    final sent = senders.where((s) => s.track?.kind == kind);
    return trackId == null
        ? sent.isEmpty
        : sent.any((s) => s.track?.id == trackId);
  }, what);

  Future<RTCRtpEncoding?> videoEncoding(CallUser user, String peer) async {
    final pc = user.rtc.peerConnectionFor(peer)!;
    for (final transceiver in await pc.getTransceivers()) {
      if (transceiver.receiver.track?.kind == 'video') {
        return transceiver.sender.parameters.encodings?.firstOrNull;
      }
    }
    return null;
  }

  Future<int?> audioBitrate(CallUser user, String peer) async {
    final pc = user.rtc.peerConnectionFor(peer)!;
    for (final transceiver in await pc.getTransceivers()) {
      if (transceiver.receiver.track?.kind == 'audio') {
        return transceiver.sender.parameters.encodings?.firstOrNull?.maxBitrate;
      }
    }
    return null;
  }

  Future<(CallUser, CallUser)> twoInACall() async {
    final a = await harness.join('a');
    final b = await harness.join('b');
    await settle(b.bloc, (s) => s.remoteRenderers.containsKey('a'), 'a at b');
    await settle(a.bloc, (s) => s.remoteRenderers.containsKey('b'), 'b at a');
    return (a, b);
  }

  test('the screen replaces the camera for everyone, then the camera '
      'comes back', () async {
    if (!await devicesAvailable()) return markTestSkipped(needsDevices);
    final (a, b) = await twoInACall();
    a.bloc.add(ToggleVideo());
    await settle(a.bloc, (s) => s.isVideoEnabled, 'camera on');
    final camera = a.media.localStream!.getVideoTracks().single;

    await startShare(a);
    final screen = screenTrack(a);
    await waitForSent(a, 'b', 'video', screen.id, 'the screen sent to b');
    await waitFor(
      () => harness.room.mediaState['a']?.isScreenSharing == true,
      'the room to know about the share',
    );
    final connection = b.rtc.peerConnectionFor('a')!;
    await waitForGrowth(() => videoBytesReceived(connection), 'screen at b');

    await stopShare(a);
    final restored = a.media.localStream!.getVideoTracks().single;
    expect(stateOf(a.bloc).isVideoEnabled, isTrue);
    expect(stateOf(a.bloc).activeScreenShare, isNull);
    await waitForSent(a, 'b', 'video', restored.id, 'the camera sent again');
    expect(
      (screen as MediaStreamTrackWeb).jsTrack.readyState,
      'ended',
      reason: 'screen capture released',
    );
    expect(restored.id, isNot(camera.id), reason: 'a fresh camera track');
    await waitFor(
      () => harness.room.mediaState['a']?.isScreenSharing == false,
      'the room to know the share ended',
    );
    expect(b.rtc.peerConnectionFor('a'), same(connection));
  });

  test('viewers learn the share ended before the camera is back', () async {
    if (!await devicesAvailable()) return markTestSkipped(needsDevices);
    final (a, _) = await twoInACall();
    a.bloc.add(ToggleVideo());
    await settle(a.bloc, (s) => s.isVideoEnabled, 'camera on');
    await startShare(a);

    // Stopping reopens the camera and microphone, which can take long (or
    // hang); until the room hears, viewers watch a stopped, black screen.
    bool? captureStillOpen;
    harness.room.onMediaStateWrite = (userId, state) {
      if (userId == 'a' && !state.isScreenSharing) {
        captureStillOpen ??= a.media.screenStream != null;
      }
    };
    await stopShare(a);

    expect(captureStillOpen, isTrue);
    expect(harness.room.mediaState['a']?.isScreenSharing, isFalse);
    expect(harness.room.mediaState['a']?.isVideoEnabled, isTrue);
  });

  test('sharing with the camera off goes back to camera off', () async {
    if (!await devicesAvailable()) return markTestSkipped(needsDevices);
    final (a, _) = await twoInACall();

    await startShare(a);
    await waitForSent(a, 'b', 'video', screenTrack(a).id, 'screen sent');

    await stopShare(a);
    expect(stateOf(a.bloc).isVideoEnabled, isFalse);
    expect(
      a.media.localStream!.getVideoTracks(),
      isEmpty,
      reason: 'stopping a share must not switch the camera on',
    );
    await waitForSent(a, 'b', 'video', null, 'nothing sent as video');
  });

  test('the profile caps the encoder and hints the content; '
      'both go when the share ends', () async {
    if (!await devicesAvailable()) return markTestSkipped(needsDevices);
    final (a, _) = await twoInACall();

    await startShare(a, profile: ScreenShareProfile.motion);
    final screen = screenTrack(a) as MediaStreamTrackWeb;
    expect(screen.jsTrack.contentHint, 'motion');
    expect(
      stateOf(a.bloc).activeScreenShare?.profile,
      ScreenShareProfile.motion,
    );
    final capped = await videoEncoding(a, 'b');
    expect(capped?.maxBitrate, ScreenShareProfile.motion.maxBitrate);
    expect(capped?.maxFramerate, ScreenShareProfile.motion.frameRate);

    await stopShare(a);
    final lifted = await videoEncoding(a, 'b');
    expect(lifted?.maxBitrate, isNull);
    expect(lifted?.maxFramerate, isNull);
  });

  test("the browser's own stop button ends the share in the app", () async {
    if (!await devicesAvailable()) return markTestSkipped(needsDevices);
    final (a, _) = await twoInACall();
    await startShare(a);

    // "Stop sharing" bar, or the shared tab closed.
    (screenTrack(a) as MediaStreamTrackWeb).jsTrack.dispatchEvent(
      web.Event('ended'),
    );

    await settle(a.bloc, (s) => !s.isScreenSharing, 'the app to notice');
    await waitFor(
      () => harness.room.mediaState['a']?.isScreenSharing == false,
      'the room to know',
    );
  });

  test('a camera switched on during a share takes over afterwards', () async {
    if (!await devicesAvailable()) return markTestSkipped(needsDevices);
    final (a, _) = await twoInACall();
    await startShare(a);
    expect(stateOf(a.bloc).isCameraOn, isFalse, reason: 'camera was off');

    a.bloc.add(ToggleVideo());
    await settle(a.bloc, (s) => s.isCameraOn, 'the button to show it on');
    expect(
      a.media.localStream!.getVideoTracks(),
      hasLength(1),
      reason: 'the camera runs, shown next to the share',
    );
    // The screen keeps the main video meanwhile.
    await waitForSent(a, 'b', 'video', screenTrack(a).id, 'still the screen');

    await stopShare(a);
    expect(stateOf(a.bloc).isVideoEnabled, isTrue);
    final camera = a.media.localStream!.getVideoTracks().single;
    await waitForSent(a, 'b', 'video', camera.id, 'the camera afterwards');
  });

  test('a camera switched off during a share stays off afterwards', () async {
    if (!await devicesAvailable()) return markTestSkipped(needsDevices);
    final (a, _) = await twoInACall();
    a.bloc.add(ToggleVideo());
    await settle(a.bloc, (s) => s.isVideoEnabled, 'camera on');
    await startShare(a);
    expect(stateOf(a.bloc).isCameraOn, isTrue);

    a.bloc.add(ToggleVideo());
    await settle(a.bloc, (s) => !s.isCameraOn, 'the button to show it off');
    expect(
      stateOf(a.bloc).isVideoEnabled,
      isTrue,
      reason: 'still sending the screen',
    );

    await stopShare(a);
    expect(stateOf(a.bloc).isVideoEnabled, isFalse);
    expect(a.media.localStream!.getVideoTracks(), isEmpty);
    await waitForSent(a, 'b', 'video', null, 'nothing sent as video');
  });

  test(
    'someone joining mid-share sees the screen, capped like the rest',
    () async {
      if (!await devicesAvailable()) return markTestSkipped(needsDevices);
      final a = await harness.join('a');
      await startShare(a, profile: ScreenShareProfile.detail);

      final b = await harness.join('b');
      await settle(b.bloc, (s) => s.remoteRenderers.containsKey('a'), 'a at b');
      await waitForGrowth(
        () => videoBytesReceived(b.rtc.peerConnectionFor('a')!),
        'the screen at the late joiner',
      );
      final encoding = await videoEncoding(a, 'b');
      expect(encoding?.maxBitrate, ScreenShareProfile.detail.maxBitrate);
    },
  );

  group('camera next to the share', () {
    /// [viewer] shows [sharer]'s camera, and pictures arrive.
    Future<void> waitForShareCamera(CallUser viewer, String sharer) async {
      await settle(
        viewer.bloc,
        (s) => s.shareCameraOf(sharer, localUserId: 'x') != null,
        "$sharer's camera at the viewer",
      );
      final renderer = stateOf(
        viewer.bloc,
      ).shareCameraOf(sharer, localUserId: 'x')!;
      await waitFor(() => renderer.value.width > 0, 'camera pictures');
    }

    Future<void> waitForNoShareCamera(CallUser viewer, String sharer) => settle(
      viewer.bloc,
      (s) => s.shareCameraOf(sharer, localUserId: 'x') == null,
      "$sharer's camera gone at the viewer",
    );

    test('a camera that was on stays visible while sharing', () async {
      if (!await devicesAvailable()) return markTestSkipped(needsDevices);
      final (a, b) = await twoInACall();
      a.bloc.add(ToggleVideo());
      await settle(a.bloc, (s) => s.isVideoEnabled, 'camera on');

      await startShare(a);

      // The screen is still the main video...
      await waitForSent(a, 'b', 'video', screenTrack(a).id, 'screen sent');
      // ...and the camera shows next to it, for b and for a.
      await waitForShareCamera(b, 'a');
      expect(
        stateOf(a.bloc).shareCameraOf('a', localUserId: 'a'),
        isNotNull,
        reason: 'the sharer sees their own camera',
      );
      expect(harness.room.mediaState['a']?.isShareCameraOn, isTrue);
    });

    test('turning the camera off and on mid-share shows at once', () async {
      if (!await devicesAvailable()) return markTestSkipped(needsDevices);
      final (a, b) = await twoInACall();
      await startShare(a);
      expect(stateOf(b.bloc).shareCameraOf('a', localUserId: 'b'), isNull);

      a.bloc.add(ToggleVideo());
      await settle(a.bloc, (s) => s.isCameraOn, 'camera on');
      await waitForShareCamera(b, 'a');
      expect(stateOf(a.bloc).shareCameraOf('a', localUserId: 'a'), isNotNull);

      a.bloc.add(ToggleVideo());
      await settle(a.bloc, (s) => !s.isCameraOn, 'camera off');
      await waitForNoShareCamera(b, 'a');
      expect(stateOf(a.bloc).shareCameraOf('a', localUserId: 'a'), isNull);
      expect(
        a.media.localStream!.getVideoTracks(),
        isEmpty,
        reason: 'the camera (and its light) is off',
      );
      expect(harness.room.mediaState['a']?.isShareCameraOn, isFalse);

      // Again: same connection, no new offer needed.
      final connection = b.rtc.peerConnectionFor('a');
      a.bloc.add(ToggleVideo());
      await waitForShareCamera(b, 'a');
      expect(b.rtc.peerConnectionFor('a'), same(connection));
      expect(stateOf(a.bloc).isScreenSharing, isTrue, reason: 'still sharing');
      await waitForSent(a, 'b', 'video', screenTrack(a).id, 'still the screen');
    });

    test('ending the share puts the camera back as the main video', () async {
      if (!await devicesAvailable()) return markTestSkipped(needsDevices);
      final (a, b) = await twoInACall();
      a.bloc.add(ToggleVideo());
      await settle(a.bloc, (s) => s.isVideoEnabled, 'camera on');
      await startShare(a);
      await waitForShareCamera(b, 'a');

      await stopShare(a);

      await waitForNoShareCamera(b, 'a');
      expect(stateOf(a.bloc).localShareCameraRenderer, isNull);
      expect(harness.room.mediaState['a']?.isShareCameraOn, isFalse);
      final camera = a.media.localStream!.getVideoTracks().single;
      await waitForSent(a, 'b', 'video', camera.id, 'camera as main video');
    });

    test('older apps never get the second video', () async {
      if (!await devicesAvailable()) return markTestSkipped(needsDevices);
      final (a, b) = await twoInACall();
      // b plays an older version: it never said it can show it.
      await harness.room.updateUserMediaState(
        'room',
        'b',
        isVideoEnabled: false,
        isAudioEnabled: true,
        isScreenSharing: false,
        acceptsShareCamera: false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final before =
          (await a.rtc.peerConnectionFor('b')!.getTransceivers()).length;

      a.bloc.add(ToggleVideo());
      await settle(a.bloc, (s) => s.isVideoEnabled, 'camera on');
      await startShare(a);
      await Future<void>.delayed(const Duration(seconds: 1));

      expect(
        (await a.rtc.peerConnectionFor('b')!.getTransceivers()).length,
        before,
        reason: 'no extra video that could replace the screen',
      );
      expect(stateOf(b.bloc).shareCameraRenderers, isEmpty);
      await waitForSent(a, 'b', 'video', screenTrack(a).id, 'the screen');
    });

    test('someone joining mid-share sees the camera too', () async {
      if (!await devicesAvailable()) return markTestSkipped(needsDevices);
      final a = await harness.join('a');
      a.bloc.add(ToggleVideo());
      await settle(a.bloc, (s) => s.isVideoEnabled, 'camera on');
      await startShare(a);

      final b = await harness.join('b');
      await settle(b.bloc, (s) => s.remoteRenderers.containsKey('a'), 'a at b');
      await waitForShareCamera(b, 'a');
    });
  });

  group('tab audio', () {
    test('is mixed into what peers hear, and dropped after', () async {
      if (!await devicesAvailable()) return markTestSkipped(needsDevices);
      if (!await audioCanRun()) return markTestSkipped(needsAutoplay);
      final (a, b) = await twoInACall();
      final microphone = a.media.localStream!.getAudioTracks().single;

      await startShare(a, shareAudio: true);
      final share = stateOf(a.bloc).activeScreenShare!;
      expect(share.audioRequested, isTrue);
      expect(share.hasAudio, isTrue);
      expect(share.isAudioMissing, isFalse);
      // One audio sender carries microphone + tab: a mixed track.
      await waitForAsync(() async {
        final senders = await a.rtc.peerConnectionFor('b')!.getSenders();
        final audio = senders.where((s) => s.track?.kind == 'audio');
        return audio.isNotEmpty &&
            audio.every((s) => s.track!.id != microphone.id);
      }, 'the mix on the audio sender');
      await waitForGrowth(
        () => audioBytesReceived(b.rtc.peerConnectionFor('a')!),
        'audio at b during the share',
      );
      expect(await audioBitrate(a, 'b'), 128000, reason: 'room for music');

      await stopShare(a);
      final after = a.media.localStream!.getAudioTracks().single;
      await waitForSent(a, 'b', 'audio', after.id, 'the plain microphone');
      expect(await audioBitrate(a, 'b'), isNull, reason: 'speech default');
    });

    test('a quality change keeps sending the same mix', () async {
      if (!await devicesAvailable()) return markTestSkipped(needsDevices);
      if (!await audioCanRun()) return markTestSkipped(needsAutoplay);
      final (a, _) = await twoInACall();
      a.bloc.add(ToggleVideo());
      await settle(a.bloc, (s) => s.isVideoEnabled, 'camera on');
      await startShare(a, shareAudio: true);
      expect(stateOf(a.bloc).activeScreenShare!.hasAudio, isTrue);

      Future<String?> sentAudio() async {
        final senders = await a.rtc.peerConnectionFor('b')!.getSenders();
        return senders.where((s) => s.track?.kind == 'audio').single.track?.id;
      }

      final microphone = a.media.localStream!.getAudioTracks().single;
      String? mix;
      await waitForAsync(() async {
        mix = await sentAudio();
        return mix != null && mix != microphone.id;
      }, 'the mix on the audio sender');

      a.bloc.add(const ChangeQuality(CallQualityPreset.low));
      await settle(
        a.bloc,
        (s) => s.currentQuality == CallQualityPreset.low,
        'the quality change',
      );
      expect(await sentAudio(), mix, reason: 'no gap in the sound');
    });

    test('mute is kept across a share with audio', () async {
      if (!await devicesAvailable()) return markTestSkipped(needsDevices);
      if (!await audioCanRun()) return markTestSkipped(needsAutoplay);
      final (a, _) = await twoInACall();
      a.bloc.add(ToggleMute());
      await settle(a.bloc, (s) => s.isMuted, 'muted');

      await startShare(a, shareAudio: true);
      expect(stateOf(a.bloc).isMuted, isTrue);
      await stopShare(a);

      expect(stateOf(a.bloc).isMuted, isTrue);
      expect(a.media.localStream!.getAudioTracks().single.enabled, isFalse);
    });
  });
}
