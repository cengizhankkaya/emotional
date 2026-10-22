@TestOn('browser')
library;

import 'package:emotional/features/call/domain/enums/peer_status.dart';
import 'package:emotional/features/call/presentation/participant_video.dart';
import 'package:emotional/features/call/service/webrtc_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'support/call_test_support.dart';

/// Audio and video actually flowing between real browser peer connections,
/// with synthetic microphones (a tone) and cameras (a canvas).
void main() {
  late PeerHarness peers;
  final cleanups = <void Function()>[];

  setUp(() => peers = PeerHarness());

  tearDown(() async {
    await peers.dispose();
    for (final cleanup in cleanups) {
      cleanup();
    }
    cleanups.clear();
  });

  ({MediaStream stream, MediaStreamTrack track}) tone() {
    final microphone = toneMicrophone();
    cleanups.add(microphone.stop);
    return (stream: microphone.stream, track: microphone.track);
  }

  MediaStreamTrack camera() {
    final fake = fakeCamera();
    cleanups.add(fake.stop);
    return fake.track;
  }

  /// a and b in a call, each with a humming microphone.
  Future<(WebRTCService, WebRTCService, MediaStreamTrack)>
  callWithTone() async {
    final aMic = tone();
    final a = await peers.join('a', isHost: true, localStream: aMic.stream);
    final b = await peers.join('b', localStream: tone().stream);
    await a.connect('b');
    await waitConnected(a, 'b');
    await waitConnected(b, 'a');
    return (a, b, aMic.track);
  }

  group('audio', () {
    test('flows both ways', () async {
      if (!await audioCanRun()) return markTestSkipped(needsAutoplay);
      final (a, b, _) = await callWithTone();

      await waitForAsync(
        () async => await audioBytesReceived(b.peerConnectionFor('a')!) > 0,
        'audio at b',
      );
      await waitForAsync(
        () async => await audioBytesReceived(a.peerConnectionFor('b')!) > 0,
        'audio at a',
      );
    });

    test('the speaking level falls when the speaker mutes', () async {
      if (!await audioCanRun()) return markTestSkipped(needsAutoplay);
      // What the active-speaker highlight is built on.
      final aMic = tone();
      final a = await peers.join('a', isHost: true, localStream: aMic.stream);
      final b = await peers.join('b', localStream: tone().stream);
      MediaStream? fromA;
      b.onRemoteStream = (stream, uid) => fromA = stream;
      await a.connect('b');
      await waitConnected(b, 'a');
      await waitFor(() => fromA != null, 'stream from a');
      cleanups.add(await playRemoteAudio(fromA!));
      final aMicrophone = aMic.track;

      await waitForAsync(
        () async => await b.getRemoteAudioLevel('a') > 0.01,
        'a to be heard at b',
      );

      aMicrophone.enabled = false; // ToggleMute
      await waitForAsync(
        () async => await b.getRemoteAudioLevel('a') < 0.005,
        'a to go quiet at b',
      );

      aMicrophone.enabled = true;
      await waitForAsync(
        () async => await b.getRemoteAudioLevel('a') > 0.01,
        'a to be heard again',
      );
    });

    test('switching microphones keeps the call and the sound', () async {
      if (!await audioCanRun()) return markTestSkipped(needsAutoplay);
      final (a, b, _) = await callWithTone();
      final connection = b.peerConnectionFor('a')!;
      await waitForGrowth(() => audioBytesReceived(connection), 'audio');

      // Another device picked in the settings, or a lost one replaced.
      final other = tone().track;
      await a.replaceLocalAllAudioTrack(other);

      await waitForAsync(() async {
        final senders = await a.peerConnectionFor('b')!.getSenders();
        return senders.any((s) => s.track?.id == other.id);
      }, 'the new microphone on the sender');
      await waitForGrowth(
        () => audioBytesReceived(connection),
        'audio after switching',
        by: 1000,
      );
      expect(b.peerConnectionFor('a'), same(connection));
      expect(a.peerStatus('b').status, PeerStatus.connected);
    });

    test('three people all hear each other', () async {
      if (!await audioCanRun()) return markTestSkipped(needsAutoplay);
      final a = await peers.join('a', isHost: true, localStream: tone().stream);
      final b = await peers.join('b', localStream: tone().stream);
      final c = await peers.join('c', localStream: tone().stream);
      // The lower ID offers, as the reconcile loop does.
      await a.connect('b');
      await a.connect('c');
      await b.connect('c');

      final everyone = {'a': a, 'b': b, 'c': c};
      for (final MapEntry(key: me, value: service) in everyone.entries) {
        for (final other in everyone.keys.where((id) => id != me)) {
          await waitConnected(service, other);
          await waitForAsync(
            () async =>
                await audioBytesReceived(service.peerConnectionFor(other)!) > 0,
            'audio from $other at $me',
          );
        }
      }
    });

    test('my own speaking level is measured, silence is not', () async {
      if (!await audioCanRun()) return markTestSkipped(needsAutoplay);
      final a = await peers.join('a', isHost: true, localStream: tone().stream);
      final quiet = microphoneOnly();
      final b = await peers.join('b', localStream: quiet);
      await a.connect('b');
      await waitConnected(a, 'b');

      // Sampled every 500 ms for the local speaking highlight.
      await waitForAsync(
        () async => await a.getLocalAudioLevel() > 0.01,
        'a to register its own voice',
      );
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(await b.getLocalAudioLevel(), lessThan(0.005));
    });
  });

  group('video', () {
    test('camera off, then on again, sends video again', () async {
      final (a, b, _) = await callWithTone();
      final connection = b.peerConnectionFor('a')!;

      await a.replaceLocalAllVideoTrack(camera());
      await waitForGrowth(() => videoBytesReceived(connection), 'video');

      await a.removeLocalVideoTrack();
      await waitForAsync(() async {
        final senders = await a.peerConnectionFor('b')!.getSenders();
        return senders.every((s) => s.track?.kind != 'video');
      }, 'video to stop');
      // Nothing more arrives once the sender is empty.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final stopped = await videoBytesReceived(connection);
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(await videoBytesReceived(connection), stopped);

      await a.replaceLocalAllVideoTrack(camera());
      await waitForGrowth(
        () => videoBytesReceived(connection),
        'video after turning the camera back on',
      );
      expect(b.peerConnectionFor('a'), same(connection));
    });

    test(
      'a tall phone picture and a wide laptop one arrive as they are',
      () async {
        // What lets the other side lay out each camera in its own shape.
        final a = await peers.join(
          'a',
          isHost: true,
          localStream: tone().stream,
        );
        final b = await peers.join('b', localStream: tone().stream);
        MediaStream? fromA;
        b.onRemoteStream = (stream, uid) => fromA = stream;
        await a.connect('b');
        await waitConnected(b, 'a');
        await waitFor(() => fromA != null, 'stream from a');
        final renderer = RTCVideoRenderer();
        await renderer.initialize();
        cleanups.add(renderer.dispose);
        renderer.srcObject = fromA;

        final phone = fakeCamera(width: 180, height: 320);
        cleanups.add(phone.stop);
        await a.replaceLocalAllVideoTrack(phone.track);
        await waitFor(
          () =>
              VideoShape.of(renderer.value.aspectRatio) == VideoShape.portrait,
          'a tall picture at b',
        );

        // Turned sideways / another camera: same connection, new shape.
        final laptop = fakeCamera(width: 320, height: 180);
        cleanups.add(laptop.stop);
        await a.replaceLocalAllVideoTrack(laptop.track);
        await waitFor(
          () =>
              VideoShape.of(renderer.value.aspectRatio) == VideoShape.landscape,
          'a wide picture at b',
        );
      },
    );

    test('screen share limits reach the encoder and can be lifted', () async {
      final (a, _, _) = await callWithTone();
      await a.replaceLocalAllVideoTrack(camera());

      Future<RTCRtpEncoding?> videoEncoding() async {
        for (final sender in await a.peerConnectionFor('b')!.getSenders()) {
          if (sender.track?.kind == 'video') {
            return sender.parameters.encodings?.firstOrNull;
          }
        }
        return null;
      }

      await a.setVideoSenderLimits(maxBitrate: 300000, maxFramerate: 10);
      var encoding = await videoEncoding();
      expect(encoding?.maxBitrate, 300000);
      expect(encoding?.maxFramerate, 10);

      // Share over: encoder defaults again.
      await a.setVideoSenderLimits();
      encoding = await videoEncoding();
      expect(encoding?.maxBitrate, isNull);
      expect(encoding?.maxFramerate, isNull);
    });

    test('the camera next to a share gets a small budget, the screen '
        'comes first', () async {
      final (a, _, _) = await callWithTone();
      await a.replaceLocalAllVideoTrack(camera());
      final shareCamera = camera();
      await a.setShareCameraPeers({'b'});
      await a.setShareCamera(shareCamera);

      Future<Map<String, RTCRtpEncoding?>> encodings() async => {
        for (final sender in await a.peerConnectionFor('b')!.getSenders())
          if (sender.track?.kind == 'video')
            sender.track!.id!: sender.parameters.encodings?.first,
      };

      // A second share: its caps are set while the share camera is idle.
      await a.setShareCamera(null);
      await a.setVideoSenderLimits(maxBitrate: 3000000, maxFramerate: 10);
      await a.setShareCamera(shareCamera);
      await waitForAsync(
        () async => (await encodings()).containsKey(shareCamera.id),
        'share camera sending',
      );

      final sent = await encodings();
      final cameraEncoding = sent[shareCamera.id]!;
      final screenEncoding = sent.entries
          .where((e) => e.key != shareCamera.id)
          .single
          .value!;
      expect(cameraEncoding.maxBitrate, 700000);
      expect(cameraEncoding.maxFramerate, isNull, reason: "not the share's");
      expect(cameraEncoding.priority, RTCPriorityType.low);
      expect(screenEncoding.maxBitrate, 3000000);
      expect(screenEncoding.priority, RTCPriorityType.high);

      await a.setVideoSenderLimits();
      final screen = (await encodings()).entries
          .where((e) => e.key != shareCamera.id)
          .single
          .value!;
      expect(screen.priority, RTCPriorityType.low, reason: 'share over');
    });

    test(
      'each viewer keeps the profile ceiling when others join or leave',
      () async {
        final a = await peers.join(
          'a',
          isHost: true,
          localStream: tone().stream,
        );
        final b = await peers.join('b', localStream: tone().stream);
        // Set before connecting: peers joining mid-share inherit the cap.
        await a.setVideoSenderLimits(maxBitrate: 4000000);
        final c = await peers.join('c', localStream: tone().stream);
        for (final (other, id) in [(b, 'b'), (c, 'c')]) {
          await a.connect(id);
          await waitConnected(a, id);
          await waitConnected(other, 'a');
        }
        await a.replaceLocalAllVideoTrack(camera());

        Future<int?> budgetFor(String peer) async {
          for (final sender in await a.peerConnectionFor(peer)!.getSenders()) {
            if (sender.track?.kind == 'video') {
              return sender.parameters.encodings?.first.maxBitrate;
            }
          }
          return null;
        }

        expect(await budgetFor('b'), 4000000);
        expect(await budgetFor('c'), 4000000);

        a.forgetUser('c');
        await waitForAsync(
          () async => await budgetFor('b') == 4000000,
          'b to retain its profile ceiling',
        );
      },
    );

    test('both sides ask for stereo Opus; the audio bitrate can be raised '
        'and restored', () async {
      final (a, b, _) = await callWithTone();
      for (final (side, peer) in [(a, 'b'), (b, 'a')]) {
        final pc = side.peerConnectionFor(peer)!;
        for (final description in [
          await pc.getLocalDescription(),
          await pc.getRemoteDescription(),
        ]) {
          expect(description?.sdp, contains('stereo=1'));
        }
      }

      Future<int?> audioBitrate() async {
        for (final sender in await a.peerConnectionFor('b')!.getSenders()) {
          if (sender.track?.kind == 'audio') {
            return sender.parameters.encodings?.firstOrNull?.maxBitrate;
          }
        }
        return null;
      }

      await a.setAudioSenderBitrate(128000);
      expect(await audioBitrate(), 128000);
      await a.setAudioSenderBitrate(null);
      expect(await audioBitrate(), isNull);
    });

    test(
      'replacing or removing the main video preserves the share camera',
      () async {
        final (a, _, _) = await callWithTone();
        await a.replaceLocalAllVideoTrack(camera());
        final face = camera();
        await a.setShareCameraPeers({'b'});
        await a.setShareCamera(face);
        await waitForAsync(
          () async => (await a.peerConnectionFor('b')!.getSenders()).any(
            (s) => s.track?.id == face.id,
          ),
          'share camera',
        );
        final screen = camera();
        await a.replaceLocalAllVideoTrack(screen);
        await waitForAsync(
          () async => (await a.peerConnectionFor('b')!.getSenders()).any(
            (s) => s.track?.id == screen.id,
          ),
          'screen replacement',
        );
        var senders = await a.peerConnectionFor('b')!.getSenders();
        expect(senders.where((s) => s.track?.id == face.id), hasLength(1));
        expect(senders.where((s) => s.track?.id == screen.id), hasLength(1));
        await a.removeLocalVideoTrack();
        await waitForAsync(
          () async => !(await a.peerConnectionFor('b')!.getSenders()).any(
            (s) => s.track?.id == screen.id,
          ),
          'screen removal',
        );
        senders = await a.peerConnectionFor('b')!.getSenders();
        expect(senders.where((s) => s.track?.id == face.id), hasLength(1));
        expect(senders.where((s) => s.track?.id == screen.id), isEmpty);
      },
    );

    test('a peer joining mid-share gets the same limits', () async {
      final stream = tone().stream;
      await stream.addTrack(camera());
      final a = await peers.join('a', isHost: true, localStream: stream);
      await a.setVideoSenderLimits(maxBitrate: 250000);
      final b = await peers.join('b', localStream: tone().stream);
      await a.connect('b');
      await waitConnected(a, 'b');

      final senders = await a.peerConnectionFor('b')!.getSenders();
      final video = senders.firstWhere((s) => s.track?.kind == 'video');
      expect(video.parameters.encodings?.first.maxBitrate, 250000);
      expect(b.peerStatus('a').status, PeerStatus.connected);
    });
  });
}
