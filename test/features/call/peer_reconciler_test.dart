import 'package:emotional/features/call/domain/enums/peer_status.dart';
import 'package:emotional/features/call/service/peer_reconciler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late PeerReconciler reconciler;
  late Map<String, ({PeerStatus status, Duration since})> statuses;

  ({PeerStatus status, Duration since}) statusOf(String uid) =>
      statuses[uid] ?? (status: PeerStatus.none, since: Duration.zero);

  List<String> offers({
    String me = 'b',
    List<String> room = const ['a', 'b', 'c'],
    Set<String> leaving = const {},
  }) => reconciler.peersToOffer(
    me: me,
    roomUsers: room,
    statusOf: statusOf,
    isLeaving: leaving.contains,
  );

  void advance(Duration by) => now = now.add(by);

  setUp(() {
    now = DateTime(2026, 1, 1, 12);
    statuses = {};
    reconciler = PeerReconciler(clock: () => now);
  });

  group('who to offer', () {
    test('offers right away to an unconnected peer when it is our turn', () {
      reconciler.trackPeerState('c', 1);
      expect(offers(), ['c']);
    });

    test('gives the peer whose turn it is a head start', () {
      reconciler.trackPeerState('a', 1);
      expect(offers(), isEmpty);
      advance(const Duration(seconds: 3));
      expect(offers(), isEmpty);
      advance(const Duration(seconds: 2));
      expect(offers(), ['a'], reason: 'steps in once the grace is over');
    });

    test('skips peers who never joined the call', () {
      // In the room (no usersState yet): nobody listens for offers.
      expect(offers(), isEmpty);
    });

    test('skips itself, connected peers and peers sending bye', () {
      reconciler.trackPeerState('b', 1);
      reconciler.trackPeerState('c', 1);
      reconciler.trackPeerState('d', 1);
      statuses['c'] = (status: PeerStatus.connected, since: Duration.zero);
      expect(offers(room: ['a', 'b', 'c', 'd'], leaving: {'d'}), isEmpty);
    });

    test('leaves a negotiation in progress alone until it times out', () {
      reconciler.trackPeerState('c', 1);
      statuses['c'] = (
        status: PeerStatus.negotiating,
        since: const Duration(seconds: 5),
      );
      expect(offers(), isEmpty);
      statuses['c'] = (
        status: PeerStatus.negotiating,
        since: const Duration(seconds: 13),
      );
      expect(offers(), ['c'], reason: 'a stuck negotiation is retried');
    });
  });

  group('retries', () {
    test('retries an unanswered offer without anyone toggling media', () {
      reconciler.trackPeerState('c', 1);
      expect(offers(), ['c']);

      // Still nothing back from c.
      advance(const Duration(seconds: 6));
      expect(offers(), isEmpty, reason: 'too early to retry');
      advance(const Duration(seconds: 6));
      expect(offers(), ['c']);
    });

    test('never gives up, but slows down after the fast retries', () {
      reconciler.trackPeerState('c', 1);
      for (var i = 0; i < 3; i++) {
        expect(offers(), ['c']);
        advance(const Duration(seconds: 12));
      }
      expect(offers(), isEmpty, reason: 'now waits the slow retry delay');
      advance(const Duration(seconds: 18));
      expect(offers(), ['c']);
      expect(reconciler.attemptsFor('c'), 4);
    });

    test('a connection resets the retry count', () {
      reconciler.trackPeerState('c', 1);
      offers();
      statuses['c'] = (status: PeerStatus.connected, since: Duration.zero);
      offers();
      expect(reconciler.attemptsFor('c'), 0);

      // It drops later: offered again immediately.
      statuses['c'] = (status: PeerStatus.none, since: Duration.zero);
      expect(offers(), ['c']);
    });
  });

  group('leaving and rejoining', () {
    test('stops offering to a peer that left the call', () {
      reconciler.trackPeerState('c', 1);
      reconciler.peerLeftCall('c');
      expect(reconciler.isInCall('c'), isFalse);
      expect(offers(), isEmpty);

      // Room updates repeating the same usersState keep them out.
      reconciler.trackPeerState('c', 1);
      expect(offers(), isEmpty);
    });

    test('rejoining the call (new usersState) brings them back at once', () {
      reconciler.trackPeerState('c', 1);
      offers();
      offers();
      reconciler.peerLeftCall('c');

      reconciler.trackPeerState('c', 2);
      expect(reconciler.isInCall('c'), isTrue);
      expect(offers(), ['c']);
      expect(reconciler.attemptsFor('c'), 1, reason: 'fresh attempt count');
    });

    test('a rejoining peer whose turn it is gets a new head start', () {
      reconciler.trackPeerState('a', 1);
      advance(const Duration(minutes: 1));
      reconciler.peerLeftCall('a');
      reconciler.trackPeerState('a', 2);
      expect(offers(), isEmpty);
      advance(const Duration(seconds: 5));
      expect(offers(), ['a']);
    });

    test('a peer that left the room starts over when they return', () {
      reconciler.trackPeerState('c', 1);
      reconciler.peerLeftCall('c');
      reconciler.forget('c');
      reconciler.trackPeerState('c', 1);
      expect(offers(), ['c']);
    });

    test('reset forgets everything (our own rejoin)', () {
      reconciler.trackPeerState('c', 1);
      offers();
      reconciler.reset();
      expect(reconciler.isInCall('c'), isFalse);
      expect(reconciler.attemptsFor('c'), 0);
    });
  });

  test('late joiner: both sides converge without a room update', () {
    // b was alone; c joins the room and then the call.
    expect(offers(), isEmpty);
    reconciler.trackPeerState('c', 7);
    expect(offers(), ['c']);

    // c (an older app) cleared the offer while starting its call; no room
    // update follows. The timer tick alone retries.
    advance(const Duration(seconds: 12));
    expect(offers(), ['c']);
  });
}
