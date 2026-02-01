import 'dart:async';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/call/service/signaling_service.dart';
import 'package:emotional/features/call/service/webrtc_manager.dart';
import 'package:emotional/features/room/repository/room_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:emotional/core/services/permission_service.dart';
import 'package:permission_handler/permission_handler.dart';

class CallBloc extends Bloc<CallEvent, CallState> {
  final RoomRepository roomRepository;

  SignalingService? _signalingService;
  final WebRTCManager _webRTCManager;

  // Active Connections
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  RTCVideoRenderer? _localRenderer;
  Map<String, String> _activeUsers = {};
  Map<String, bool> _userVideoStates = {};

  StreamSubscription? _roomSubscription;

  String? _roomId;
  String? _userId;
  String? get userId => _userId;

  CallBloc({required this.roomRepository})
    : _webRTCManager = WebRTCManager(),
      super(CallInitial()) {
    on<JoinCall>(_onJoinCall);
    on<LeaveCall>(_onLeaveCall);
    on<IncomingOffer>(_onIncomingOffer);
    on<IncomingAnswer>(_onIncomingAnswer);
    on<IncomingIceCandidate>(_onIncomingIceCandidate);
    on<IncomingBye>(_onIncomingBye);
    on<ToggleMute>(_onToggleMute);
    on<ToggleVideo>(_onToggleVideo);
    on<SwitchCamera>(_onSwitchCamera);
    on<InternalUpdateState>((event, emit) {
      if (state is CallConnected) {
        emit(
          (state as CallConnected).copyWith(
            remoteRenderers: Map.from(_remoteRenderers),
            activeUsers: Map.from(_activeUsers),
            userVideoStates: Map.from(_userVideoStates),
          ),
        );
      }
    });
  }

  // Pending connections to prevent race conditions
  final Set<String> _connecting = {};

  Future<void> _onJoinCall(JoinCall event, Emitter<CallState> emit) async {
    emit(CallLoading());
    try {
      _roomId = event.roomId;
      _userId = event.userId;
      _connecting.clear();

      // Check Permissions
      final permissionService = PermissionService();
      final permissions = await permissionService
          .requestCameraAndMicrophonePermissions();

      final cameraGranted = permissions[Permission.camera] ?? false;
      final microphoneGranted = permissions[Permission.microphone] ?? false;

      if (!cameraGranted || !microphoneGranted) {
        emit(CallError('Kamera ve mikrofon izinleri gerekli.'));
        return;
      }

      await _cleanup(); // Safety cleanup

      // Setup Local Renderer first so it's ready for stream
      _localRenderer = RTCVideoRenderer();
      await _localRenderer!.initialize();

      _webRTCManager.onLocalStream = (stream) {
        _localRenderer!.srcObject = stream;
      };

      // Initialize WebRTC Manager (Get Local Stream)
      await _webRTCManager.initialize();

      // Ensure audio is routed to speaker
      _webRTCManager.enableSpeakerphone(true);

      // Initialize Signaling
      _signalingService = SignalingService(roomId: _roomId!, userId: _userId!);
      _signalingService!.initialize();

      _setupSignalingListeners();
      _setupSignalingListeners();
      _setupRoomListeners(); // To discover users

      // Initialize User Media State in Firebase
      await roomRepository.updateUserMediaState(
        _roomId!,
        _userId!,
        isVideoEnabled: true, // Default to true on join
        isAudioEnabled: true, // Default to true on join
      );

      emit(
        CallConnected(
          localRenderer: _localRenderer!,
          remoteRenderers: const {},
          activeUsers: const {},
          userVideoStates: const {},
        ),
      );
    } catch (e) {
      emit(CallError('Failed to join call: $e'));
    }
  }

  void _setupSignalingListeners() {
    _signalingService!.onRemoteOffer = (desc, fromUserId) {
      add(IncomingOffer(userId: fromUserId, description: desc));
    };

    _signalingService!.onRemoteAnswer = (desc, fromUserId) {
      add(IncomingAnswer(userId: fromUserId, description: desc));
    };

    _signalingService!.onRemoteIceCandidate = (candidate, fromUserId) {
      add(IncomingIceCandidate(userId: fromUserId, candidate: candidate));
    };

    _signalingService!.onRemoteBye = (fromUserId) {
      add(IncomingBye(userId: fromUserId));
    };
  }

  void _setupRoomListeners() {
    if (_roomId == null || _userId == null) return;

    _roomSubscription = roomRepository.streamRoom(_roomId!).listen((event) {
      final snapshot = event.snapshot;
      if (snapshot.value == null) return;

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      if (!data.containsKey('users')) return;

      final users = Map<String, dynamic>.from(data['users'] as Map);
      final currentUserIds = users.keys.toSet();

      // Update active users map for UI
      _activeUsers = users.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );

      // Handle Users State (Video/Audio)
      if (data.containsKey('usersState')) {
        final states = Map<String, dynamic>.from(data['usersState'] as Map);
        _userVideoStates.clear();
        states.forEach((uid, stateData) {
          final s = Map<String, dynamic>.from(stateData as Map);
          _userVideoStates[uid.toString()] = s['video'] as bool? ?? false;
        });
      }

      add(InternalUpdateState()); // UI'ı güncelle

      // Odadan çıkan kullanıcıları temizle (Bye göndermeden ayrılanlar için)
      for (final peerId in _peerConnections.keys.toList()) {
        if (!currentUserIds.contains(peerId)) {
          _removePeer(peerId);
        }
      }

      // Odadaki diğer kullanıcılara bağlan
      for (final otherUserId in currentUserIds) {
        if (otherUserId == _userId) continue;
        if (_peerConnections.containsKey(otherUserId) ||
            _connecting.contains(otherUserId))
          continue;

        _initiateCallTo(otherUserId);
      }
    });
  }

  /// Tek bir peer'ı kaldır (PC kapat, renderer dispose, Bye gönder)
  Future<void> _removePeer(String userId) async {
    await _signalingService?.sendBye(userId);

    final pc = _peerConnections[userId];
    if (pc != null) {
      await pc.close();
      _peerConnections.remove(userId);
    }

    final renderer = _remoteRenderers[userId];
    if (renderer != null) {
      renderer.srcObject = null;
      await renderer.dispose();
      _remoteRenderers.remove(userId);
    }
    _connecting.remove(userId);
    add(InternalUpdateState());
  }

  Future<void> _initiateCallTo(String targetUserId) async {
    _connecting.add(targetUserId);
    try {
      final pc = await _webRTCManager.createPeerConnectionForUser(targetUserId);
      _peerConnections[targetUserId] = pc;

      _setupPeerConnectionListeners(pc, targetUserId);

      RTCSessionDescription offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      await _signalingService!.sendOffer(targetUserId, offer);
    } catch (e) {
      print('Error initiating call to $targetUserId: $e');
      _connecting.remove(targetUserId);
    }
  }

  void _setupPeerConnectionListeners(
    RTCPeerConnection pc,
    String targetUserId,
  ) {
    pc.onIceCandidate = (candidate) {
      _signalingService?.sendIceCandidate(targetUserId, candidate);
    };

    pc.onAddStream = (MediaStream stream) {
      final renderer = RTCVideoRenderer();
      renderer.initialize().then((_) {
        renderer.srcObject = stream;
        _remoteRenderers[targetUserId] = renderer;
        _connecting.remove(targetUserId); // Successfully connected
        add(InternalUpdateState());
      });
    };

    // Also remove from connecting if failed/closed?
    // pc.onConnectionState...
  }

  Future<void> _onIncomingOffer(
    IncomingOffer event,
    Emitter<CallState> emit,
  ) async {
    _connecting.add(event.userId);

    // Glare: Zaten bu kullanıcıya biz offer göndermişsek mevcut PC'yi kullan
    RTCPeerConnection pc;
    final existing = _peerConnections[event.userId];
    if (existing == null) {
      pc = await _webRTCManager.createPeerConnectionForUser(event.userId);
      _peerConnections[event.userId] = pc;
      _setupPeerConnectionListeners(pc, event.userId);
    } else {
      pc = existing;
    }

    await pc.setRemoteDescription(event.description);
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    await _signalingService!.sendAnswer(event.userId, answer);
  }

  Future<void> _onIncomingAnswer(
    IncomingAnswer event,
    Emitter<CallState> emit,
  ) async {
    final pc = _peerConnections[event.userId];
    if (pc != null) {
      await pc.setRemoteDescription(event.description);
    }
  }

  Future<void> _onIncomingIceCandidate(
    IncomingIceCandidate event,
    Emitter<CallState> emit,
  ) async {
    final pc = _peerConnections[event.userId];
    if (pc != null) {
      await pc.addCandidate(event.candidate);
    }
  }

  Future<void> _onIncomingBye(
    IncomingBye event,
    Emitter<CallState> emit,
  ) async {
    final userId = event.userId;

    // Peer ve renderer temizle
    final pc = _peerConnections[userId];
    if (pc != null) {
      await pc.close();
      _peerConnections.remove(userId);
    }
    final renderer = _remoteRenderers[userId];
    if (renderer != null) {
      renderer.srcObject = null;
      await renderer.dispose();
      _remoteRenderers.remove(userId);
    }
    _connecting.remove(userId);

    // Bu kullanıcının bize yazdığı offer/answer/candidates'ı sil ki tekrar
    // aramaya girince aynı path'e yazdığı offer yeni child sayılsın (onChildAdded tetiklensin).
    await _signalingService?.clearIncomingFromUser(userId);

    add(InternalUpdateState());
  }

  Future<void> _onLeaveCall(LeaveCall event, Emitter<CallState> emit) async {
    for (final targetId in _peerConnections.keys.toList()) {
      await _signalingService?.sendBye(targetId);
    }
    await _signalingService?.clearSignal();
    await _cleanup();
    emit(CallInitial());
  }

  @override
  Future<void> close() async {
    await _cleanup();
    return super.close();
  }

  Future<void> _cleanup() async {
    _roomSubscription?.cancel();
    _signalingService?.dispose();
    _connecting.clear();

    for (var pc in _peerConnections.values) {
      pc.close();
    }
    _peerConnections.clear();

    for (var renderer in _remoteRenderers.values) {
      renderer.srcObject = null;
      renderer.dispose();
    }
    _remoteRenderers.clear();

    if (_localRenderer != null) {
      _localRenderer!.srcObject = null;
      _localRenderer!.dispose();
      _localRenderer = null;
    }

    await _webRTCManager.dispose();
  }

  void _onToggleMute(ToggleMute event, Emitter<CallState> emit) {
    if (state is CallConnected) {
      final s = state as CallConnected;
      _webRTCManager.toggleMute(!s.isMuted);
      emit(s.copyWith(isMuted: !s.isMuted));
    }
  }

  void _onToggleVideo(ToggleVideo event, Emitter<CallState> emit) {
    if (state is CallConnected) {
      final s = state as CallConnected;
      final newVideoState = !s.isVideoEnabled;

      _webRTCManager.toggleVideo(newVideoState);

      // Force refresh renderer to ensure UI updates if track was disabled
      if (_localRenderer != null) {
        _localRenderer!.srcObject = _webRTCManager.localStream;
      }

      // Sync state to Firebase
      if (_roomId != null && _userId != null) {
        roomRepository.updateUserMediaState(
          _roomId!,
          _userId!,
          isVideoEnabled: newVideoState,
          isAudioEnabled: !s.isMuted, // Assuming current mute state
        );
      }

      emit(s.copyWith(isVideoEnabled: newVideoState));
    }
  }

  void _onSwitchCamera(SwitchCamera event, Emitter<CallState> emit) {
    _webRTCManager.switchCamera();
  }
}
