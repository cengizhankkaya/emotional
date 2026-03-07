import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef OnRemoteOffer =
    void Function(RTCSessionDescription offer, String fromUserId);
typedef OnRemoteAnswer =
    void Function(RTCSessionDescription answer, String fromUserId);
typedef OnIceCandidate =
    void Function(RTCIceCandidate candidate, String fromUserId);
typedef OnBye = void Function(String fromUserId);

class SignalingService {
  final String roomId;
  final String userId;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  late DatabaseReference _roomSignalRef;

  /// Tüm sinyal dinleyicileri - dispose'da iptal edilir.
  final List<StreamSubscription<DatabaseEvent>> _subscriptions = [];

  // Callbacks
  OnRemoteOffer? onRemoteOffer;
  OnRemoteAnswer? onRemoteAnswer;
  OnIceCandidate? onRemoteIceCandidate;
  OnBye? onRemoteBye;

  bool _isDisposed = false;

  SignalingService({required this.roomId, required this.userId}) {
    _roomSignalRef = _database.ref('rooms/$roomId/signal');
  }

  final Map<String, StreamSubscription> _candidateSubscriptions = {};

  Future<void> initialize() async {
    // Kendi sinyal node'umuzu temizle: önceki oturumdan kalan
    // eski offer/answer/candidate'ların yeni oturuma karışmasını önler.
    await clearSignal();
    listenForIncomingSignals();
  }

  Future<void> sendOffer(
    String targetUserId,
    RTCSessionDescription description,
  ) async {
    final Map<String, dynamic> offer = {
      'sdp': description.sdp,
      'type': description.type,
    };
    await _roomSignalRef
        .child(targetUserId)
        .child('offers')
        .child(userId)
        .set(offer);
  }

  Future<void> sendAnswer(
    String targetUserId,
    RTCSessionDescription description,
  ) async {
    final Map<String, dynamic> answer = {
      'sdp': description.sdp,
      'type': description.type,
    };
    await _roomSignalRef
        .child(targetUserId)
        .child('answers')
        .child(userId)
        .set(answer);
  }

  Future<void> sendIceCandidate(
    String targetUserId,
    RTCIceCandidate candidate,
  ) async {
    final Map<String, dynamic> candidateMap = {
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    };
    await _roomSignalRef
        .child(targetUserId)
        .child('candidates')
        .child(userId)
        .push()
        .set(candidateMap);
  }

  Future<void> sendBye(String targetUserId) async {
    await _roomSignalRef
        .child(targetUserId)
        .child('bye')
        .child(userId)
        .set(ServerValue.timestamp);
  }

  void listenForIncomingSignals() {
    final mySignalRef = _roomSignalRef.child(userId);

    void handleOfferEvent(DatabaseEvent event) {
      if (_isDisposed) return;
      if (event.snapshot.value == null) return;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final fromUserId = event.snapshot.key;
      final description = RTCSessionDescription(data['sdp'], data['type']);
      if (fromUserId != null) {
        onRemoteOffer?.call(description, fromUserId);
      }
    }

    _subscriptions.add(
      mySignalRef.child('offers').onChildAdded.listen(handleOfferEvent),
    );
    _subscriptions.add(
      mySignalRef.child('offers').onChildChanged.listen(handleOfferEvent),
    );

    void handleAnswerEvent(DatabaseEvent event) {
      if (_isDisposed) return;
      if (event.snapshot.value == null) return;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final fromUserId = event.snapshot.key;
      final description = RTCSessionDescription(data['sdp'], data['type']);
      if (fromUserId != null) {
        onRemoteAnswer?.call(description, fromUserId);
      }
    }

    _subscriptions.add(
      mySignalRef.child('answers').onChildAdded.listen(handleAnswerEvent),
    );
    _subscriptions.add(
      mySignalRef.child('answers').onChildChanged.listen(handleAnswerEvent),
    );

    _subscriptions.add(
      mySignalRef.child('candidates').onChildAdded.listen((userEvent) {
        if (_isDisposed) return;
        final senderId = userEvent.snapshot.key;
        if (senderId == null) return;

        // Prevent duplicate subscriptions for the same sender
        _candidateSubscriptions[senderId]?.cancel();

        final innerSub = mySignalRef
            .child('candidates')
            .child(senderId)
            .onChildAdded
            .listen((candidateEvent) {
              if (_isDisposed) return;
              if (candidateEvent.snapshot.value == null) return;
              final data = Map<String, dynamic>.from(
                candidateEvent.snapshot.value as Map,
              );
              final candidate = RTCIceCandidate(
                data['candidate'],
                data['sdpMid'],
                (data['sdpMLineIndex'] as num?)?.toInt(),
              );
              onRemoteIceCandidate?.call(candidate, senderId);
            });

        _candidateSubscriptions[senderId] = innerSub;
        _subscriptions.add(innerSub);
      }),
    );

    void handleByeEvent(DatabaseEvent event) {
      if (_isDisposed) return;
      final fromUserId = event.snapshot.key;
      if (fromUserId != null) {
        onRemoteBye?.call(fromUserId);
        mySignalRef.child('bye').child(fromUserId).remove();
      }
    }

    _subscriptions.add(
      mySignalRef.child('bye').onChildAdded.listen(handleByeEvent),
    );
    _subscriptions.add(
      mySignalRef.child('bye').onChildChanged.listen(handleByeEvent),
    );
  }

  Future<void> clearSignal() async {
    final mySignalRef = _roomSignalRef.child(userId);
    await mySignalRef.remove();
  }

  Future<void> clearIncomingFromUser(String fromUserId) async {
    final mySignalRef = _roomSignalRef.child(userId);
    await mySignalRef.child('offers').child(fromUserId).remove();
    await mySignalRef.child('answers').child(fromUserId).remove();
    await mySignalRef.child('candidates').child(fromUserId).remove();
  }

  Future<void> clearOutgoingToUser(String targetUserId) async {
    final targetSignalRef = _roomSignalRef.child(targetUserId);
    await targetSignalRef.child('offers').child(userId).remove();
    await targetSignalRef.child('answers').child(userId).remove();
    await targetSignalRef.child('candidates').child(userId).remove();
  }

  void dispose() {
    _isDisposed = true;

    // Null out all callbacks immediately so any in-flight Firebase events
    // that fire after cancel() cannot invoke stale handlers.
    onRemoteOffer = null;
    onRemoteAnswer = null;
    onRemoteIceCandidate = null;
    onRemoteBye = null;

    for (final sub in _subscriptions) {
      sub.cancel();
    }
    for (final sub in _candidateSubscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    _candidateSubscriptions.clear();
  }
}
