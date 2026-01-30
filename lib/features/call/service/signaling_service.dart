import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef OnRemoteOffer =
    void Function(RTCSessionDescription offer, String fromUserId);
typedef OnRemoteAnswer =
    void Function(RTCSessionDescription answer, String fromUserId);
typedef OnIceCandidate =
    void Function(RTCIceCandidate candidate, String fromUserId);

class SignalingService {
  final String roomId;
  final String userId;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  late DatabaseReference _roomSignalRef;

  // Callbacks
  OnRemoteOffer? onRemoteOffer;
  OnRemoteAnswer? onRemoteAnswer;
  OnIceCandidate? onRemoteIceCandidate;

  SignalingService({required this.roomId, required this.userId}) {
    _roomSignalRef = _database.ref('rooms/$roomId/signal');
  }

  void initialize() {
    _listenToSignal();
  }

  void _listenToSignal() {
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
  void listenForIncomingSignals() {
    final mySignalRef = _roomSignalRef.child(userId);

    // Listen for Offers
    mySignalRef.child('offers').onChildAdded.listen((event) {
      if (event.snapshot.value == null) return;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final fromUserId = event.snapshot.key;

      var description = RTCSessionDescription(data['sdp'], data['type']);
      if (fromUserId != null) {
        onRemoteOffer?.call(description, fromUserId);
      }
    });

    // Listen for Answers
    mySignalRef.child('answers').onChildAdded.listen((event) {
      if (event.snapshot.value == null) return;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final fromUserId = event.snapshot.key;
      var description = RTCSessionDescription(data['sdp'], data['type']);
      if (fromUserId != null) {
        onRemoteAnswer?.call(description, fromUserId);
      }
    });

    // Listen for ICE Candidates
    mySignalRef.child('candidates').onChildAdded.listen((userEvent) {
      final senderId = userEvent.snapshot.key;
      if (senderId == null) return;

      mySignalRef.child('candidates').child(senderId).onChildAdded.listen((
        candidateEvent,
      ) {
        if (candidateEvent.snapshot.value == null) return;
        final data = Map<String, dynamic>.from(
          candidateEvent.snapshot.value as Map,
        );
        var candidate = RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        );
        onRemoteIceCandidate?.call(candidate, senderId);
      });
    });
  }

  void dispose() {
    // Clean up listeners if stored
  }
}
