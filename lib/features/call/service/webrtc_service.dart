import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:emotional/features/call/domain/enums/peer_status.dart';
import 'package:emotional/features/call/domain/services/i_call_service.dart';
import 'package:emotional/features/call/service/signaling_service.dart';
import 'package:emotional/product/model/enum/firebase_remote_enums.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:emotional/features/call/domain/screen_share/outgoing_video_stats.dart';
import 'package:emotional/features/call/service/outgoing_video_stats_sampler.dart';
import 'package:emotional/features/call/service/opus_sdp.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService implements ICallService {
  WebRTCService({
    @visibleForTesting
    SignalingService Function(String roomId, String userId)? signalingFactory,
  }) : _signalingFactory =
           signalingFactory ??
           ((roomId, userId) =>
               SignalingService(roomId: roomId, userId: userId));

  final SignalingService Function(String roomId, String userId)
  _signalingFactory;
  SignalingService? _signalingService;
  final Map<String, RTCPeerConnection> _peerConnections = {};

  double _localAudioLevel = 0.0;
  Timer? _localAudioTimer;

  /// Prevents duplicate concurrent connect() calls for the same peer.
  final Set<String> _connectingPeers = {};

  bool _isDisposed = false;
  bool _isHost = false;

  /// Incremented on every joinRoom() — invalidates callbacks from previous sessions.
  int _sessionToken = 0;

  /// SDP calls on a connection that gets closed meanwhile never complete
  /// (per the WebRTC spec), which would leave connect() hanging forever.
  static const Duration _sdpTimeout = Duration(seconds: 10);

  static const List<Map<String, dynamic>> _defaultIceServers = [
    {
      'urls': [
        'stun:stun1.l.google.com:19302',
        'stun:stun2.l.google.com:19302',
      ],
    },
  ];

  /// STUN alone fails behind symmetric NATs (corporate, campus and some
  /// mobile networks); TURN relays come from Remote Config so their
  /// credentials can be rotated without a release.
  Map<String, dynamic> get _configuration => {
    'iceServers': _remoteIceServers() ?? _defaultIceServers,
  };

  static List<Map<String, dynamic>>? _remoteIceServers() {
    try {
      final raw = FirebaseRemoteEnums.webrtcIceServers.valueString.trim();
      if (raw.isEmpty) return null;
      final servers = (jsonDecode(raw) as List)
          .map((server) => Map<String, dynamic>.from(server as Map))
          .toList();
      return servers.isEmpty ? null : servers;
    } catch (e) {
      debugPrint('[WebRTC] Using default ICE servers ($e)');
      return null;
    }
  }

  // Audio level fallback (energy calculation)
  final Map<String, double> _lastTotalAudioEnergy = {};
  final Map<String, double> _lastTotalSamplesDuration = {};

  // FIX: onTrack fires once per track (audio + video = 2 events) for the same
  // stream. Without dedup, onRemoteStream fires twice for the same stream,
  // causing the renderer in CallBloc to be created and disposed twice.
  // We store the last stream ID seen per user and skip duplicate events.
  final Map<String, String> _lastRemoteStreamId = {};

  // FIX: Bye-pending guard.
  // When a bye arrives we don't immediately know if the user is truly leaving
  // or just reconnecting. We mark them pending-bye for up to 2 seconds.
  // During this window, the delayed connect() in CallBloc._setupRoomListeners
  // must not fire — otherwise we create a new PC for a user who is leaving.
  // The flag is cleared by forgetUser() (room-update confirms leave) or after
  // the 2s timeout, whichever comes first.
  final Set<String> _pendingByeUsers = {};

  /// Last connection state per peer and since when, so CallBloc can tell
  /// a healthy connection from one that is stuck or gone.
  final Map<String, RTCPeerConnectionState> _peerStates = {};
  final Map<String, DateTime> _peerStateSince = {};

  /// A peer left the call (sent bye) but may still be in the room.
  void Function(String userId)? onRemoteBye;

  @override
  Function(MediaStream stream, String userId)? onRemoteStream;

  @override
  Function(String userId)? onRemoteStreamRemoved;

  MediaStream? _localStream;

  @override
  void updateLocalStream(webrtc.MediaStream? stream) {
    _localStream = stream;
    debugPrint("[WebRTC] localStream updated. New StreamID: ${stream?.id}");
  }

  // ─── Track replacement ────────────────────────────────────────────────────

  @override
  Future<void> replaceLocalAllVideoTrack(
    webrtc.MediaStreamTrack newTrack,
  ) async {
    if (_isDisposed) return;
    final token = _sessionToken;
    final entries = _peerConnections.entries.toList();

    for (var entry in entries) {
      final userId = entry.key;
      final pc = entry.value;
      if (_peerConnections[userId] != pc) continue;

      try {
        final transceivers = await pc.getTransceivers();
        if (_isDisposed || _sessionToken != token) return;
        if (_peerConnections[userId] != pc) continue;

        bool replaced = false;
        for (var t in transceivers) {
          if (_isShareCameraSender(t.sender)) continue;
          if (t.sender.track?.kind == 'video' ||
              t.receiver.track?.kind == 'video') {
            debugPrint(
              "[WebRTC] Replacing video track for $userId. NewTrackID: ${newTrack.id}",
            );
            await t.sender.replaceTrack(newTrack);
            if (_isDisposed || _sessionToken != token) return;
            replaced = true;
          }
        }

        if (!replaced) {
          debugPrint(
            "[WebRTC] No video sender for $userId, adding a new transceiver.",
          );

          await pc.addTransceiver(
            track: newTrack,
            kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
            init: RTCRtpTransceiverInit(
              direction: TransceiverDirection.SendRecv,
              streams: [_localStream!],
            ),
          );

          // Trigger renegotiation
          if (_isDisposed || _sessionToken != token) return;
          if (_peerConnections[userId] != pc) continue;
          await connect(userId);
        }
        if (_isDisposed || _sessionToken != token) return;
        if (_peerConnections[userId] != pc) continue;
        // An idle transceiver may have had no encodings when the profile
        // was selected. Apply it again once the video track is attached.
        if (_videoSenderLimits != null) await _applyVideoSenderLimits(pc);
      } catch (e) {
        debugPrint("[WebRTC] Error replacing video track for $userId: $e");
      }
    }
  }

  /// Camera off: stop sending video but keep the transceiver, so turning the
  /// camera back on needs no renegotiation.
  @override
  Future<void> removeLocalVideoTrack() async {
    if (_isDisposed) return;
    final token = _sessionToken;
    for (final entry in _peerConnections.entries.toList()) {
      final pc = entry.value;
      try {
        final transceivers = await pc.getTransceivers();
        if (_isDisposed || _sessionToken != token) return;
        for (final t in transceivers) {
          if (_isShareCameraSender(t.sender)) continue;
          if (t.sender.track?.kind == 'video' ||
              t.receiver.track?.kind == 'video') {
            await t.sender.replaceTrack(null);
          }
        }
      } catch (e) {
        debugPrint("[WebRTC] Error removing video track for ${entry.key}: $e");
      }
    }
  }

  @override
  Future<void> replaceLocalAllAudioTrack(MediaStreamTrack newTrack) async {
    if (_isDisposed) return;
    final token = _sessionToken;
    final entries = _peerConnections.entries.toList();

    for (var entry in entries) {
      final userId = entry.key;
      final pc = entry.value;
      if (_peerConnections[userId] != pc) continue;

      final transceivers = await pc.getTransceivers();
      if (_isDisposed || _sessionToken != token) return;
      if (_peerConnections[userId] != pc) continue;

      bool replaced = false;
      for (var t in transceivers) {
        if (t.sender.track?.kind == 'audio' ||
            t.receiver.track?.kind == 'audio') {
          await t.sender.replaceTrack(newTrack);
          if (_isDisposed || _sessionToken != token) return;
          replaced = true;
        }
      }

      if (!replaced) {
        debugPrint(
          "[WebRTC] No audio sender for $userId, adding a new transceiver.",
        );

        await pc.addTransceiver(
          track: newTrack,
          kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
          init: RTCRtpTransceiverInit(
            direction: TransceiverDirection.SendRecv,
            streams: [_localStream!],
          ),
        );

        // Trigger renegotiation
        if (_isDisposed || _sessionToken != token) return;
        if (_peerConnections[userId] != pc) continue;
        await connect(userId);
      }
    }
  }

  // ─── Sender tuning ────────────────────────────────────────────────────────

  /// See [withStereoOpus]: lets peers send us a shared tab's sound in
  /// stereo.
  RTCSessionDescription _withStereoOpus(RTCSessionDescription description) {
    final sdp = description.sdp;
    if (sdp == null) return description;
    return RTCSessionDescription(withStereoOpus(sdp), description.type);
  }

  /// Outgoing audio target; null keeps the encoder default (about 32 kbps,
  /// tuned for speech). Kept so peers that join mid-share get it too.
  int? _audioMaxBitrate;

  @override
  Future<void> setAudioSenderBitrate(int? maxBitrate) async {
    if (_isDisposed) return;
    _audioMaxBitrate = maxBitrate;
    for (final pc in _peerConnections.values.toList()) {
      await _applyAudioSenderBitrate(pc);
    }
  }

  Future<void> _applyAudioSenderBitrate(RTCPeerConnection pc) async {
    try {
      for (final transceiver in await pc.getTransceivers()) {
        final sender = transceiver.sender;
        final isAudio =
            sender.track?.kind == 'audio' ||
            transceiver.receiver.track?.kind == 'audio';
        if (!isAudio) continue;
        final parameters = sender.parameters;
        final encodings = parameters.encodings;
        if (encodings == null || encodings.isEmpty) continue;
        for (final encoding in encodings) {
          encoding.maxBitrate = _audioMaxBitrate;
        }
        await sender.setParameters(parameters);
      }
    } catch (e) {
      debugPrint("[WebRTC] Failed to apply audio sender bitrate: $e");
    }
  }

  /// Outgoing video caps; null keeps the encoder defaults. Kept so peers that
  /// join mid-share get the same limits.
  ({int? maxBitrate, int? maxFramerate})? _videoSenderLimits;

  @override
  Future<void> setVideoSenderLimits({
    int? maxBitrate,
    int? maxFramerate,
  }) async {
    if (_isDisposed) return;
    _videoSenderLimits = maxBitrate == null && maxFramerate == null
        ? null
        : (maxBitrate: maxBitrate, maxFramerate: maxFramerate);
    for (final pc in _peerConnections.values.toList()) {
      await _applyVideoSenderLimits(pc);
    }
  }

  /// The camera next to a share is a thumbnail: it gets a small budget and
  /// a low priority, so the screen keeps the bandwidth.
  static const ({int? maxBitrate, int? maxFramerate}) _shareCameraLimits = (
    maxBitrate: 700000,
    maxFramerate: null,
  );

  bool _isShareCameraSender(RTCRtpSender sender) => _shareCameraTransceivers
      .values
      .any((transceiver) => transceiver.sender.senderId == sender.senderId);

  Future<void> _applyVideoSenderLimits(RTCPeerConnection pc) async {
    final limits = _videoSenderLimits;
    try {
      // Find the video sender by its transceiver, not its track: dart_webrtc
      // doesn't wait for replaceTrack, so right after a track switch (as at
      // the start of a screen share) the sender may not show it yet and the
      // limits were skipped.
      for (final transceiver in await pc.getTransceivers()) {
        final sender = transceiver.sender;
        final isVideo =
            sender.track?.kind == 'video' ||
            transceiver.receiver.track?.kind == 'video';
        if (!isVideo) continue;
        // The camera next to a share keeps its own budget.
        if (_isShareCameraSender(sender)) {
          continue;
        }
        await _setVideoSenderLimits(
          sender,
          // Each connection adapts to its own available bandwidth. Dividing
          // this ceiling by the room size lowered quality even on fast links.
          limits,
          // While sharing, the screen comes first when bandwidth is short.
          priority: limits == null ? RTCPriorityType.low : RTCPriorityType.high,
        );
      }
    } catch (e) {
      debugPrint("[WebRTC] Failed to apply video sender limits: $e");
    }
  }

  Future<void> _setVideoSenderLimits(
    RTCRtpSender sender,
    ({int? maxBitrate, int? maxFramerate})? limits, {
    RTCPriorityType priority = RTCPriorityType.low,
  }) async {
    final parameters = sender.parameters;
    final encodings = parameters.encodings;
    if (encodings == null || encodings.isEmpty) return;
    for (final encoding in encodings) {
      encoding.maxBitrate = limits?.maxBitrate;
      encoding.maxFramerate = limits?.maxFramerate;
      encoding.priority = priority;
    }
    await sender.setParameters(parameters);
  }

  final OutgoingVideoStatsSampler _outgoingVideoStats =
      OutgoingVideoStatsSampler();

  @override
  Future<OutgoingVideoStats?> getOutgoingVideoStats() async {
    if (_isDisposed) return null;
    return _outgoingVideoStats.sample(
      _peerConnections,
      excludedTrackIds: {if (_shareCameraTrack?.id case final String id) id},
    );
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  Future<void> initialize() async {
    // Nothing to init globally; room-specific init happens in joinRoom.
  }

  @override
  Future<void> joinRoom(
    String roomId,
    String userId, {
    bool isHost = false,
  }) async {
    // FIX: Reset _isHost explicitly before setting the new value.
    // If a previous session left _isHost=true and the new session is a guest,
    // the glare-resolution logic (impolite=host) would be wrong, causing the
    // host-side to ignore the guest's offer instead of the other way around.
    _isHost = isHost;
    _isDisposed = false;
    _sessionToken++;
    _lastRemoteStreamId.clear();
    _pendingByeUsers.clear();
    _connectingPeers.clear();
    _signalingService = _signalingFactory(roomId, userId);
    // Before initialize(): it starts listening, and offers already waiting
    // in the inbox fire right away.
    _setupSignalingListeners();
    await _signalingService!.initialize();
    _startLocalAudioMonitor();
  }

  void _setupSignalingListeners() {
    if (_signalingService == null) return;

    _signalingService!.onRemoteOffer = (description, fromUserId) async {
      if (_isDisposed) return;
      await _guard(
        'offer from $fromUserId',
        () => _handleRemoteOffer(description, fromUserId),
      );
    };

    _signalingService!.onRemoteAnswer = (description, fromUserId) async {
      if (_isDisposed) return;
      await _guard(
        'answer from $fromUserId',
        () => _handleRemoteAnswer(description, fromUserId),
      );
    };

    _signalingService!.onRemoteIceCandidate = (candidate, fromUserId) async {
      if (_isDisposed) return;
      await _guard(
        'ICE candidate from $fromUserId',
        () => _handleRemoteIceCandidate(candidate, fromUserId),
      );
    };

    _signalingService!.onRemoteBye = (fromUserId) async {
      if (_isDisposed) return;
      await _guard('bye from $fromUserId', () => _handleRemoteBye(fromUserId));
    };
  }

  /// Signaling arrives from database listeners; a failure here (e.g. the
  /// connection was replaced meanwhile) must not become an unhandled error.
  /// The reconcile loop in CallBloc retries what didn't work out.
  Future<void> _guard(String what, Future<void> Function() handle) async {
    try {
      await handle();
    } catch (e) {
      debugPrint("[WebRTC] Handling $what failed: $e");
    }
  }

  @override
  Future<void> leaveRoom() async {
    if (_signalingService != null) {
      final userIds = _peerConnections.keys.toList();
      for (final userId in userIds) {
        await _signalingService!.sendBye(userId);
        // FIX: Clear outgoing signals to each peer (offers/answers/candidates
        // this user sent to them). Without this, stale signals from the old
        // session remain at rooms/<roomId>/signal/<peerId>/offers/<thisUserId>
        // and fire immediately as onChildAdded events when this user rejoins,
        // causing the peer to create a PC with wrong/stale session state.
        // This is the root cause of the host-rejoin failure.
        await _signalingService!.clearOutgoingToUser(userId);
      }
      await _signalingService!.clearSignal();
      _signalingService!.dispose();
      _signalingService = null;
    }

    final pcs = _peerConnections.values.toList();
    for (final pc in pcs) {
      await pc.close();
      await pc.dispose();
    }
    _localAudioTimer?.cancel();
    _localAudioTimer = null;
    _localAudioLevel = 0.0;
    _peerConnections.clear();
    _shareCameraTransceivers.clear();
    _lastShareCameraStreamId.clear();
    _shareCameraTrack = null;
    _shareCameraPeers = {};
    await _shareCameraStream?.dispose();
    _shareCameraStream = null;
    _peerStates.clear();
    _peerStateSince.clear();
    _remoteCandidateQueues.clear();
    _remoteDescriptionSet.clear();
    _lastRemoteStreamId.clear();
    _pendingByeUsers.clear();
    _connectingPeers.clear();
  }

  // ─── Peer connection ──────────────────────────────────────────────────────

  @override
  Future<RTCPeerConnection> createPeerConnection(String targetUserId) async {
    final token = _sessionToken;
    final pc = await webrtc.createPeerConnection(_configuration);

    if (_isDisposed || _sessionToken != token) {
      await pc.close();
      await pc.dispose();
      throw Exception(
        "WebRTCService disposed or session changed during createPeerConnection",
      );
    }

    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        pc.addTrack(track, _localStream!);
      });
    }

    final senders = await pc.getSenders();
    bool hasAudio = senders.any((s) => s.track?.kind == 'audio');
    bool hasVideo = senders.any((s) => s.track?.kind == 'video');

    // Tie the empty transceivers to our stream too: peers then get every
    // track in one stream from the start, and a camera turned on later just
    // fills the existing video track (no renegotiation). Without a stream,
    // peers drop the track (onTrack with no streams) and never show video.
    final streams = [?_localStream];
    if (!hasAudio) {
      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(
          direction: TransceiverDirection.SendRecv,
          streams: streams,
        ),
      );
    }
    if (!hasVideo) {
      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(
          direction: TransceiverDirection.SendRecv,
          streams: streams,
        ),
      );
    }

    if (_videoSenderLimits != null) await _applyVideoSenderLimits(pc);
    if (_audioMaxBitrate != null) await _applyAudioSenderBitrate(pc);

    pc.onIceCandidate = (candidate) {
      if (_isDisposed || _sessionToken != token) return;
      _signalingService?.sendIceCandidate(targetUserId, candidate);
    };

    // FIX: onTrack fires once per track. A typical call has audio+video,
    // so this fires twice for the same stream. We deduplicate by stream ID
    // so CallBloc only receives one InternalIncomingStream per peer.
    pc.onTrack = (event) {
      if (_isDisposed || _sessionToken != token) return;
      if (event.streams.isEmpty) {
        debugPrint("[WebRTC] onTrack from $targetUserId — streams are EMPTY.");
        return;
      }
      final stream = event.streams.first;
      // A second, video-only stream next to the main one (which always has
      // the microphone) is the sharer's camera.
      final main = _lastRemoteStreamId[targetUserId];
      if (event.track.kind == 'video' &&
          main != null &&
          stream.id != main &&
          stream.getAudioTracks().isEmpty) {
        if (_lastShareCameraStreamId[targetUserId] == stream.id) return;
        _lastShareCameraStreamId[targetUserId] = stream.id;
        debugPrint("[WebRTC] Share camera from $targetUserId.");
        onRemoteShareCamera?.call(stream, targetUserId);
        return;
      }
      // Skip if we already reported this stream (e.g. second track event)
      if (_lastRemoteStreamId[targetUserId] == stream.id) return;
      _lastRemoteStreamId[targetUserId] = stream.id;
      debugPrint("[WebRTC] onTrack from $targetUserId. StreamID: ${stream.id}");
      onRemoteStream?.call(stream, targetUserId);
    };

    // NOTE: onAddStream is intentionally NOT set.
    // onAddStream and onTrack both fire for the same remote stream on Android,
    // causing a double InternalIncomingStream. onTrack is the modern standard;
    // onAddStream is legacy and redundant here.

    pc.onConnectionState = (state) async {
      debugPrint("[WebRTC] Connection state with $targetUserId: $state");
      if (_isDisposed) return;
      if (_peerConnections[targetUserId] == pc) {
        _peerStates[targetUserId] = state;
        _peerStateSince[targetUserId] = DateTime.now();
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          // A camera shared before this connection existed goes out now.
          unawaited(_syncShareCamera(targetUserId));
        }
      }
      final cbToken = _sessionToken;

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        debugPrint(
          "[WebRTC] Connection failed with $targetUserId. Reconnecting...",
        );
        if (_peerConnections[targetUserId] != pc) return;
        if (!_isDisposed && _sessionToken == cbToken) {
          await connect(targetUserId);
        }
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        debugPrint(
          "[WebRTC] Disconnected from $targetUserId. ICE Restart in 3s...",
        );
        if (_peerConnections[targetUserId] != pc) return;

        await Future.delayed(const Duration(seconds: 3));
        if (_isDisposed || _sessionToken != cbToken) return;
        if (_peerConnections[targetUserId] != pc) return;

        final currentState = await pc.getConnectionState();
        if (_isDisposed || _sessionToken != cbToken) return;
        if (_peerConnections[targetUserId] != pc) return;

        if (currentState ==
            RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          debugPrint(
            "[WebRTC] Still disconnected from $targetUserId. ICE Restart.",
          );
          await _triggerIceRestart(targetUserId);
        }
      }
    };

    _peerConnections[targetUserId] = pc;
    _peerStates.remove(targetUserId);
    _peerStateSince[targetUserId] = DateTime.now();
    return pc;
  }

  @visibleForTesting
  RTCPeerConnection? peerConnectionFor(String userId) =>
      _peerConnections[userId];

  /// Where the connection to [userId] stands, and since when.
  ({PeerStatus status, Duration since}) peerStatus(String userId) {
    final since = _peerStateSince[userId];
    final age = since == null
        ? Duration.zero
        : DateTime.now().difference(since);
    if (!_peerConnections.containsKey(userId)) {
      return (status: PeerStatus.none, since: age);
    }
    return switch (_peerStates[userId]) {
      RTCPeerConnectionState.RTCPeerConnectionStateConnected => (
        status: PeerStatus.connected,
        since: age,
      ),
      RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
      RTCPeerConnectionState.RTCPeerConnectionStateClosed => (
        status: PeerStatus.none,
        since: age,
      ),
      _ => (status: PeerStatus.negotiating, since: age),
    };
  }

  /// Closes our connection to [userId] and forgets its per-connection state.
  Future<void> _closePeer(String userId, RTCPeerConnection pc) async {
    if (_peerConnections[userId] == pc) {
      _peerConnections.remove(userId);
      _peerStates.remove(userId);
      _peerStateSince.remove(userId);
    }
    _connectingPeers.remove(userId);
    _remoteDescriptionSet.remove(userId);
    _remoteCandidateQueues.remove(userId);
    // A new connection may carry the same remote stream; let onTrack report
    // it again so the renderer doesn't keep the dead one.
    _lastRemoteStreamId.remove(userId);
    _lastShareCameraStreamId.remove(userId);
    _shareCameraTransceivers.remove(userId);
    await pc.close();
    await pc.dispose();
  }

  // ─── Camera next to a screen share ────────────────────────────────────────

  /// While sharing with the camera on, the camera goes out as a second
  /// video in its own stream, only to [_shareCameraPeers]: older app
  /// versions show one video per person and would replace the screen.
  MediaStreamTrack? _shareCameraTrack;
  MediaStream? _shareCameraStream;
  Set<String> _shareCameraPeers = {};
  final Map<String, RTCRtpTransceiver> _shareCameraTransceivers = {};
  final Map<String, String> _lastShareCameraStreamId = {};

  /// A sharer's camera arrived (see [setShareCamera]).
  void Function(MediaStream stream, String userId)? onRemoteShareCamera;

  /// Sends [track] next to the screen share; null stops sending it (the
  /// transceiver stays, so turning it back on needs no renegotiation).
  Future<void> setShareCamera(MediaStreamTrack? track) async {
    if (_isDisposed) return;
    _shareCameraTrack = track;
    if (track != null) {
      final stream = _shareCameraStream ??= await createLocalMediaStream(
        'share-camera',
      );
      for (final old in stream.getVideoTracks().toList()) {
        if (old.id != track.id) await stream.removeTrack(old);
      }
      if (!stream.getVideoTracks().any((t) => t.id == track.id)) {
        await stream.addTrack(track);
      }
    }
    for (final peer in _peerConnections.keys.toList()) {
      await _syncShareCamera(peer);
    }
  }

  /// Who can show a sharer's camera; from the room's usersState.
  Future<void> setShareCameraPeers(Set<String> peers) async {
    if (setEquals(peers, _shareCameraPeers)) return;
    _shareCameraPeers = {...peers};
    for (final peer in _peerConnections.keys.toList()) {
      await _syncShareCamera(peer);
    }
  }

  Future<void> _syncShareCamera(String peer) async {
    final pc = _peerConnections[peer];
    if (pc == null || _isDisposed) return;
    final track = _shareCameraPeers.contains(peer) ? _shareCameraTrack : null;
    try {
      final existing = _shareCameraTransceivers[peer];
      if (existing != null) {
        await existing.sender.replaceTrack(track);
        // An idle share-camera sender also got the share's caps; give it
        // the camera's own.
        if (track != null) {
          await _setVideoSenderLimits(existing.sender, _shareCameraLimits);
        }
        return;
      }
      final stream = _shareCameraStream;
      if (track == null || stream == null) return;
      // An answer can't add a video the offer lacks, so add it to a
      // connection that is up and offer again.
      if (peerStatus(peer).status != PeerStatus.connected) return;
      final transceiver = await pc.addTransceiver(
        track: track,
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(
          direction: TransceiverDirection.SendOnly,
          streams: [stream],
        ),
      );
      _shareCameraTransceivers[peer] = transceiver;
      await _setVideoSenderLimits(transceiver.sender, _shareCameraLimits);
      await _renegotiate(peer);
    } catch (e) {
      debugPrint("[WebRTC] Share camera for $peer failed: $e");
    }
  }

  /// Offers again on the existing connection, e.g. after adding a video.
  Future<void> _renegotiate(String userId) async {
    final pc = _peerConnections[userId];
    if (pc == null) return;
    final token = _sessionToken;
    bool isStale() =>
        _isDisposed || _sessionToken != token || _peerConnections[userId] != pc;

    // Let an offer/answer already in flight finish first.
    for (
      var i = 0;
      i < 20 &&
          await pc.getSignalingState() !=
              RTCSignalingState.RTCSignalingStateStable;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (isStale()) return;
    }
    final offer = _withStereoOpus(
      await pc.createOffer({}).timeout(_sdpTimeout),
    );
    if (isStale()) return;
    await pc.setLocalDescription(offer).timeout(_sdpTimeout);
    if (isStale()) return;
    await sendOffer(userId, offer);
    debugPrint("[WebRTC] Renegotiation offer sent to $userId.");
  }

  @override
  Future<void> connect(String targetUserId) async {
    if (_isDisposed) return;
    final token = _sessionToken;

    if (_connectingPeers.contains(targetUserId)) {
      debugPrint("[WebRTC] connect() for $targetUserId already in progress.");
      return;
    }
    _connectingPeers.add(targetUserId);

    try {
      if (_peerConnections.containsKey(targetUserId)) {
        final pc = _peerConnections[targetUserId];
        final state = await pc?.getConnectionState();
        if (_isDisposed || _sessionToken != token) return;
        if (_peerConnections[targetUserId] != pc) return;

        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          debugPrint("[WebRTC] Already connected to $targetUserId.");
          return;
        }
        debugPrint(
          "[WebRTC] Connection to $targetUserId is $state. Restarting...",
        );
        if (pc != null) await _closePeer(targetUserId, pc);
        _connectingPeers.add(targetUserId);
      }

      if (_isDisposed || _sessionToken != token) return;

      debugPrint("[WebRTC] Creating peer connection for $targetUserId.");
      final pc = await createPeerConnection(targetUserId);

      await _signalingService?.clearOutgoingToUser(targetUserId);

      if (_isDisposed ||
          _sessionToken != token ||
          _peerConnections[targetUserId] != pc) {
        if (_peerConnections[targetUserId] == pc) {
          _peerConnections.remove(targetUserId);
        }
        await pc.close();
        await pc.dispose();
        return;
      }

      try {
        final offer = _withStereoOpus(
          await pc
              .createOffer({
                'offerToReceiveAudio': true,
                'offerToReceiveVideo': true,
              })
              .timeout(_sdpTimeout),
        );
        if (_isDisposed ||
            _sessionToken != token ||
            _peerConnections[targetUserId] != pc) {
          return;
        }
        await pc.setLocalDescription(offer).timeout(_sdpTimeout);
        if (_isDisposed ||
            _sessionToken != token ||
            _peerConnections[targetUserId] != pc) {
          return;
        }
        await sendOffer(targetUserId, offer);
      } catch (e) {
        debugPrint(
          "[WebRTC] connect() createOffer failed for $targetUserId: $e",
        );
      }
    } finally {
      _connectingPeers.remove(targetUserId);
    }
  }

  @visibleForTesting
  Future<void> restartIce(String targetUserId) =>
      _triggerIceRestart(targetUserId);

  Future<void> _triggerIceRestart(String targetUserId) async {
    if (_isDisposed) return;
    final token = _sessionToken;
    final pc = _peerConnections[targetUserId];
    if (pc == null) return;

    try {
      final offer = _withStereoOpus(
        await pc
            .createOffer({
              'offerToReceiveAudio': true,
              'offerToReceiveVideo': true,
              'iceRestart': true,
            })
            .timeout(_sdpTimeout),
      );
      if (_isDisposed ||
          _sessionToken != token ||
          _peerConnections[targetUserId] != pc) {
        return;
      }
      await pc.setLocalDescription(offer).timeout(_sdpTimeout);
      if (_isDisposed ||
          _sessionToken != token ||
          _peerConnections[targetUserId] != pc) {
        return;
      }
      await sendOffer(targetUserId, offer);
      debugPrint("[WebRTC] ICE Restart offer sent to $targetUserId.");
    } catch (e) {
      debugPrint("[WebRTC] ICE Restart failed for $targetUserId: $e");
      if (!_isDisposed &&
          _sessionToken == token &&
          _peerConnections[targetUserId] == pc) {
        await connect(targetUserId);
      }
    }
  }

  // ─── Signaling handlers ───────────────────────────────────────────────────

  final Map<String, List<RTCIceCandidate>> _remoteCandidateQueues = {};
  final Set<String> _remoteDescriptionSet = {};

  Future<void> _handleRemoteOffer(
    RTCSessionDescription description,
    String fromUserId,
  ) async {
    if (_isDisposed) return;
    final token = _sessionToken;
    debugPrint("[WebRTC] Received offer from $fromUserId.");
    final existing = _peerConnections[fromUserId];

    if (existing != null) {
      final signalingState = await existing.getSignalingState();
      if (_isDisposed ||
          _sessionToken != token ||
          _peerConnections[fromUserId] != existing) {
        return;
      }

      if (signalingState == RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        // Glare: both sides offered at once. The host keeps its offer and
        // the guest answers, matching older app versions.
        if (_isHost) {
          debugPrint(
            "[WebRTC] GLARE: HOST (impolite). Ignoring offer from $fromUserId.",
          );
          return;
        }
        debugPrint(
          "[WebRTC] GLARE: GUEST (polite). Dropping own offer to $fromUserId.",
        );
        await _closePeer(fromUserId, existing);
      } else if (await _isSameRemotePeer(existing, description)) {
        // Renegotiation or ICE restart on the connection we already share.
        debugPrint("[WebRTC] Renegotiating with $fromUserId.");
        await _answerOffer(existing, description, fromUserId, token);
        return;
      } else {
        // The peer came back with a new connection (rejoin, reload); ours
        // talks to one that no longer exists.
        debugPrint(
          "[WebRTC] $fromUserId started a new connection. Replacing ours.",
        );
        await _closePeer(fromUserId, existing);
      }
      if (_isDisposed || _sessionToken != token) return;
    }

    final pc = await createPeerConnection(fromUserId);
    if (_isDisposed ||
        _sessionToken != token ||
        _peerConnections[fromUserId] != pc) {
      if (_peerConnections[fromUserId] == pc) {
        _peerConnections.remove(fromUserId);
      }
      await pc.close();
      await pc.dispose();
      return;
    }
    await _answerOffer(pc, description, fromUserId, token);
  }

  Future<void> _answerOffer(
    RTCPeerConnection pc,
    RTCSessionDescription description,
    String fromUserId,
    int token,
  ) async {
    bool isStale() =>
        _isDisposed ||
        _sessionToken != token ||
        _peerConnections[fromUserId] != pc;

    await pc.setRemoteDescription(description).timeout(_sdpTimeout);
    if (isStale()) return;
    _remoteDescriptionSet.add(fromUserId);
    debugPrint("[WebRTC] Remote description set for offer from $fromUserId.");

    await _processQueuedCandidates(fromUserId);
    if (isStale()) return;

    await _signalingService?.clearOutgoingToUser(fromUserId);
    if (isStale()) return;

    final answer = _withStereoOpus(
      await pc
          .createAnswer({
            'offerToReceiveAudio': true,
            'offerToReceiveVideo': true,
          })
          .timeout(_sdpTimeout),
    );
    if (isStale()) return;
    await pc.setLocalDescription(answer).timeout(_sdpTimeout);
    if (isStale()) return;

    if (_videoSenderLimits != null) await _applyVideoSenderLimits(pc);
    if (isStale()) return;
    await sendAnswer(fromUserId, answer);
    debugPrint("[WebRTC] Answer sent to $fromUserId.");
  }

  /// Whether [offer] comes from the same remote connection as [pc]'s
  /// current remote description; a new connection has a new DTLS
  /// certificate and so a new fingerprint.
  Future<bool> _isSameRemotePeer(
    RTCPeerConnection pc,
    RTCSessionDescription offer,
  ) async {
    final current = _fingerprint((await pc.getRemoteDescription())?.sdp);
    return current != null && current == _fingerprint(offer.sdp);
  }

  static final RegExp _fingerprintPattern = RegExp(
    r'^a=fingerprint:(.+)$',
    multiLine: true,
  );

  static String? _fingerprint(String? sdp) => sdp == null
      ? null
      : _fingerprintPattern.firstMatch(sdp)?.group(1)?.trim();

  Future<void> _handleRemoteAnswer(
    RTCSessionDescription description,
    String fromUserId,
  ) async {
    if (_isDisposed) return;
    final token = _sessionToken;
    debugPrint("[WebRTC] Received answer from $fromUserId.");
    final pc = _peerConnections[fromUserId];
    if (pc == null) return;

    final signalingState = await pc.getSignalingState();
    if (_isDisposed ||
        _sessionToken != token ||
        _peerConnections[fromUserId] != pc) {
      return;
    }

    if (signalingState != RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
      debugPrint(
        "[WebRTC] Ignoring stale answer from $fromUserId. State: $signalingState.",
      );
      return;
    }

    await pc.setRemoteDescription(description).timeout(_sdpTimeout);
    if (_isDisposed ||
        _sessionToken != token ||
        _peerConnections[fromUserId] != pc) {
      return;
    }
    if (_videoSenderLimits != null) await _applyVideoSenderLimits(pc);
    if (_isDisposed ||
        _sessionToken != token ||
        _peerConnections[fromUserId] != pc) {
      return;
    }
    _remoteDescriptionSet.add(fromUserId);
    debugPrint("[WebRTC] Remote description set for answer from $fromUserId.");

    await _processQueuedCandidates(fromUserId);
  }

  Future<void> _handleRemoteIceCandidate(
    RTCIceCandidate candidate,
    String fromUserId,
  ) async {
    if (_isDisposed) return;

    final pc = _peerConnections[fromUserId];
    if (pc == null) return;

    if (_remoteDescriptionSet.contains(fromUserId)) {
      debugPrint("[WebRTC] Adding ICE candidate from $fromUserId.");
      await pc.addCandidate(candidate);
    } else {
      debugPrint(
        "[WebRTC] Queuing ICE candidate from $fromUserId (no remote desc yet).",
      );
      _remoteCandidateQueues.putIfAbsent(fromUserId, () => []).add(candidate);
    }
  }

  Future<void> _processQueuedCandidates(String userId) async {
    final token = _sessionToken;
    final pc = _peerConnections[userId];
    final queue = _remoteCandidateQueues.remove(userId);
    if (pc == null || queue == null) return;

    debugPrint(
      "[WebRTC] Processing ${queue.length} queued candidates for $userId.",
    );
    for (final candidate in queue) {
      if (_isDisposed ||
          _sessionToken != token ||
          _peerConnections[userId] != pc) {
        break;
      }
      await pc.addCandidate(candidate);
    }
  }

  Future<void> _handleRemoteBye(String fromUserId) async {
    debugPrint("[WebRTC] Received bye from $fromUserId.");

    // FIX: Mark as pending-bye so CallBloc's delayed connect() won't fire
    // while the room-update confirming the user left is still in transit.
    // Cleared automatically after 2s or immediately by forgetUser().
    _pendingByeUsers.add(fromUserId);
    Future.delayed(const Duration(seconds: 2), () {
      _pendingByeUsers.remove(fromUserId);
    });

    final pc = _peerConnections[fromUserId];
    if (pc != null) await _closePeer(fromUserId, pc);
    onRemoteStreamRemoved?.call(fromUserId);
    onRemoteBye?.call(fromUserId);
    await _signalingService?.clearIncomingFromUser(fromUserId);
  }

  // ─── Signaling send ───────────────────────────────────────────────────────

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

  // ─── User management ──────────────────────────────────────────────────────

  @override
  Future<void> forgetUser(String userId) async {
    debugPrint("[WebRTC] Forgetting user $userId.");

    // FIX: Clear pending-bye flag immediately — room-update confirmed the
    // user left, no longer need the reconnect-suppression window.
    _pendingByeUsers.remove(userId);

    final pcToForget = _peerConnections[userId];
    if (pcToForget != null) await _closePeer(userId, pcToForget);
    _connectingPeers.remove(userId);
    await _signalingService?.clearIncomingFromUser(userId);
    onRemoteStreamRemoved?.call(userId);
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    await leaveRoom();
  }

  /// Returns true if a bye was received for this user but the room-update
  /// confirming they left has not yet arrived. CallBloc uses this to suppress
  /// a premature reconnect attempt during the bye→room-update race window.
  bool isUserPendingBye(String userId) => _pendingByeUsers.contains(userId);

  /// Updates the host/guest role at runtime.
  /// Called by CallBloc whenever the room document changes so that glare
  /// resolution (impolite=host ignores offer, polite=guest closes and answers)
  /// stays correct even after a host transfer or host rejoin.
  void updateHostStatus(bool isHost) {
    if (_isHost != isHost) {
      debugPrint("[WebRTC] Host status updated: isHost=$isHost");
      _isHost = isHost;
    }
  }

  // ─── Audio level helpers ──────────────────────────────────────────────────

  @override
  Future<double> getRemoteAudioLevel(String userId) async {
    final pc = _peerConnections[userId];
    if (pc == null) return 0.0;

    try {
      final stats = await pc.getStats();
      for (final report in stats) {
        if (report.type == 'inbound-rtp' && _isAudio(report.values)) {
          final level = report.values['audioLevel'];
          if (level != null) return (level is num) ? level.toDouble() : 0.0;

          final totalAudioEnergy = report.values['totalAudioEnergy'];
          final totalSamplesDuration = report.values['totalSamplesDuration'];

          if (totalAudioEnergy != null && totalSamplesDuration != null) {
            final currentEnergy = (totalAudioEnergy is num)
                ? totalAudioEnergy.toDouble()
                : 0.0;
            final currentDuration = (totalSamplesDuration is num)
                ? totalSamplesDuration.toDouble()
                : 0.0;

            final lastEnergy = _lastTotalAudioEnergy[userId];
            final lastDuration = _lastTotalSamplesDuration[userId];

            _lastTotalAudioEnergy[userId] = currentEnergy;
            _lastTotalSamplesDuration[userId] = currentDuration;

            if (lastEnergy != null && lastDuration != null) {
              final durationDelta = currentDuration - lastDuration;
              if (durationDelta > 0) {
                final averagePower =
                    (currentEnergy - lastEnergy) / durationDelta;
                return (averagePower * 10).clamp(0.0, 1.0);
              }
            }
            return 0.0;
          }
        }
        // TRACK and MEDIA-SOURCE checks REMOVED from remote level because on some
        // platforms/versions they refer to the local microphone source attached
        // to the PeerConnection, causing local audio to trigger remote-active-speaker.
      }
    } catch (e) {
      debugPrint("[WebRTC] Error getting remote stats: $e");
    }
    return 0.0;
  }

  void _startLocalAudioMonitor() {
    _localAudioTimer?.cancel();
    final token = _sessionToken;
    _localAudioTimer = Timer.periodic(const Duration(milliseconds: 500), (
      _,
    ) async {
      if (_isDisposed || _sessionToken != token || _peerConnections.isEmpty) {
        _localAudioLevel = 0.0;
        return;
      }
      try {
        final pc = _peerConnections.values.first;
        final stats = await pc.getStats();
        // Current Chrome and libwebrtc report the microphone's level on
        // its media-source; outbound-rtp only carried it in older versions.
        for (final report in stats) {
          if (report.type == 'media-source' && _isAudio(report.values)) {
            final level = report.values['audioLevel'];
            if (level is num) {
              _localAudioLevel = level.toDouble().clamp(0.0, 1.0);
              return;
            }
          }
        }
        for (final report in stats) {
          if (report.type == 'outbound-rtp' && _isAudio(report.values)) {
            final e = (report.values['totalAudioEnergy'] as num?)?.toDouble();
            final d = (report.values['totalSamplesDuration'] as num?)
                ?.toDouble();
            if (e != null && d != null) {
              final lastE = _lastTotalAudioEnergy['__local__'];
              final lastD = _lastTotalSamplesDuration['__local__'];
              _lastTotalAudioEnergy['__local__'] = e;
              _lastTotalSamplesDuration['__local__'] = d;
              if (lastE != null && lastD != null && (d - lastD) > 0) {
                _localAudioLevel = ((e - lastE) / (d - lastD) * 10).clamp(
                  0.0,
                  1.0,
                );
                return;
              }
            }
          }
        }
        _localAudioLevel = 0.0;
      } catch (_) {
        _localAudioLevel = 0.0;
      }
    });
  }

  @override
  Future<double> getLocalAudioLevel() async => _localAudioLevel;

  /// `kind` in current stats; `mediaType` was dropped from Chrome and
  /// libwebrtc, which left speaking levels stuck at zero.
  static bool _isAudio(Map<dynamic, dynamic> values) =>
      values['kind'] == 'audio' || values['mediaType'] == 'audio';
}
