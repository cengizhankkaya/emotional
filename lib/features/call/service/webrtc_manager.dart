import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCManager {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? get localStream => _localStream;

  // Callbacks
  Function(MediaStream stream)? onLocalStream;
  Function(MediaStream stream)? onRemoteStream;
  Function(RTCIceCandidate candidate)? onIceCandidate;

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

  Future<void> initialize() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user'},
    });

    if (_localStream != null) {
      onLocalStream?.call(_localStream!);
    }
  }

  Future<RTCPeerConnection> createPeerConnectionForUser(String userId) async {
    final pc = await createPeerConnection(_configuration);

    // Add local stream tracks to peer connection
    _localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    pc.onIceCandidate = (candidate) {
      onIceCandidate?.call(candidate);
    };

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        onRemoteStream?.call(event.streams.first);
      }
    };

    return pc;
  }

  void switchCamera() {
    if (_localStream != null) {
      // Helper to switch camera
      // Helper.switchCamera(_localStream!.getVideoTracks()[0]);
      // Actually flutter_webrtc has a helper on the track usually, or we use Helper.
      final videoTrack = _localStream!.getVideoTracks().first;
      Helper.switchCamera(videoTrack);
    }
  }

  void toggleMute(bool muted) {
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !muted;
    });
  }

  void toggleVideo(bool enabled) {
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = enabled;
    });
  }

  Future<void> dispose() async {
    await _localStream?.dispose();
    _localStream = null;
    await _peerConnection?.close();
    _peerConnection = null;
  }
}
