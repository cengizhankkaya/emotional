import 'package:emotional/features/call/domain/screen_share/outgoing_video_stats.dart';
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

  Future<void> removeLocalVideoTrack();

  /// Caps outgoing video for all current and future peer connections.
  /// Passing no limits restores the default encoder behaviour.
  Future<void> setVideoSenderLimits({int? maxBitrate, int? maxFramerate});

  /// Target bitrate for outgoing audio on all current and future peer
  /// connections, e.g. for music in a shared tab; null restores the
  /// speech default.
  Future<void> setAudioSenderBitrate(int? maxBitrate);

  /// What the video senders currently transmit, for the weakest peer; null
  /// when there is no connection to measure.
  Future<OutgoingVideoStats?> getOutgoingVideoStats();

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
