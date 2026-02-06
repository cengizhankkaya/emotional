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

  SignalingService({required this.roomId, required this.userId}) {
    _roomSignalRef = _database.ref('rooms/$roomId/signal');
  }

  final Map<String, StreamSubscription> _candidateSubscriptions = {};

  Future<void> initialize() async {
    // We do NOT clear signals here anymore.
    // Signals are cleared in Repository BEFORE joining the room.
    // Clearing here causes race condition (deleting offers sent by others who saw us join).
    listenForIncomingSignals();
  }

  // Create an Offer (Caller)
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

  // Create an Answer (Callee)
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

  // Send Ice Candidate
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

  // Listeners for specific user (My ID)
  // We listen to 'signal/{myUserId}' because others will write there for me.

  OnBye? onRemoteBye;

  // Send Bye
  Future<void> sendBye(String targetUserId) async {
    await _roomSignalRef
        .child(targetUserId)
        .child('bye')
        .child(userId)
        .set(ServerValue.timestamp);
  }

  // Listen for incoming signals for this user (others write to signal/{myUserId})
  void listenForIncomingSignals() {
    final mySignalRef = _roomSignalRef.child(userId);

    _subscriptions.add(
      mySignalRef.child('offers').onChildAdded.listen((event) {
        if (event.snapshot.value == null) return;
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final fromUserId = event.snapshot.key;
        var description = RTCSessionDescription(data['sdp'], data['type']);
        if (fromUserId != null) {
          onRemoteOffer?.call(description, fromUserId);
        }
      }),
    );

    _subscriptions.add(
      mySignalRef.child('answers').onChildAdded.listen((event) {
        if (event.snapshot.value == null) return;
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final fromUserId = event.snapshot.key;
        var description = RTCSessionDescription(data['sdp'], data['type']);
        if (fromUserId != null) {
          onRemoteAnswer?.call(description, fromUserId);
        }
      }),
    );

    _subscriptions.add(
      mySignalRef.child('candidates').onChildAdded.listen((userEvent) {
        final senderId = userEvent.snapshot.key;
        if (senderId == null) return;

        // Prevent duplicate subscriptions for the same user
        _candidateSubscriptions[senderId]?.cancel();

        final innerSub = mySignalRef
            .child('candidates')
            .child(senderId)
            .onChildAdded
            .listen((candidateEvent) {
              if (candidateEvent.snapshot.value == null) return;
              final data = Map<String, dynamic>.from(
                candidateEvent.snapshot.value as Map,
              );
              var candidate = RTCIceCandidate(
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

    _subscriptions.add(
      mySignalRef.child('bye').onChildAdded.listen((event) {
        final fromUserId = event.snapshot.key;
        if (fromUserId != null) {
          onRemoteBye?.call(fromUserId);
          mySignalRef.child('bye').child(fromUserId).remove();
        }
      }),
    );
  }

  Future<void> clearSignal() async {
    final mySignalRef = _roomSignalRef.child(userId);
    await mySignalRef.remove();
  }

  /// Bye aldığımız kullanıcının bize yazdığı offer/answer/candidates'ı siler.
  /// Böylece o kullanıcı tekrar aramaya girince aynı path'e yazacağı offer
  /// yeni child sayılır ve onChildAdded tetiklenir.
  Future<void> clearIncomingFromUser(String fromUserId) async {
    final mySignalRef = _roomSignalRef.child(userId);
    await mySignalRef.child('offers').child(fromUserId).remove();
    await mySignalRef.child('answers').child(fromUserId).remove();
    await mySignalRef.child('candidates').child(fromUserId).remove();
  }

  /// Belirli bir kullanıcıya BİZİM gönderdiğimiz sinyalleri temizler.
  /// Yeni bir bağlantı başlatırken (re-entry gibi) eski sinyallerin karışmasını önler.
  Future<void> clearOutgoingToUser(String targetUserId) async {
    final targetSignalRef = _roomSignalRef.child(targetUserId);
    await targetSignalRef.child('offers').child(userId).remove();
    await targetSignalRef.child('answers').child(userId).remove();
    await targetSignalRef.child('candidates').child(userId).remove();
  }

  void dispose() {
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
