import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCManager {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? get localStream => _localStream;

  // Dispose & session guards
  bool _isDisposed = false;
  int _sessionToken = 0;

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
    _isDisposed = false;
    _sessionToken++;

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user'},
    });

    // Guard: dispose may have been called while getUserMedia was awaited
    if (_isDisposed) {
      await _localStream?.dispose();
      _localStream = null;
      return;
    }

    if (_localStream != null) {
      onLocalStream?.call(_localStream!);
    }
  }

  Future<RTCPeerConnection?> createPeerConnectionForUser(String userId) async {
    if (_isDisposed) return null;
    final token = _sessionToken;

    final pc = await createPeerConnection(_configuration);

    // Guard: dispose or new session while createPeerConnection was awaited
    if (_isDisposed || _sessionToken != token) {
      await pc.close();
      await pc.dispose();
      return null;
    }

    // Add local stream tracks to peer connection
    _localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    pc.onIceCandidate = (candidate) {
      if (_isDisposed || _sessionToken != token) return;
      onIceCandidate?.call(candidate);
    };

    pc.onTrack = (event) {
      if (_isDisposed || _sessionToken != token) return;
      if (event.streams.isNotEmpty) {
        onRemoteStream?.call(event.streams.first);
      }
    };

    // Store reference so it can be cleaned up
    _peerConnection = pc;
    return pc;
  }

  void switchCamera() {
    if (_isDisposed || _localStream == null) return;
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isEmpty) return;
    Helper.switchCamera(videoTracks.first);
  }

  void enableSpeakerphone(bool enable) {
    if (_isDisposed) return;
    Helper.setSpeakerphoneOn(enable);
  }

  void toggleMute(bool muted) {
    if (_isDisposed) return;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !muted;
    });
  }

  void toggleVideo(bool enabled) {
    if (_isDisposed) return;
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = enabled;
    });
  }

  Future<void> dispose() async {
    _isDisposed = true;

    // Null out callbacks immediately so no late-arriving events fire them
    onLocalStream = null;
    onRemoteStream = null;
    onIceCandidate = null;

    await _localStream?.dispose();
    _localStream = null;

    await _peerConnection?.close();
    await _peerConnection?.dispose();
    _peerConnection = null;
  }
}
