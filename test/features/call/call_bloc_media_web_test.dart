@TestOn('browser')
library;

import 'package:dart_webrtc/dart_webrtc.dart' show MediaStreamTrackWeb;
import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/call/domain/client_platform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web/web.dart' as web;

import 'support/call_bloc_harness.dart';
import 'support/call_test_support.dart';

/// The whole call stack (CallBloc, MediaDeviceService, WebRTCService) on
/// Chrome's fake camera and microphone; only Firebase is replaced.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(mockCallPlugins);

  late CallHarness harness;

  setUp(() => harness = CallHarness());
  tearDown(() => harness.dispose());

  Future<CallUser> join(String userId) => harness.join(userId);

  CallConnected stateOf(CallBloc bloc) => bloc.state as CallConnected;

  Future<void> settle(
    CallBloc bloc,
    bool Function(CallConnected) condition,
    String what,
  ) => waitFor(() {
    final state = bloc.state;
    return state is CallConnected && condition(state);
  }, what);

  void unplug(MediaStreamTrack track) =>
      (track as MediaStreamTrackWeb).jsTrack.dispatchEvent(web.Event('ended'));

  test('joins with the microphone on and the camera off', () async {
    if (!await devicesAvailable()) return markTestSkipped(needsDevices);
    final a = await join('a');

    final state = stateOf(a.bloc);
    expect(state.isMuted, isFalse);
    expect(state.isVideoEnabled, isFalse);
    expect(a.media.localStream!.getAudioTracks(), hasLength(1));
    expect(
      a.media.localStream!.getVideoTracks(),
      isEmpty,
      reason: 'no camera (or camera light) until turned on',
    );
    expect(harness.room.mediaState['a']?.isAudioEnabled, isTrue);
    expect(harness.room.mediaState['a']?.isVideoEnabled, isFalse);
  });

  test('camera on and off: device, state and room stay in step', () async {
    if (!await devicesAvailable()) return markTestSkipped(needsDevices);
    final a = await join('a');

    a.bloc.add(ToggleVideo());
    await settle(a.bloc, (s) => s.isVideoEnabled, 'camera on');
    final camera = a.media.localStream!.getVideoTracks().single;
    expect((camera as MediaStreamTrackWeb).jsTrack.readyState, 'live');
    await waitFor(
      () => harness.room.mediaState['a']?.isVideoEnabled == true,
      'room told about the camera',
    );

    a.bloc.add(ToggleVideo());
    await settle(a.bloc, (s) => !s.isVideoEnabled, 'camera off');
    expect(a.media.localStream!.getVideoTracks(), isEmpty);
    expect(camera.jsTrack.readyState, 'ended', reason: 'camera released');
    await waitFor(
      () => harness.room.mediaState['a']?.isVideoEnabled == false,
      'room told the camera is off',
    );
  });

  test('mute silences the microphone and tells the room', () async {
    if (!await devicesAvailable()) return markTestSkipped(needsDevices);
    final a = await join('a');

    a.bloc.add(ToggleMute());
    await settle(a.bloc, (s) => s.isMuted, 'muted');
    expect(a.media.localStream!.getAudioTracks().single.enabled, isFalse);
    await waitFor(
      () => harness.room.mediaState['a']?.isAudioEnabled == false,
      'room told about mute',
    );

    a.bloc.add(ToggleMute());
    await settle(a.bloc, (s) => !s.isMuted, 'unmuted');
    expect(a.media.localStream!.getAudioTracks().single.enabled, isTrue);
  });

  test('two people connect on their own and see each other', () async {
    if (!await devicesAvailable()) return markTestSkipped(needsDevices);
    final a = await join('a');
    final b = await join('b');

    // Nobody toggles anything: the reconcile loop connects them.
    await settle(
      a.bloc,
      (s) => s.remoteRenderers.containsKey('b'),
      'b to appear at a',
    );
    await settle(
      b.bloc,
      (s) => s.remoteRenderers.containsKey('a'),
      'a to appear at b',
    );

    // a turns the camera on; b receives video on the same connection.
    final connection = b.rtc.peerConnectionFor('a')!;
    a.bloc.add(ToggleVideo());
    await waitForAsync(
      () async => await videoBytesReceived(connection) > 0,
      "a's camera at b",
    );
    expect(b.rtc.peerConnectionFor('a'), same(connection));
  });

  test('everyone sees where the others joined from', () async {
    if (!await devicesAvailable()) return markTestSkipped(needsDevices);
    final a = await join('a');
    final b = await join('b');

    expect(harness.room.mediaState['a']?.platform, 'web');
    await settle(
      a.bloc,
      (s) => s.userPlatforms['b'] == ClientPlatform.web,
      "b's platform at a",
    );
    final state = stateOf(b.bloc);
    expect(state.platformOf('b', localUserId: 'b'), ClientPlatform.web);
    await settle(
      b.bloc,
      (s) => s.platformOf('a', localUserId: 'b') == ClientPlatform.web,
      "a's platform at b",
    );

    // Later media updates don't erase it (the database merges updates).
    a.bloc.add(ToggleMute());
    await waitFor(
      () => harness.room.mediaState['a']?.isAudioEnabled == false,
      'mute in the room',
    );
    expect(harness.room.mediaState['a']?.platform, 'web');

    // An older app version says nothing: no badge rather than a wrong one.
    harness.room.addUser('old');
    await harness.room.updateUserMediaState(
      'room',
      'old',
      isVideoEnabled: false,
      isAudioEnabled: true,
      isScreenSharing: false,
    );
    await settle(
      a.bloc,
      (s) => s.activeUsers.containsKey('old'),
      'the older app at a',
    );
    expect(stateOf(a.bloc).platformOf('old', localUserId: 'a'), isNull);
  });

  group('a device going away mid-call', () {
    test('a lost microphone switches to the default one', () async {
      if (!await devicesAvailable()) return markTestSkipped(needsDevices);
      final a = await join('a');
      final b = await join('b');
      await settle(
        b.bloc,
        (s) => s.remoteRenderers.containsKey('a'),
        'a and b connected',
      );
      final old = a.media.localStream!.getAudioTracks().single;

      unplug(old);

      await settle(
        a.bloc,
        (s) => s.mediaIssue == MediaIssue.microphoneSwitched,
        'the switch to be reported',
      );
      final replacement = a.media.localStream!.getAudioTracks().single;
      expect(replacement.id, isNot(old.id));
      // b now gets the new microphone.
      await waitForAsync(() async {
        final senders = await a.rtc.peerConnectionFor('b')!.getSenders();
        return senders.any((s) => s.track?.id == replacement.id);
      }, 'the new microphone on the connection to b');
      expect(stateOf(a.bloc).isMuted, isFalse, reason: 'mute choice kept');
    });

    test('a lost camera turns video off and says so', () async {
      if (!await devicesAvailable()) return markTestSkipped(needsDevices);
      final a = await join('a');
      a.bloc.add(ToggleVideo());
      await settle(a.bloc, (s) => s.isVideoEnabled, 'camera on');
      final camera = a.media.localStream!.getVideoTracks().single;

      unplug(camera);

      await settle(
        a.bloc,
        (s) => !s.isVideoEnabled && s.mediaIssue == MediaIssue.cameraLost,
        'camera off and reported',
      );
      expect(a.media.localStream!.getVideoTracks(), isEmpty);
      await waitFor(
        () => harness.room.mediaState['a']?.isVideoEnabled == false,
        'room told the camera is off',
      );
    });

    test('a muted user stays muted on the new microphone', () async {
      if (!await devicesAvailable()) return markTestSkipped(needsDevices);
      final a = await join('a');
      a.bloc.add(ToggleMute());
      await settle(a.bloc, (s) => s.isMuted, 'muted');

      unplug(a.media.localStream!.getAudioTracks().single);

      await settle(
        a.bloc,
        (s) => s.mediaIssue == MediaIssue.microphoneSwitched,
        'switched',
      );
      expect(a.media.localStream!.getAudioTracks().single.enabled, isFalse);
      expect(stateOf(a.bloc).isMuted, isTrue);
    });
  });
}
