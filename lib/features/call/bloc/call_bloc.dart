import 'dart:async';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/call/service/signaling_service.dart';
import 'package:emotional/features/call/service/webrtc_manager.dart';
import 'package:emotional/features/room/repository/room_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CallBloc extends Bloc<CallEvent, CallState> {
  final RoomRepository roomRepository;

  SignalingService? _signalingService;
  final WebRTCManager _webRTCManager;

  // Active Connections
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  RTCVideoRenderer? _localRenderer;

  StreamSubscription? _roomSubscription;

  String? _roomId;
  String? _userId;

  CallBloc({required this.roomRepository})
    : _webRTCManager = WebRTCManager(),
      super(CallInitial()) {
    on<JoinCall>(_onJoinCall);
    on<LeaveCall>(_onLeaveCall);
    on<IncomingOffer>(_onIncomingOffer);
    on<IncomingAnswer>(_onIncomingAnswer);
    on<IncomingIceCandidate>(_onIncomingIceCandidate);
    on<ToggleMute>(_onToggleMute);
    on<ToggleVideo>(_onToggleVideo);
    on<SwitchCamera>(_onSwitchCamera);
    on<InternalUpdateState>((event, emit) {
      if (state is CallConnected) {
        emit(
          (state as CallConnected).copyWith(
            remoteRenderers: Map.from(_remoteRenderers),
          ),
        );
      }
    });
  }

  Future<void> _onJoinCall(JoinCall event, Emitter<CallState> emit) async {
    emit(CallLoading());
    try {
      _roomId = event.roomId;
      _userId = event.userId;

      await _cleanup(); // Safety cleanup

      // Setup Local Renderer first so it's ready for stream
      _localRenderer = RTCVideoRenderer();
      await _localRenderer!.initialize();

      _webRTCManager.onLocalStream = (stream) {
        _localRenderer!.srcObject = stream;
      };

      // Initialize WebRTC Manager (Get Local Stream)
      await _webRTCManager.initialize();

      // Initialize Signaling
      _signalingService = SignalingService(roomId: _roomId!, userId: _userId!);
      _signalingService!.initialize();

      _setupSignalingListeners();
      _setupRoomListeners(); // To discover users

      emit(
        CallConnected(
          localRenderer: _localRenderer!,
          remoteRenderers: const {},
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
  }

  void _setupRoomListeners() {
    if (_roomId == null) return;

    _roomSubscription = roomRepository.streamRoom(_roomId!).listen((event) {
      final snapshot = event.snapshot;
      if (snapshot.value == null) return;

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      if (data.containsKey('users')) {
        final users = Map<String, dynamic>.from(data['users'] as Map);

        users.forEach((otherUserId, _) {
          if (otherUserId == _userId) return;

          // If we are already connected or connecting, skip
          if (_peerConnections.containsKey(otherUserId)) return;

          // Determine if I should call
          if (_userId != null && _userId!.compareTo(otherUserId) > 0) {
            _initiateCallTo(otherUserId);
          }
        });
      }
    });
  }

  Future<void> _initiateCallTo(String targetUserId) async {
    final pc = await _webRTCManager.createPeerConnectionForUser(targetUserId);
    _peerConnections[targetUserId] = pc;

    _setupPeerConnectionListeners(pc, targetUserId);

    RTCSessionDescription offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    await _signalingService!.sendOffer(targetUserId, offer);
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
        add(InternalUpdateState());
      });
    };
  }

  Future<void> _onIncomingOffer(
    IncomingOffer event,
    Emitter<CallState> emit,
  ) async {
    final pc = await _webRTCManager.createPeerConnectionForUser(event.userId);
    _peerConnections[event.userId] = pc;
    _setupPeerConnectionListeners(pc, event.userId);

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

  Future<void> _onLeaveCall(LeaveCall event, Emitter<CallState> emit) async {
    await _cleanup();
    emit(CallInitial());
  }

  Future<void> _cleanup() async {
    _roomSubscription?.cancel();
    _signalingService?.dispose();

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

      emit(s.copyWith(isVideoEnabled: newVideoState));
    }
  }

  void _onSwitchCamera(SwitchCamera event, Emitter<CallState> emit) {
    _webRTCManager.switchCamera();
  }
}

class InternalUpdateState extends CallEvent {}
