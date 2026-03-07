import 'package:flutter_webrtc/flutter_webrtc.dart';

abstract class ICallService {
  /// Initialize the service (signaling connections, etc.)
  Future<void> initialize();

  /// Join a room
  /// Join a room
  Future<void> joinRoom(String roomId, String userId, {bool isHost = false});

  /// Leave the current room
  Future<void> leaveRoom();

  /// Create a peer connection for a target user
  Future<RTCPeerConnection> createPeerConnection(String targetUserId);

  /// Initiate a call to a target user
  Future<void> connect(String targetUserId);

  /// Send an offer to a user
  Future<void> sendOffer(String targetUserId, RTCSessionDescription offer);

  /// Send an answer to a user
  Future<void> sendAnswer(String targetUserId, RTCSessionDescription answer);

  /// Send an ICE candidate to a user
  Future<void> sendIceCandidate(String targetUserId, RTCIceCandidate candidate);

  /// Update the local stream being transmitted
  void updateLocalStream(MediaStream? stream);

  /// Replace video track for all active peer connections
  Future<void> replaceLocalAllVideoTrack(MediaStreamTrack newTrack);

  /// Replace audio track for all active peer connections
  Future<void> replaceLocalAllAudioTrack(MediaStreamTrack newTrack);

  /// Get the current audio level for a remote user (0.0 to 1.0)
  Future<double> getRemoteAudioLevel(String userId);

  /// Get the current local audio level (0.0 to 1.0)
  Future<double> getLocalAudioLevel();

  /// Callback for when a remote stream is received
  set onRemoteStream(Function(MediaStream stream, String userId)? callback);

  /// Callback for when a remote stream is removed
  set onRemoteStreamRemoved(Function(String userId)? callback);

  /// Forget a user (close connection and clear signaling data)
  Future<void> forgetUser(String userId);

  /// Clean up resources
  Future<void> dispose();
}
