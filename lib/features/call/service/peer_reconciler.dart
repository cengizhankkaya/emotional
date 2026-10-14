import 'package:emotional/features/call/domain/enums/peer_status.dart';

/// Decides when to (re)offer to each peer so everyone in the call ends up
/// connected without anyone toggling the camera or microphone: late
/// joiners, peers who left the call and came back, and connections that got
/// stuck all get a fresh offer.
///
/// It only decides; CallBloc feeds it room updates and acts on [peersToOffer].
class PeerReconciler {
  PeerReconciler({
    this.negotiationTimeout = const Duration(seconds: 12),
    this.calleeGrace = const Duration(seconds: 4),
    this.slowRetryDelay = const Duration(seconds: 30),
    this.fastRetries = 3,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  /// How long an offer may stay unanswered (or ICE unfinished) before the
  /// connection counts as stuck.
  final Duration negotiationTimeout;

  /// Head start for the peer whose turn it is to offer; it may run an older
  /// app version that never offers otherwise.
  final Duration calleeGrace;

  /// Retry interval once [fastRetries] offers went unanswered, e.g. while
  /// the peer's app is in the background.
  final Duration slowRetryDelay;
  final int fastRetries;

  final DateTime Function() _now;

  /// When each peer joined (or rejoined) the call, as far as we've seen.
  final Map<String, DateTime> _joinedAt = {};

  /// Latest `usersState.updatedAt` per peer; written when a peer joins the
  /// call, so a newer value after they left means they're back.
  final Map<String, int> _stateUpdatedAt = {};

  /// `updatedAt` seen when a peer left the call (bye) but stayed in the room.
  final Map<String, int> _leftCallAt = {};

  final Map<String, DateTime> _lastOfferAt = {};
  final Map<String, int> _offerAttempts = {};

  /// Records a peer's `usersState.updatedAt` from a room update.
  void trackPeerState(String uid, int updatedAt) {
    final wasInCall = isInCall(uid);
    _stateUpdatedAt[uid] = updatedAt;
    final leftAt = _leftCallAt[uid];
    if (leftAt != null && leftAt != updatedAt) _leftCallAt.remove(uid);
    if (!wasInCall && isInCall(uid)) {
      _joinedAt[uid] = _now();
      _clearAttempts(uid);
    }
  }

  /// Peers in the room who never joined the call (or left it) have nobody
  /// listening for offers.
  bool isInCall(String uid) =>
      _stateUpdatedAt.containsKey(uid) && !_leftCallAt.containsKey(uid);

  /// The peer sent bye: they left the call but may still be in the room.
  void peerLeftCall(String uid) {
    _leftCallAt[uid] = _stateUpdatedAt[uid] ?? 0;
    _joinedAt.remove(uid);
    _clearAttempts(uid);
  }

  /// The peer left the room.
  void forget(String uid) {
    _joinedAt.remove(uid);
    _stateUpdatedAt.remove(uid);
    _leftCallAt.remove(uid);
    _clearAttempts(uid);
  }

  void reset() {
    _joinedAt.clear();
    _stateUpdatedAt.clear();
    _leftCallAt.clear();
    _lastOfferAt.clear();
    _offerAttempts.clear();
  }

  /// Peers to send an offer to now; each returned peer counts as offered.
  List<String> peersToOffer({
    required String me,
    required Iterable<String> roomUsers,
    required ({PeerStatus status, Duration since}) Function(String uid)
    statusOf,
    bool Function(String uid)? isLeaving,
  }) {
    final now = _now();
    final offers = <String>[];

    for (final uid in roomUsers) {
      if (uid == me || !isInCall(uid)) continue;
      if (isLeaving?.call(uid) ?? false) continue;

      final peer = statusOf(uid);
      if (peer.status == PeerStatus.connected) {
        _clearAttempts(uid);
        continue;
      }
      if (peer.status == PeerStatus.negotiating &&
          peer.since < negotiationTimeout) {
        continue;
      }

      // The lower ID offers first; the other side only steps in if that
      // doesn't happen.
      final isOurTurn = me.compareTo(uid) < 0;
      final joinedAt = _joinedAt.putIfAbsent(uid, () => now);
      if (!isOurTurn && now.difference(joinedAt) < calleeGrace) continue;

      final attempts = _offerAttempts[uid] ?? 0;
      final lastOffer = _lastOfferAt[uid];
      if (lastOffer != null &&
          now.difference(lastOffer) < _retryDelay(attempts)) {
        continue;
      }

      _offerAttempts[uid] = attempts + 1;
      _lastOfferAt[uid] = now;
      offers.add(uid);
    }
    return offers;
  }

  int attemptsFor(String uid) => _offerAttempts[uid] ?? 0;

  Duration _retryDelay(int attempts) =>
      attempts < fastRetries ? negotiationTimeout : slowRetryDelay;

  void _clearAttempts(String uid) {
    _offerAttempts.remove(uid);
    _lastOfferAt.remove(uid);
  }
}
