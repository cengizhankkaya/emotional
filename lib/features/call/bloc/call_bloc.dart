import 'dart:async';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/call/bloc/call_state.dart';

import 'package:emotional/features/call/service/media_device_service.dart';
import 'package:emotional/features/call/service/webrtc_service.dart';
import 'package:emotional/features/room/repository/room_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:emotional/core/services/permission_service.dart';
import 'package:permission_handler/permission_handler.dart';

class CallBloc extends Bloc<CallEvent, CallState> {
  final RoomRepository roomRepository;

  final WebRTCService _callService;
  final MediaDeviceService _mediaDeviceService;

  // Active Connections
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  RTCVideoRenderer? _localRenderer;
  Map<String, String> _activeUsers = {};
  Map<String, bool> _userVideoStates = {};
  Map<String, bool> _userAudioStates = {};

  final Set<String> _connectionInitiated = {};

  StreamSubscription? _roomSubscription;

  String? _roomId;
  String? _userId;
  String? get userId => _userId;

  CallBloc({required this.roomRepository})
    : _callService = WebRTCService(),
      _mediaDeviceService = MediaDeviceService(),
      super(CallInitial()) {
    on<JoinCall>(_onJoinCall);
    on<LeaveCall>(_onLeaveCall);

    // Internal Events
    on<InternalUpdateState>(_onInternalUpdateState);
    on<InternalIncomingStream>(_onInternalIncomingStream);
    on<InternalStreamRemoved>(_onInternalStreamRemoved);

    // Signaling Events handled via WebRTCService callbacks now, but we kept IncomingOffer etc. in CallEvent
    // for compatibility if we were using streams. However, WebRTCService handles them internally via SignalingService
    // So we don't need to listen to them here anymore unless we proxy them.
    // Wait, WebRTCService encapsulates signaling completely. We don't need IncomingOffer handlers here!
    // But existing CallBloc had them. New design removes them from Bloc logic. Great.

    // Device & Quality Events
    on<ToggleMute>(_onToggleMute);
    on<ToggleVideo>(_onToggleVideo);
    on<SwitchCamera>(_onSwitchCamera);
    on<ChangeVideoInput>(_onChangeVideoInput);
    on<ChangeAudioInput>(_onChangeAudioInput);
    on<ChangeAudioOutput>(_onChangeAudioOutput);
    on<ChangeQuality>(_onChangeQuality);
    on<ChangeVideoSize>(_onChangeVideoSize);
  }

  Future<void> _onJoinCall(JoinCall event, Emitter<CallState> emit) async {
    emit(CallLoading());
    try {
      _roomId = event.roomId;
      _userId = event.userId;

      // 1. Check Permissions
      final permissionService = PermissionService();
      final permissions = await permissionService
          .requestCameraAndMicrophonePermissions();

      final cameraGranted = permissions[Permission.camera] ?? false;
      final microphoneGranted = permissions[Permission.microphone] ?? false;

      if (!cameraGranted || !microphoneGranted) {
        emit(CallError('Kamera ve mikrofon izinleri gerekli.'));
        return;
      }

      await _cleanup();

      // 2. Initialize Media Devices (Tracks ready and ENABLED by default)
      await _mediaDeviceService.initialize();
      await _mediaDeviceService.enableSpeakerphone(true);

      _mediaDeviceService.toggleVideo(false);
      _mediaDeviceService.toggleMute(false);

      // Update local stream in CallService too (so it can be added to PeerConnections)
      _callService.updateLocalStream(_mediaDeviceService.localStream);

      // 3. Setup Local Renderer
      _localRenderer = RTCVideoRenderer();
      await _localRenderer!.initialize();
      if (_mediaDeviceService.localStream != null) {
        _localRenderer!.srcObject = _mediaDeviceService.localStream!;
      }

      // 4. Setup Call Service Callbacks
      _callService.onRemoteStream = (stream, userId) {
        add(InternalIncomingStream(userId, stream));
      };

      _callService.onRemoteStreamRemoved = (userId) {
        add(InternalStreamRemoved(userId));
      };

      // 5. Join Room (Signaling)
      await _callService.joinRoom(_roomId!, _userId!);

      // 6. Setup Room Listeners (User Discovery)
      _setupRoomListeners();

      // 7. Initialize User Media State in Firebase (Start as ON)
      await roomRepository.updateUserMediaState(
        _roomId!,
        _userId!,
        isVideoEnabled: false,
        isAudioEnabled: true,
      );

      // 8. Get Initial Devices List
      final videoInputs = await _mediaDeviceService.getVideoInputs();
      final audioInputs = await _mediaDeviceService.getAudioInputs();
      final audioOutputs = await _mediaDeviceService.getAudioOutputs();

      emit(
        CallConnected(
          localRenderer: _localRenderer!,
          remoteRenderers: Map.from(_remoteRenderers),
          activeUsers: Map.from(_activeUsers),
          userVideoStates: Map.from(_userVideoStates),
          userAudioStates: Map.from(_userAudioStates),
          videoInputs: videoInputs,
          audioInputs: audioInputs,
          audioOutputs: audioOutputs,
          isVideoEnabled: false, // Default OFF
          isMuted: false, // Default OFF (not muted)
        ),
      );
    } catch (e) {
      emit(CallError('Failed to join call: $e'));
    }
  }

  void _setupRoomListeners() {
    if (_roomId == null || _userId == null) return;

    _roomSubscription = roomRepository.streamRoom(_roomId!).listen((event) {
      final snapshot = event.snapshot;
      if (snapshot.value == null) return;

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      if (!data.containsKey('users')) return;

      final users = Map<String, dynamic>.from(data['users'] as Map);
      final currentUserIds = users.keys.map((e) => e.toString()).toSet();

      // --- Re-entry Koruması ---
      // Eğer bir kullanıcı artık odada değilse, onunla olan 'bağlantı başlatıldı' işaretini kaldırıyoruz.
      // Ayrıca tüm yerel WebRTC nesnelerini ve sinyal verilerini temizliyoruz.

      // Odadan AYRILMIŞ olanları tespit et
      final currentlyActiveIds = _activeUsers.keys.toSet();
      final removedUserIds = currentlyActiveIds.difference(currentUserIds);

      for (final removedUid in removedUserIds) {
        print("[CallBloc] User $removedUid left, cleaning up artifacts.");
        _callService.forgetUser(
          removedUid,
        ); // PC kapat, sinyalleri sil, streamRemoved tetikle
        _connectionInitiated.remove(removedUid);
      }

      // Update active users map for UI
      _activeUsers = users.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );

      // Handle Users State (Video/Audio)
      if (data.containsKey('usersState')) {
        final states = Map<String, dynamic>.from(data['usersState'] as Map);
        _userVideoStates.clear();
        _userAudioStates.clear();
        states.forEach((uid, stateData) {
          final s = Map<String, dynamic>.from(stateData as Map);
          _userVideoStates[uid.toString()] = s['video'] as bool? ?? false;
          _userAudioStates[uid.toString()] = s['audio'] as bool? ?? false;
        });
      }

      // Connect to new users
      for (final otherUserId in currentUserIds) {
        if (otherUserId == _userId) continue;

        // "Initiator" rule: only the user with the alphabetically "smaller" ID initiates.
        // This is a simple way to prevent "Glare" where both try to call each other at the exact same time.
        if (_userId!.compareTo(otherUserId) < 0) {
          if (!_connectionInitiated.contains(otherUserId)) {
            print(
              "[CallBloc] I AM INITIATOR for $otherUserId. Initializing connection in 500ms...",
            );
            _connectionInitiated.add(otherUserId);
            // Give a small grace period for the other side to be ready for incoming signals
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_connectionInitiated.contains(otherUserId)) {
                _callService.connect(otherUserId);
              }
            });
          }
        } else {
          print(
            "[CallBloc] I AM CALLEE for $otherUserId. Waiting for offer...",
          );
        }
      }

      add(InternalUpdateState());
    });
  }

  // Actually, to make it professional, `WebRTCService` should probably expose `connect(userId)`.
  // But since I implemented `createPeerConnection` only, I'll use that.
  // Wait, I need to know WHEN to call.
  // In Mesh, usually the person joining calls everyone else.
  // The 'users' list in Firebase updates.
  // If I am the joiner, I see existing users. I call them.
  // If I am existing, I see new user. Do I call them? Or wait for them?
  // Convention: Joiner calls.
  // So when I first join, I iterate `users` and call them.
  // When a new user joins later, `users` updates.
  // If I am existing, I see new user. I should WAIT for them to call me?
  // Previous logic:
  // `_initiateCallTo` was called for every user in `currentUserIds` if not connected.
  // This implies bidirectional calling risk (Glare).
  // But `WebRTCManager` had Glare handling? No, it just created PC.
  // Let's stick to simplicity: Try to connect.
  // BUT I need to access `_peerConnections` to know if I have one?
  // WebRTCService hides it.
  // I will add `connectTo(userId)` to WebRTCService later or simply rely on Signaling to handle offers.
  // If I receive an offer, WebRTCService handles it.
  // I only need to send offer if I am the initiator.

  // Hack for now: I will assume `WebRTCService` handles incoming.
  // I will NOT initiate calls from Bloc in this refactor step unless I add `connectTo` to interface.
  // Wait, if I don't initiate, no one connects!
  // I MUST initiate.
  // I will update ICallService to have `connect(userId)` or perform logic here.
  // `_callService.createPeerConnection(id)` returns PC. I can check if it's new.

  // Unused method removed to fix lint

  void _onInternalUpdateState(
    InternalUpdateState event,
    Emitter<CallState> emit,
  ) {
    if (state is CallConnected) {
      emit(
        (state as CallConnected).copyWith(
          remoteRenderers: Map.from(_remoteRenderers),
          activeUsers: Map.from(_activeUsers),
          userVideoStates: Map.from(_userVideoStates),
          userAudioStates: Map.from(_userAudioStates),
        ),
      );
    }
  }

  Future<void> _onInternalIncomingStream(
    InternalIncomingStream event,
    Emitter<CallState> emit,
  ) async {
    print("[CallBloc] Incoming stream received from ${event.userId}");

    // Eski bir renderer varsa temizle (bellek sızıntısı ve çakışma önleme)
    final oldRenderer = _remoteRenderers.remove(event.userId);
    if (oldRenderer != null) {
      oldRenderer.srcObject = null;
      await oldRenderer.dispose();
    }

    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    renderer.srcObject = event.stream;
    _remoteRenderers[event.userId] = renderer;
    add(InternalUpdateState());
  }

  Future<void> _onInternalStreamRemoved(
    InternalStreamRemoved event,
    Emitter<CallState> emit,
  ) async {
    print("[CallBloc] Stream removed for user ${event.userId}");
    _connectionInitiated.remove(event.userId); // Allow reconnection
    final renderer = _remoteRenderers.remove(event.userId);
    if (renderer != null) {
      renderer.srcObject = null;
      await renderer.dispose();
    }
    add(InternalUpdateState());
  }

  Future<void> _onLeaveCall(LeaveCall event, Emitter<CallState> emit) async {
    await _cleanup();
    emit(CallInitial());
  }

  Future<void> _cleanup() async {
    _roomSubscription?.cancel();

    // Dispose Renderers
    if (_localRenderer != null) {
      _localRenderer!.srcObject = null;
      _localRenderer!.dispose();
      _localRenderer = null;
    }
    for (var r in _remoteRenderers.values) {
      r.srcObject = null;
      r.dispose();
    }
    _remoteRenderers.clear();
    _connectionInitiated.clear();
    _activeUsers.clear();
    _userVideoStates.clear();
    _userAudioStates.clear();

    await _callService.dispose();
    // We don't dispose mediaDeviceService fully if we want to preview?
    // Usually yes on leave.
    await _mediaDeviceService.dispose();
  }

  // Device & Quality Handlers

  void _onToggleMute(ToggleMute event, Emitter<CallState> emit) {
    if (state is CallConnected) {
      final s = state as CallConnected;
      _mediaDeviceService.toggleMute(!s.isMuted);
      emit(s.copyWith(isMuted: !s.isMuted));
      if (_roomId != null && userId != null) {
        _syncState(
          _roomId!,
          userId!,
          video: s.isVideoEnabled,
          audio: !s.isMuted,
        );
      }
    }
  }

  void _onToggleVideo(ToggleVideo event, Emitter<CallState> emit) {
    if (state is CallConnected) {
      final s = state as CallConnected;
      final newVideo = !s.isVideoEnabled;
      _mediaDeviceService.toggleVideo(newVideo);

      // Refresh local renderer if needed (State update usually handles UI, but stream track is same)
      emit(s.copyWith(isVideoEnabled: newVideo));
      _syncState(_roomId!, userId!, video: newVideo, audio: !s.isMuted);
    }
  }

  void _onSwitchCamera(SwitchCamera event, Emitter<CallState> emit) async {
    await _mediaDeviceService.switchCamera();
  }

  Future<void> _onChangeVideoInput(
    ChangeVideoInput event,
    Emitter<CallState> emit,
  ) async {
    await _mediaDeviceService.selectVideoInput(event.device);
    _callService.updateLocalStream(_mediaDeviceService.localStream);
    if (_localRenderer != null) {
      _localRenderer!.srcObject = _mediaDeviceService.localStream;
    }
    if (state is CallConnected) {
      emit(
        (state as CallConnected).copyWith(
          selectedVideoInputId: event.device.deviceId,
        ),
      );
    }
  }

  Future<void> _onChangeAudioInput(
    ChangeAudioInput event,
    Emitter<CallState> emit,
  ) async {
    await _mediaDeviceService.selectAudioInput(event.device);
    _callService.updateLocalStream(_mediaDeviceService.localStream);
    if (state is CallConnected) {
      emit(
        (state as CallConnected).copyWith(
          selectedAudioInputId: event.device.deviceId,
        ),
      );
    }
  }

  Future<void> _onChangeAudioOutput(
    ChangeAudioOutput event,
    Emitter<CallState> emit,
  ) async {
    await _mediaDeviceService.selectAudioOutput(event.device);
    if (state is CallConnected) {
      emit(
        (state as CallConnected).copyWith(
          selectedAudioOutputId: event.device.deviceId,
        ),
      );
    }
  }

  Future<void> _onChangeQuality(
    ChangeQuality event,
    Emitter<CallState> emit,
  ) async {
    await _mediaDeviceService.setQuality(event.preset);
    // Stream might have changed (restarted with new constraints)
    _callService.updateLocalStream(_mediaDeviceService.localStream);
    if (_localRenderer != null) {
      _localRenderer!.srcObject = _mediaDeviceService.localStream;
    }
    if (state is CallConnected) {
      emit((state as CallConnected).copyWith(currentQuality: event.preset));
    }
  }

  void _onChangeVideoSize(ChangeVideoSize event, Emitter<CallState> emit) {
    if (state is CallConnected) {
      final s = state as CallConnected;
      emit(s.copyWith(videoSize: event.size));
    }
  }

  Future<void> _syncState(
    String roomId,
    String userId, {
    required bool video,
    required bool audio,
  }) async {
    await roomRepository.updateUserMediaState(
      roomId,
      userId,
      isVideoEnabled: video,
      isAudioEnabled: audio,
    );
  }
}

// Extension to safely access roomId since it's private field in Bloc,
// or we just use _roomId field which is available in method scope.
