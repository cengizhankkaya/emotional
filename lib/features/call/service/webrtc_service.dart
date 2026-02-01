import 'dart:async';
import 'package:emotional/features/call/domain/services/i_call_service.dart';
import 'package:emotional/features/call/service/signaling_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService implements ICallService {
  SignalingService? _signalingService;
  final Map<String, RTCPeerConnection> _peerConnections = {};

  // Configuration
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
        ],
      },
    ],
  };

  // Deprecated usage of public stream for external access if needed,
  // but strictly we should use onRemoteStream callback.

  @override
  Function(MediaStream stream, String userId)? onRemoteStream;

  @override
  Function(String userId)? onRemoteStreamRemoved;

  // We need to keep track of the local stream to add it to new connections
  MediaStream? _localStream;

  // Method to update local stream (e.g. when device changes)
  // This is not in ICallService but specific to implementation that needs to re-add tracks
  void updateLocalStream(MediaStream? stream) {
    _localStream = stream;
    _peerConnections.values.forEach((pc) {
      // Replacing tracks is complex, for simple V1 we might re-negotiate or use replaceTrack
      // For now, let's assume we might need to use replaceTrack sender logic if we want smooth switch
      // Or just simple:
      if (stream != null) {
        stream.getTracks().forEach((track) {
          pc.addTrack(track, stream);
        });
      }
    });
    // Note: Proper track replacement is more involved than just addTrack loop for existing connections.
    // Ideally we find RtcRtpSender and replaceTrack.
    // For this pass, we will focus on initial connection.
    // TODO: Implement replaceTrack for established connections.
  }

  // Specific helper to replace track for all peers
  Future<void> replaceLocalAllVideoTrack(MediaStreamTrack newTrack) async {
    for (var pc in _peerConnections.values) {
      var senders = await pc.getSenders();
      for (var sender in senders) {
        if (sender.track?.kind == 'video') {
          await sender.replaceTrack(newTrack);
        }
      }
    }
  }

  Future<void> replaceLocalAllAudioTrack(MediaStreamTrack newTrack) async {
    for (var pc in _peerConnections.values) {
      var senders = await pc.getSenders();
      for (var sender in senders) {
        if (sender.track?.kind == 'audio') {
          await sender.replaceTrack(newTrack);
        }
      }
    }
  }

  @override
  Future<void> initialize() async {
    // Nothing to init globally yet, room specific init happens in joinRoom
  }

  @override
  Future<void> joinRoom(String roomId, String userId) async {
    _signalingService = SignalingService(roomId: roomId, userId: userId);
    _signalingService!.initialize();

    _setupSignalingListeners();
  }

  void _setupSignalingListeners() {
    if (_signalingService == null) return;

    _signalingService!.onRemoteOffer = (description, fromUserId) async {
      await _handleRemoteOffer(description, fromUserId);
    };

    _signalingService!.onRemoteAnswer = (description, fromUserId) async {
      await _handleRemoteAnswer(description, fromUserId);
    };

    _signalingService!.onRemoteIceCandidate = (candidate, fromUserId) async {
      await _handleRemoteIceCandidate(candidate, fromUserId);
    };

    _signalingService!.onRemoteBye = (fromUserId) async {
      await _handleRemoteBye(fromUserId);
    };
  }

  @override
  Future<void> leaveRoom() async {
    if (_signalingService != null) {
      // Send bye to all
      for (var userId in _peerConnections.keys) {
        await _signalingService!.sendBye(userId);
      }
      await _signalingService!.clearSignal();
      _signalingService!.dispose();
      _signalingService = null;
    }

    for (var pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();
  }

  @override
  Future<RTCPeerConnection> createPeerConnection(String targetUserId) async {
    final pc = await webrtc.createPeerConnection(_configuration);

    // Add local stream if available
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        pc.addTrack(track, _localStream!);
      });
    }

    // ICE Candidate handling
    pc.onIceCandidate = (candidate) {
      _signalingService?.sendIceCandidate(targetUserId, candidate);
    };

    // Track handling (Unified Plan)
    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        onRemoteStream?.call(event.streams.first, targetUserId);
      }
    };

    // Legacy support (Plan B - though verify if needed for this web/mobile project, usually onTrack is best)
    pc.onAddStream = (stream) {
      onRemoteStream?.call(stream, targetUserId);
    };

    // Peer Connection State (optional logging)
    pc.onConnectionState = (state) {
      print("[WebRTC] Connection state with $targetUserId: $state");
    };

    _peerConnections[targetUserId] = pc;
    return pc;
  }

  Future<void> _handleRemoteOffer(
    RTCSessionDescription description,
    String fromUserId,
  ) async {
    var pc = _peerConnections[fromUserId];

    // Correct Glare handling or existing connection reuse could significantly complicate this.
    // For now, if we have a PC, we might need to check its state.
    // Simplest robust strategy: if offer comes, treat as renegotiation or new call.
    if (pc == null) {
      pc = await createPeerConnection(fromUserId);
    }

    await pc.setRemoteDescription(description);
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    await sendAnswer(fromUserId, answer);
  }

  Future<void> _handleRemoteAnswer(
    RTCSessionDescription description,
    String fromUserId,
  ) async {
    var pc = _peerConnections[fromUserId];
    if (pc != null) {
      await pc.setRemoteDescription(description);
    }
  }

  Future<void> _handleRemoteIceCandidate(
    RTCIceCandidate candidate,
    String fromUserId,
  ) async {
    var pc = _peerConnections[fromUserId];
    if (pc != null) {
      await pc.addCandidate(candidate);
    }
  }

  Future<void> _handleRemoteBye(String fromUserId) async {
    var pc = _peerConnections[fromUserId];
    if (pc != null) {
      await pc.close();
      _peerConnections.remove(fromUserId);
    }
    onRemoteStreamRemoved?.call(fromUserId);
    await _signalingService?.clearIncomingFromUser(fromUserId);
  }

  @override
  Future<void> sendOffer(
    String targetUserId,
    RTCSessionDescription offer,
  ) async {
    await _signalingService?.sendOffer(targetUserId, offer);
  }

  @override
  Future<void> sendAnswer(
    String targetUserId,
    RTCSessionDescription answer,
  ) async {
    await _signalingService?.sendAnswer(targetUserId, answer);
  }

  @override
  Future<void> sendIceCandidate(
    String targetUserId,
    RTCIceCandidate candidate,
  ) async {
    await _signalingService?.sendIceCandidate(targetUserId, candidate);
  }

  @override
  Future<void> dispose() async {
    await leaveRoom();
  }
}
