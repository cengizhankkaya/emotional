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

  // Audio Level Fallback (Energy Calculation)
  final Map<String, double> _lastTotalAudioEnergy = {};
  final Map<String, double> _lastTotalSamplesDuration = {};

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
  void updateLocalStream(webrtc.MediaStream? stream) {
    _localStream = stream;
    // CRITICAL: We DO NOT manually loop and addTrack here anymore.
    // addTrack fails if the same kind of track is already added, causing crashes.
    // Dynamic track updates should be handled via replaceLocalAllVideoTrack/replaceLocalAllAudioTrack
    // which use replaceTrack on existing senders.
    print("[WebRTC] localStream updated. New StreamID: ${stream?.id}");
  }

  // Specific helper to replace track for all peers
  Future<void> replaceLocalAllVideoTrack(
    webrtc.MediaStreamTrack newTrack,
  ) async {
    for (var entry in _peerConnections.entries) {
      final userId = entry.key;
      final pc = entry.value;
      try {
        var senders = await pc.getSenders();
        // Modern WebRTC way: find the video sender and replace track
        bool replaced = false;
        for (var sender in senders) {
          if (sender.track?.kind == 'video') {
            print(
              "[WebRTC] Replacing video track for user $userId. NewTrackID: ${newTrack.id}",
            );
            await sender.replaceTrack(newTrack);
            replaced = true;
          }
        }

        // If no video sender was found (e.g. user started without camera)
        // we must initiate a full reconnect to add the new track,
        // as this service's basic signaling doesn't support easy mid-call addTrack negotiation.
        if (!replaced) {
          print(
            "[WebRTC] No video sender found for $userId. Triggering full reconnect to add screen/video track.",
          );
          // We don't call pc.addTrack here because connect() will create a fresh PC with the new _localStream
          await connect(userId);
        }
      } catch (e) {
        print("[WebRTC] Error replacing video track for $userId: $e");
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
    await _signalingService!.initialize();

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
    _remoteCandidateQueues.clear();
    _remoteDescriptionSet.clear();
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
        print(
          "[WebRTC] onTrack: Received stream from $targetUserId. StreamID: ${event.streams.first.id}, Tracks: ${event.streams.first.getTracks().length}",
        );
        onRemoteStream?.call(event.streams.first, targetUserId);
      } else {
        print(
          "[WebRTC] onTrack: Received event from $targetUserId but STREAMS ARE EMPTY.",
        );
      }
    };

    // Legacy support (Plan B - though verify if needed for this web/mobile project, usually onTrack is best)
    pc.onAddStream = (stream) {
      onRemoteStream?.call(stream, targetUserId);
    };

    // Peer Connection State (optional logging)
    pc.onConnectionState = (state) async {
      print("[WebRTC] Connection state with $targetUserId: $state");

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        print(
          "[WebRTC] Connection failed with $targetUserId. Attempting full reconnect...",
        );
        await connect(targetUserId); // Full reconnect
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        // Soft recovery (Ice Restart)
        print(
          "[WebRTC] Disconnected from $targetUserId. Initiating ICE Restart...",
        );

        // Wait a bit to see if it recovers naturally
        await Future.delayed(const Duration(seconds: 3));

        var currentPc = _peerConnections[targetUserId];
        if (currentPc == pc) {
          var currentState = await pc.getConnectionState();
          if (currentState ==
              RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
            print(
              "[WebRTC] Still disconnected from $targetUserId. Sending offer with iceRestart: true",
            );
            await _triggerIceRestart(targetUserId);
          }
        }
      }
    };

    _peerConnections[targetUserId] = pc;
    return pc;
  }

  @override
  Future<void> connect(String targetUserId) async {
    if (_peerConnections.containsKey(targetUserId)) {
      final pc = _peerConnections[targetUserId];
      final state = await pc?.getConnectionState();
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        print("[WebRTC] Already connected to $targetUserId");
        return;
      }
      print("[WebRTC] Connection to $targetUserId is $state, restarting...");
      await pc?.close();
      _peerConnections.remove(targetUserId);
    }

    print("[WebRTC] Creating peer connection for $targetUserId");
    final pc = await createPeerConnection(targetUserId);

    // Yeni teklif göndermeden önce o kullanıcıya giden tüm ESKİ sinyalleri (candidates vb.) temizle.
    await _signalingService?.clearOutgoingToUser(targetUserId);

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    await sendOffer(targetUserId, offer);
  }

  /// ICE Restart tetikleyici
  Future<void> _triggerIceRestart(String targetUserId) async {
    final pc = _peerConnections[targetUserId];
    if (pc == null) return;

    try {
      // createOffer with iceRestart: true
      final offer = await pc.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
        'iceRestart': true,
      });
      await pc.setLocalDescription(offer);
      await sendOffer(targetUserId, offer);
      print("[WebRTC] ICE Restart offer sent to $targetUserId");
    } catch (e) {
      print("[WebRTC] Error during ICE Restart for $targetUserId: $e");
      // If ICE Restart fails, try full reconnect
      await connect(targetUserId);
    }
  }

  final Map<String, List<RTCIceCandidate>> _remoteCandidateQueues = {};
  final Set<String> _remoteDescriptionSet = {};

  Future<void> _handleRemoteOffer(
    RTCSessionDescription description,
    String fromUserId,
  ) async {
    print("[WebRTC] Received offer from $fromUserId");
    var stalePc = _peerConnections[fromUserId];

    if (stalePc != null) {
      print(
        "[WebRTC] Closing stale PC for $fromUserId before processing new offer",
      );
      _peerConnections.remove(
        fromUserId,
      ); // Önce haritadan çıkar ki yeni PC ile karışmasın
      await stalePc.close();
      _remoteDescriptionSet.remove(fromUserId);
      _remoteCandidateQueues.remove(fromUserId);
    }

    final pc = await createPeerConnection(fromUserId);
    await pc.setRemoteDescription(description);
    _remoteDescriptionSet.add(fromUserId);
    print("[WebRTC] Remote description set for offer from $fromUserId");

    // Process queued candidates
    await _processQueuedCandidates(fromUserId);

    // Cevap göndermeden önce o kullanıcıya giden eski sinyalleri temizle.
    await _signalingService?.clearOutgoingToUser(fromUserId);

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    await sendAnswer(fromUserId, answer);
    print("[WebRTC] Sent answer to $fromUserId");
  }

  Future<void> _handleRemoteAnswer(
    RTCSessionDescription description,
    String fromUserId,
  ) async {
    print("[WebRTC] Received answer from $fromUserId");
    var pc = _peerConnections[fromUserId];
    if (pc != null) {
      await pc.setRemoteDescription(description);
      _remoteDescriptionSet.add(fromUserId);
      print("[WebRTC] Remote description set for answer from $fromUserId");

      // Process queued candidates
      await _processQueuedCandidates(fromUserId);
    }
  }

  Future<void> _handleRemoteIceCandidate(
    RTCIceCandidate candidate,
    String fromUserId,
  ) async {
    var pc = _peerConnections[fromUserId];
    if (pc != null) {
      if (_remoteDescriptionSet.contains(fromUserId)) {
        print("[WebRTC] Adding ICE candidate from $fromUserId");
        await pc.addCandidate(candidate);
      } else {
        print(
          "[WebRTC] Queuing ICE candidate from $fromUserId (Remote description not set yet)",
        );
        _remoteCandidateQueues.putIfAbsent(fromUserId, () => []).add(candidate);
      }
    }
  }

  Future<void> _processQueuedCandidates(String userId) async {
    final pc = _peerConnections[userId];
    final queue = _remoteCandidateQueues.remove(userId);
    if (pc != null && queue != null) {
      print(
        "[WebRTC] Processing ${queue.length} queued candidates for $userId",
      );
      for (var candidate in queue) {
        await pc.addCandidate(candidate);
      }
    }
  }

  Future<void> _handleRemoteBye(String fromUserId) async {
    print("[WebRTC] Received bye from $fromUserId");
    var pc = _peerConnections[fromUserId];
    if (pc != null) {
      await pc.close();
      _peerConnections.remove(fromUserId);
    }
    _remoteDescriptionSet.remove(fromUserId);
    _remoteCandidateQueues.remove(fromUserId);
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
  Future<void> forgetUser(String userId) async {
    print("[WebRTC] Forgetting user $userId");
    var pcToForget = _peerConnections[userId];
    if (pcToForget != null) {
      // Sadece eğer haritadaki PC hala bizim bulduğumuz PC ise sil
      // (Yarış durumunda yeni bir PC gelmiş olabilir)
      if (_peerConnections[userId] == pcToForget) {
        _peerConnections.remove(userId);
      }
      await pcToForget.close();
    }

    // Eğer biz siliyorsak, description ve kuyrukları da temizle (ama sadece bu session için)
    // Not: Re-entry durumunda yeni bir session başlamış olabilir, bu yüzden instance bazlı kontrol zor.
    // Ancak genellikle forgetUser 'ayrılma' anında çağrılır.
    _remoteDescriptionSet.remove(userId);
    _remoteCandidateQueues.remove(userId);

    // Kendi signaling kanalımızdaki bu kullanıcıdan gelen verileri temizle
    await _signalingService?.clearIncomingFromUser(userId);

    onRemoteStreamRemoved?.call(userId);
  }

  @override
  Future<void> dispose() async {
    await leaveRoom();
  }

  // Helper to get audio level (0.0 to 1.0)
  Future<double> getRemoteAudioLevel(String userId) async {
    final pc = _peerConnections[userId];
    if (pc == null) return 0.0;

    try {
      final stats = await pc.getStats();
      for (var report in stats) {
        // Look for 'inbound-rtp' with mediaType 'audio'
        if (report.type == 'inbound-rtp' &&
            report.values['mediaType'] == 'audio') {
          // audioLevel is usually 0..1 defined in recent specs, or energy.
          // Standard property is 'audioLevel'.
          var level = report.values['audioLevel'];
          if (level != null) {
            return (level is num) ? level.toDouble() : 0.0;
          }

          // Fallback Strategy: totalAudioEnergy
          var totalAudioEnergy = report.values['totalAudioEnergy'];
          var totalSamplesDuration = report.values['totalSamplesDuration'];

          if (totalAudioEnergy != null && totalSamplesDuration != null) {
            double currentEnergy = (totalAudioEnergy is num)
                ? totalAudioEnergy.toDouble()
                : 0.0;
            double currentDuration = (totalSamplesDuration is num)
                ? totalSamplesDuration.toDouble()
                : 0.0;

            double? lastEnergy = _lastTotalAudioEnergy[userId];
            double? lastDuration = _lastTotalSamplesDuration[userId];

            _lastTotalAudioEnergy[userId] = currentEnergy;
            _lastTotalSamplesDuration[userId] = currentDuration;

            if (lastEnergy != null && lastDuration != null) {
              double energyDelta = currentEnergy - lastEnergy;
              double durationDelta = currentDuration - lastDuration;

              if (durationDelta > 0) {
                // Average power = Energy / Time.
                // Audio level is usually sqrt(power) or similar, but for VAD, energy/time is a good proxy.
                // The WebRTC spec defines audioLevel as 0..1 linear.
                // Energy is usually in specific units. We might need to normalize or just use threshold.
                // Let's assume a raw activity level for now.
                double averagePower = energyDelta / durationDelta;
                // Empower heuristic: if power > small_value, return something > 0.01
                // Standard normalization is tricky without knowing implementation specifics.
                // But if it's > 0, it means there is audio.
                // Let's return a clamped value.
                return (averagePower * 10).clamp(0.0, 1.0);
              }
            }
            return 0.0; // Wait for next sample for delta
          } else {
            print(
              "[WebRTC] Found inbound-rtp audio but NO audioLevel OR energy. Keys: ${report.values.keys}",
            );
          }
        }

        // Check for 'track' stats as fallback
        if (report.type == 'track' && report.values['kind'] == 'audio') {
          var level = report.values['audioLevel'];
          if (level != null) {
            return (level is num) ? level.toDouble() : 0.0;
          }
        }

        // Check for 'media-source' stats as fallback
        if (report.type == 'media-source' && report.values['kind'] == 'audio') {
          var level = report.values['audioLevel'];
          if (level != null) {
            return (level is num) ? level.toDouble() : 0.0;
          }
        }
      }
    } catch (e) {
      print("[WebRTC] Error getting stats: $e");
    }
    return 0.0;
  }

  // Helper to get LOCAL audio level (0.0 to 1.0)
  Future<double> getLocalAudioLevel() async {
    if (_peerConnections.isEmpty) return 0.0;

    // We can check stats on ANY active peer connection to get local source stats
    try {
      final pc = _peerConnections.values.first;
      final stats = await pc.getStats();
      for (var report in stats) {
        // Look for 'media-source' which represents the local audio source
        if (report.type == 'media-source' && report.values['kind'] == 'audio') {
          var level = report.values['audioLevel'];
          if (level != null) {
            return (level is num) ? level.toDouble() : 0.0;
          }
        }

        // Fallback: 'outbound-rtp' might also have audio level
        if (report.type == 'outbound-rtp' &&
            report.values['mediaType'] == 'audio') {
          // Some browsers/implementations put input level here? rarely.
          // Usually it's 'media-source'.
        }
      }
    } catch (e) {
      print("[WebRTC] Error getting local stats: $e");
    }
    return 0.0;
  }
}
