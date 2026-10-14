@TestOn('browser')
library;

import 'dart:async';

import 'package:emotional/features/call/domain/enums/peer_status.dart';
import 'package:emotional/features/call/service/peer_reconciler.dart';
import 'package:emotional/features/call/service/webrtc_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'support/call_test_support.dart';

/// Real browser peer connections, with Firebase signaling replaced by an
/// in-memory inbox per user that behaves like the database: messages wait
/// there until the recipient listens, and clearing them deletes them.
void main() {
  late SignalBus bus;
  final services = <WebRTCService>[];

  Future<WebRTCService> join(
    String userId, {
    bool isHost = false,
    bool wipesInboxOnStart = false,
    MediaStream? localStream,
  }) async {
    final service = WebRTCService(
      signalingFactory: (roomId, uid) =>
          FakeSignaling(bus, roomId, uid, wipesInboxOnStart: wipesInboxOnStart),
    );
    services.add(service);
    service.updateLocalStream(localStream);
    await service.joinRoom('room', userId, isHost: isHost);
    return service;
  }

  setUp(() => bus = SignalBus());

  tearDown(() async {
    for (final service in services) {
      await service.dispose();
    }
    services.clear();
  });

  test('two peers connect', () async {
    final a = await join('a', isHost: true);
    final b = await join('b');

    await a.connect('b');

    await waitConnected(a, 'b');
    await waitConnected(b, 'a');
  });

  test('an offer sent before the peer joined the call is not lost', () async {
    final a = await join('a', isHost: true);
    // b is in the room but hasn't started its call yet.
    await a.connect('b');
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final b = await join('b');

    await waitConnected(b, 'a');
    await waitConnected(a, 'b');
  });

  test(
    'the host accepts a peer that came back with a new connection',
    () async {
      final a = await join('a', isHost: true);
      final oldB = await join('b');
      await a.connect('b');
      await waitConnected(a, 'b');

      // b's app dies without saying bye (crash, killed tab).
      bus.dropByes = true;
      await oldB.dispose();
      services.remove(oldB);
      bus.dropByes = false;

      final newB = await join('b');
      await newB.connect('a');

      await waitConnected(newB, 'a');
      await waitConnected(a, 'b');
    },
  );

  test('a peer that left with bye can rejoin', () async {
    final a = await join('a', isHost: true);
    final oldB = await join('b');
    final byes = <String>[];
    a.onRemoteBye = byes.add;
    await a.connect('b');
    await waitConnected(a, 'b');

    await oldB.dispose();
    services.remove(oldB);
    await waitFor(() => byes.contains('b'), 'bye from b');
    expect(a.peerStatus('b').status, PeerStatus.none);

    final newB = await join('b');
    await a.connect('b');

    await waitConnected(a, 'b');
    await waitConnected(newB, 'a');
  });

  test('glare: both offering at once still ends up connected', () async {
    final a = await join('a', isHost: true);
    final b = await join('b');

    // Neither call may hang: an SDP call on a connection closed meanwhile
    // never completes on its own.
    await Future.wait([
      a.connect('b'),
      b.connect('a'),
    ]).timeout(const Duration(seconds: 15));

    await waitConnected(a, 'b');
    await waitConnected(b, 'a');
  });

  test('ICE restart renegotiates on the existing connection', () async {
    final a = await join('a', isHost: true);
    final b = await join('b');
    await b.connect('a');
    await waitConnected(a, 'b');
    await waitConnected(b, 'a');
    final hostSide = a.peerConnectionFor('b');
    final guestSide = b.peerConnectionFor('a');

    // The guest restarts ICE; the host used to ignore any offer while it
    // had a connection, so this never completed.
    final offersBefore = bus.answersSent;
    await b.restartIce('a');
    await waitFor(
      () => bus.answersSent > offersBefore,
      'answer to the ICE restart',
    );
    await waitConnected(b, 'a');

    expect(a.peerConnectionFor('b'), same(hostSide));
    expect(b.peerConnectionFor('a'), same(guestSide));
    expect(
      await guestSide!.getSignalingState(),
      RTCSignalingState.RTCSignalingStateStable,
    );
  });

  test(
    'a camera turned on mid-call reaches the peer, no renegotiation',
    () async {
      // Both join with the microphone only, as calls now start.
      final a = await join('a', isHost: true, localStream: microphoneOnly());
      final b = await join('b', localStream: microphoneOnly());
      MediaStream? fromA;
      b.onRemoteStream = (stream, uid) {
        if (uid == 'a') fromA = stream;
      };

      await a.connect('b');
      await waitConnected(a, 'b');
      await waitConnected(b, 'a');
      await waitFor(() => fromA != null, 'stream from a');
      expect(fromA!.getAudioTracks(), hasLength(1));
      expect(
        fromA!.getVideoTracks(),
        hasLength(1),
        reason:
            'the video track must be in the stream from the start, '
            'or the camera turned on later never shows',
      );

      final connection = b.peerConnectionFor('a');
      final camera = fakeCamera();
      await a.replaceLocalAllVideoTrack(camera.track);

      await waitForAsync(
        () async => await videoBytesReceived(b.peerConnectionFor('a')!) > 0,
        'video from a',
      );
      expect(b.peerConnectionFor('a'), same(connection));

      // Camera off: nothing is sent any more, the connection stays.
      await a.removeLocalVideoTrack();
      // dart_webrtc doesn't await the browser's replaceTrack, so the sender
      // lets go of the track a moment later.
      await waitForAsync(() async {
        final senders = await a.peerConnectionFor('b')!.getSenders();
        return senders.every((s) => s.track?.kind != 'video');
      }, 'no video track left on any sender');
      expect(a.peerStatus('b').status, PeerStatus.connected);
      camera.stop();
    },
  );

  group('with the reconcile loop (as CallBloc runs it)', () {
    PeerReconciler reconciler() => PeerReconciler(
      negotiationTimeout: const Duration(seconds: 2),
      calleeGrace: const Duration(milliseconds: 500),
    );

    /// Ticks like CallBloc's timer until [done], offering where told to.
    Future<void> runLoops(
      Map<String, (WebRTCService, PeerReconciler)> peers,
      bool Function() done,
    ) async {
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (!done()) {
        if (DateTime.now().isAfter(deadline)) fail('Peers never connected');
        for (final MapEntry(key: me, value: (service, loop)) in peers.entries) {
          for (final uid in loop.peersToOffer(
            me: me,
            roomUsers: const ['a', 'b'],
            statusOf: service.peerStatus,
            isLeaving: service.isUserPendingBye,
          )) {
            unawaited(service.connect(uid));
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }

    test('retries when an older app wiped the first offer', () async {
      final a = await join('a', isHost: true);
      final aLoop = reconciler()..trackPeerState('b', 1);
      // a offers first; then b (an older app) starts its call and wipes its
      // inbox, offer included. No room update follows.
      for (final uid in aLoop.peersToOffer(
        me: 'a',
        roomUsers: const ['a', 'b'],
        statusOf: a.peerStatus,
      )) {
        await a.connect(uid);
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final b = await join('b', wipesInboxOnStart: true);

      await runLoops(
        {'a': (a, aLoop)},
        () =>
            a.peerStatus('b').status == PeerStatus.connected &&
            b.peerStatus('a').status == PeerStatus.connected,
      );
      expect(
        aLoop.attemptsFor('b'),
        2,
        reason: 'the wiped offer, then one retry',
      );
      expect(
        aLoop.peersToOffer(
          me: 'a',
          roomUsers: const ['a', 'b'],
          statusOf: a.peerStatus,
        ),
        isEmpty,
      );
      expect(aLoop.attemptsFor('b'), 0, reason: 'reset once connected');
    });

    test('the other side steps in when the peer never offers', () async {
      // a would offer first, but runs an older app that never retries;
      // b waits out the grace and offers itself.
      final a = await join('a', isHost: true);
      final b = await join('b');
      final bLoop = reconciler()..trackPeerState('a', 1);

      await runLoops(
        {'b': (b, bLoop)},
        () =>
            a.peerStatus('b').status == PeerStatus.connected &&
            b.peerStatus('a').status == PeerStatus.connected,
      );
    });
  });
}
