import 'dart:async';
import 'package:emotional/features/call/domain/services/i_call_service.dart';
import 'package:emotional/features/call/service/signaling_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService implements ICallService {
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

  @override
  Function(MediaStream stream, String userId)? onRemoteStream;

  @override
  Function(String userId)? onRemoteStreamRemoved;

  MediaStream? _localStream;

  @override
  void updateLocalStream(webrtc.MediaStream? stream) {
    _localStream = stream;
    print("[WebRTC] localStream updated. New StreamID: ${stream?.id}");
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
          if (t.sender.track?.kind == 'video' ||
              t.receiver.track?.kind == 'video') {
            print(
              "[WebRTC] Replacing video track for $userId. NewTrackID: ${newTrack.id}",
            );
            await t.sender.replaceTrack(newTrack);
            if (_isDisposed || _sessionToken != token) return;
            replaced = true;
          }
        }

        if (!replaced) {
          print(
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
      } catch (e) {
        print("[WebRTC] Error replacing video track for $userId: $e");
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
        print(
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
    _signalingService = SignalingService(roomId: roomId, userId: userId);
    await _signalingService!.initialize();
    _setupSignalingListeners();
    _startLocalAudioMonitor();
  }

  void _setupSignalingListeners() {
    if (_signalingService == null) return;

    _signalingService!.onRemoteOffer = (description, fromUserId) async {
      if (_isDisposed) return;
      await _handleRemoteOffer(description, fromUserId);
    };

    _signalingService!.onRemoteAnswer = (description, fromUserId) async {
      if (_isDisposed) return;
      await _handleRemoteAnswer(description, fromUserId);
    };

    _signalingService!.onRemoteIceCandidate = (candidate, fromUserId) async {
      if (_isDisposed) return;
      await _handleRemoteIceCandidate(candidate, fromUserId);
    };

    _signalingService!.onRemoteBye = (fromUserId) async {
      if (_isDisposed) return;
      await _handleRemoteBye(fromUserId);
    };
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

    if (!hasAudio) {
      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv),
      );
    }
    if (!hasVideo) {
      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv),
      );
    }

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
        print("[WebRTC] onTrack from $targetUserId — streams are EMPTY.");
        return;
      }
      final stream = event.streams.first;
      // Skip if we already reported this stream (e.g. second track event)
      if (_lastRemoteStreamId[targetUserId] == stream.id) return;
      _lastRemoteStreamId[targetUserId] = stream.id;
      print("[WebRTC] onTrack from $targetUserId. StreamID: ${stream.id}");
      onRemoteStream?.call(stream, targetUserId);
    };

    // NOTE: onAddStream is intentionally NOT set.
    // onAddStream and onTrack both fire for the same remote stream on Android,
    // causing a double InternalIncomingStream. onTrack is the modern standard;
    // onAddStream is legacy and redundant here.

    pc.onConnectionState = (state) async {
      print("[WebRTC] Connection state with $targetUserId: $state");
      if (_isDisposed) return;
      final cbToken = _sessionToken;

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        print("[WebRTC] Connection failed with $targetUserId. Reconnecting...");
        if (_peerConnections[targetUserId] != pc) return;
        if (!_isDisposed && _sessionToken == cbToken) {
          await connect(targetUserId);
        }
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        print("[WebRTC] Disconnected from $targetUserId. ICE Restart in 3s...");
        if (_peerConnections[targetUserId] != pc) return;

        await Future.delayed(const Duration(seconds: 3));
        if (_isDisposed || _sessionToken != cbToken) return;
        if (_peerConnections[targetUserId] != pc) return;

        final currentState = await pc.getConnectionState();
        if (_isDisposed || _sessionToken != cbToken) return;
        if (_peerConnections[targetUserId] != pc) return;

        if (currentState ==
            RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          print("[WebRTC] Still disconnected from $targetUserId. ICE Restart.");
          await _triggerIceRestart(targetUserId);
        }
      }
    };

    _peerConnections[targetUserId] = pc;
    return pc;
  }

  @override
  Future<void> connect(String targetUserId) async {
    if (_isDisposed) return;
    final token = _sessionToken;

    if (_connectingPeers.contains(targetUserId)) {
      print("[WebRTC] connect() for $targetUserId already in progress.");
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
          print("[WebRTC] Already connected to $targetUserId.");
          return;
        }
        print("[WebRTC] Connection to $targetUserId is $state. Restarting...");
        await pc?.close();
        await pc?.dispose();
        _peerConnections.remove(targetUserId);
      }

      if (_isDisposed || _sessionToken != token) return;

      print("[WebRTC] Creating peer connection for $targetUserId.");
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
        final offer = await pc.createOffer({
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': true,
        });
        if (_isDisposed ||
            _sessionToken != token ||
            _peerConnections[targetUserId] != pc) {
          return;
        }
        await pc.setLocalDescription(offer);
        if (_isDisposed ||
            _sessionToken != token ||
            _peerConnections[targetUserId] != pc) {
          return;
        }
        await sendOffer(targetUserId, offer);
      } catch (e) {
        print("[WebRTC] connect() createOffer failed for $targetUserId: $e");
      }
    } finally {
      _connectingPeers.remove(targetUserId);
    }
  }

  Future<void> _triggerIceRestart(String targetUserId) async {
    if (_isDisposed) return;
    final token = _sessionToken;
    final pc = _peerConnections[targetUserId];
    if (pc == null) return;

    try {
      final offer = await pc.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
        'iceRestart': true,
      });
      if (_isDisposed ||
          _sessionToken != token ||
          _peerConnections[targetUserId] != pc) {
        return;
      }
      await pc.setLocalDescription(offer);
      if (_isDisposed ||
          _sessionToken != token ||
          _peerConnections[targetUserId] != pc) {
        return;
      }
      await sendOffer(targetUserId, offer);
      print("[WebRTC] ICE Restart offer sent to $targetUserId.");
    } catch (e) {
      print("[WebRTC] ICE Restart failed for $targetUserId: $e");
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
    print("[WebRTC] Received offer from $fromUserId.");
    final stalePc = _peerConnections[fromUserId];

    if (stalePc != null) {
      if (_isHost) {
        print(
          "[WebRTC] GLARE: HOST (impolite). Ignoring offer from $fromUserId.",
        );
        return;
      } else {
        print(
          "[WebRTC] GLARE: GUEST (polite). Closing stale PC for $fromUserId.",
        );
        _peerConnections.remove(fromUserId);
        _connectingPeers.remove(fromUserId); // Fix: allow new connection
        await stalePc.close();
        await stalePc.dispose();
        if (_isDisposed || _sessionToken != token) return;
        _remoteDescriptionSet.remove(fromUserId);
        _remoteCandidateQueues.remove(fromUserId);
      }
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

    await pc.setRemoteDescription(description);
    if (_isDisposed ||
        _sessionToken != token ||
        _peerConnections[fromUserId] != pc) {
      return;
    }
    _remoteDescriptionSet.add(fromUserId);
    print("[WebRTC] Remote description set for offer from $fromUserId.");

    await _processQueuedCandidates(fromUserId);
    if (_isDisposed ||
        _sessionToken != token ||
        _peerConnections[fromUserId] != pc) {
      return;
    }

    await _signalingService?.clearOutgoingToUser(fromUserId);
    if (_isDisposed ||
        _sessionToken != token ||
        _peerConnections[fromUserId] != pc) {
      return;
    }

    final answer = await pc.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });
    if (_isDisposed ||
        _sessionToken != token ||
        _peerConnections[fromUserId] != pc) {
      return;
    }
    await pc.setLocalDescription(answer);
    if (_isDisposed ||
        _sessionToken != token ||
        _peerConnections[fromUserId] != pc) {
      return;
    }

    await sendAnswer(fromUserId, answer);
    print("[WebRTC] Answer sent to $fromUserId.");
  }

  Future<void> _handleRemoteAnswer(
    RTCSessionDescription description,
    String fromUserId,
  ) async {
    if (_isDisposed) return;
    final token = _sessionToken;
    print("[WebRTC] Received answer from $fromUserId.");
    final pc = _peerConnections[fromUserId];
    if (pc == null) return;

    final signalingState = await pc.getSignalingState();
    if (_isDisposed ||
        _sessionToken != token ||
        _peerConnections[fromUserId] != pc) {
      return;
    }

    if (signalingState != RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
      print(
        "[WebRTC] Ignoring stale answer from $fromUserId. State: $signalingState.",
      );
      return;
    }

    await pc.setRemoteDescription(description);
    if (_isDisposed ||
        _sessionToken != token ||
        _peerConnections[fromUserId] != pc) {
      return;
    }
    _remoteDescriptionSet.add(fromUserId);
    print("[WebRTC] Remote description set for answer from $fromUserId.");

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
      print("[WebRTC] Adding ICE candidate from $fromUserId.");
      await pc.addCandidate(candidate);
    } else {
      print(
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

    print("[WebRTC] Processing ${queue.length} queued candidates for $userId.");
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
    print("[WebRTC] Received bye from $fromUserId.");

    // FIX: Mark as pending-bye so CallBloc's delayed connect() won't fire
    // while the room-update confirming the user left is still in transit.
    // Cleared automatically after 2s or immediately by forgetUser().
    _pendingByeUsers.add(fromUserId);
    Future.delayed(const Duration(seconds: 2), () {
      _pendingByeUsers.remove(fromUserId);
    });

    final pc = _peerConnections[fromUserId];
    if (pc != null) {
      if (_peerConnections[fromUserId] == pc) {
        _peerConnections.remove(fromUserId);
      }
      await pc.close();
      await pc.dispose();
    }
    _remoteDescriptionSet.remove(fromUserId);
    _remoteCandidateQueues.remove(fromUserId);
    _lastRemoteStreamId.remove(fromUserId);
    onRemoteStreamRemoved?.call(fromUserId);
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
    print("[WebRTC] Forgetting user $userId.");

    // FIX: Clear pending-bye flag immediately — room-update confirmed the
    // user left, no longer need the reconnect-suppression window.
    _pendingByeUsers.remove(userId);

    final pcToForget = _peerConnections[userId];
    if (pcToForget != null) {
      if (_peerConnections[userId] == pcToForget) {
        _peerConnections.remove(userId);
      }
      await pcToForget.close();
      await pcToForget.dispose();
    }
    _remoteDescriptionSet.remove(userId);
    _remoteCandidateQueues.remove(userId);
    _lastRemoteStreamId.remove(userId);
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
      print("[WebRTC] Host status updated: isHost=$isHost");
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
        if (report.type == 'inbound-rtp' &&
            report.values['mediaType'] == 'audio') {
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
      print("[WebRTC] Error getting remote stats: $e");
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
        for (final report in stats) {
          if (report.type == 'outbound-rtp' &&
              (report.values['mediaType'] == 'audio' ||
                  report.values['kind'] == 'audio')) {
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
}
