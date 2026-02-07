import 'dart:async';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/call/bloc/call_state.dart';

import 'package:emotional/features/call/service/media_device_service.dart';
import 'package:emotional/features/call/service/webrtc_service.dart';
import 'package:emotional/features/call/service/audio_session_service.dart';
import 'package:emotional/features/room/domain/entities/room_entity.dart';
import 'package:emotional/features/room/domain/repositories/room_repository.dart'; // Use Interface
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:emotional/core/services/permission_service.dart';
import 'package:permission_handler/permission_handler.dart';

class CallBloc extends Bloc<CallEvent, CallState> {
  final RoomRepository roomRepository; // Interface

  final WebRTCService _callService;
  final MediaDeviceService _mediaDeviceService;
  final AudioSessionService _audioSessionService;

  // Active Connections
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  RTCVideoRenderer? _localRenderer;
  Map<String, String> _activeUsers = {};
  Map<String, bool> _userVideoStates = {};
  Map<String, bool> _userAudioStates = {};

  final Set<String> _connectionInitiated = {};

  StreamSubscription<RoomEntity?>? _roomSubscription;

  String? _roomId;
  String? _userId;
  String? get userId => _userId;

  CallBloc({required this.roomRepository})
    : _callService = WebRTCService(),
      _mediaDeviceService = MediaDeviceService(),
      _audioSessionService = AudioSessionService(),
      super(CallInitial()) {
    on<JoinCall>(_onJoinCall);
    on<LeaveCall>(_onLeaveCall);

    // Internal Events
    on<InternalUpdateState>(_onInternalUpdateState);
    on<InternalIncomingStream>(_onInternalIncomingStream);
    on<InternalStreamRemoved>(_onInternalStreamRemoved);

    // Device & Quality Events
    on<ToggleMute>(_onToggleMute);
    on<ToggleVideo>(_onToggleVideo);
    on<SwitchCamera>(_onSwitchCamera);
    on<ChangeVideoInput>(_onChangeVideoInput);
    on<ChangeAudioInput>(_onChangeAudioInput);
    on<ChangeAudioOutput>(_onChangeAudioOutput);
    on<ChangeQuality>(_onChangeQuality);
    on<ChangeVideoSize>(_onChangeVideoSize);
    on<InternalUpdateActiveSpeaker>(_onInternalUpdateActiveSpeaker);
    on<SuspendMedia>(_onSuspendMedia);
    on<ResumeMedia>(_onResumeMedia);
  }

  bool _isVideoEnabledBeforeSuspend = false;
  bool _isAudioEnabledBeforeSuspend = true;
  bool _isSuspended = false;
  bool _isCallActive = false;

  Future<void> _onJoinCall(JoinCall event, Emitter<CallState> emit) async {
    emit(CallLoading());
    try {
      _roomId = event.roomId;
      _userId = event.userId;

      if (_isSuspended) {
        print(
          '[CallBloc] JoinCall received but app is SUSPENDED. Initializing in BACKGROUND mode (No camera).',
        );
        emit(
          CallConnected(
            localRenderer: RTCVideoRenderer(), // Dummy or wait for resume
            remoteRenderers: const {},
            activeUsers: const {},
            userVideoStates: const {},
            userAudioStates: const {},
            videoInputs: const [],
            audioInputs: const [],
            audioOutputs: const [],
            isVideoEnabled: false,
            isMuted: true,
          ),
        );
        return;
      }

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

      // Initiate Audio Session (Focus & Routing)
      await _audioSessionService.activate();

      // 2. Initialize Media Devices (Tracks ready and ENABLED by default)
      await _mediaDeviceService.initialize();

      _mediaDeviceService.toggleVideo(false);
      _mediaDeviceService.toggleMute(false);

      // Update local stream in CallService too
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

      // 7. Initialize User Media State
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
          isVideoEnabled: false,
          isMuted: false,
        ),
      );
      _isCallActive = true;
      _startAudioLevelMonitor();
    } catch (e) {
      emit(CallError('Failed to join call: $e'));
    }
  }

  Timer? _audioMonitorTimer;

  void _startAudioLevelMonitor() {
    _audioMonitorTimer?.cancel();
    _audioMonitorTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) async {
      if (!_isCallActive) return;

      String? currentActiveSpeaker;
      double maxAudioLevel = 0.0;

      for (var userId in _activeUsers.keys) {
        if (userId == _userId) continue;
        final level = await _callService.getRemoteAudioLevel(userId);
        if (level > maxAudioLevel && level > 0.05) {
          // Threshold
          maxAudioLevel = level;
          currentActiveSpeaker = userId;
        }
      }

      final currentActiveSpeakerId = state is CallConnected
          ? (state as CallConnected).activeSpeakerId
          : null;

      if (currentActiveSpeaker != currentActiveSpeakerId) {
        add(InternalUpdateActiveSpeaker(currentActiveSpeaker));
      }
    });
  }

  void _setupRoomListeners() {
    if (_roomId == null || _userId == null) return;

    _roomSubscription = roomRepository.streamRoom(_roomId!).listen((
      roomEntity,
    ) {
      if (roomEntity == null) return;

      final users = roomEntity.users;
      final currentUserIds = users.keys.toSet();

      // Clean up users who left
      final currentlyActiveIds = _activeUsers.keys.toSet();
      final removedUserIds = currentlyActiveIds.difference(currentUserIds);

      for (final removedUid in removedUserIds) {
        print("[CallBloc] User $removedUid left, cleaning up artifacts.");
        _callService.forgetUser(removedUid);
        _connectionInitiated.remove(removedUid);
      }

      // Update active users map
      _activeUsers = Map.from(users);

      // Handle Users State (Video/Audio)
      _userVideoStates.clear();
      _userAudioStates.clear();
      roomEntity.usersState.forEach((uid, state) {
        _userVideoStates[uid] = state.isVideoEnabled;
        _userAudioStates[uid] = state.isAudioEnabled;
      });

      // Connect to new users
      for (final otherUserId in currentUserIds) {
        if (otherUserId == _userId) continue;

        if (_userId!.compareTo(otherUserId) < 0) {
          if (!_connectionInitiated.contains(otherUserId)) {
            print(
              "[CallBloc] I AM INITIATOR for $otherUserId. Initializing connection in 500ms...",
            );
            _connectionInitiated.add(otherUserId);
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_isCallActive && _connectionInitiated.contains(otherUserId)) {
                _callService.connect(otherUserId);
              }
            });
          }
        } else {
          // Callee waits
        }
      }

      add(InternalUpdateState());
    });
  }

  void _onInternalUpdateActiveSpeaker(
    InternalUpdateActiveSpeaker event,
    Emitter<CallState> emit,
  ) {
    if (state is CallConnected) {
      emit((state as CallConnected).copyWith(activeSpeakerId: event.speakerId));
    }
  }

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
    _connectionInitiated.remove(event.userId);
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
    _isCallActive = false;
    _audioMonitorTimer?.cancel();
    _roomSubscription?.cancel();

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
    await _mediaDeviceService.dispose();
    await _audioSessionService.deactivate();
  }

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

  Future<void> _onSuspendMedia(
    SuspendMedia event,
    Emitter<CallState> emit,
  ) async {
    if (state is CallConnected && !_isSuspended) {
      final s = state as CallConnected;
      _isVideoEnabledBeforeSuspend = s.isVideoEnabled;
      _isAudioEnabledBeforeSuspend = !s.isMuted;
      _isSuspended = true;

      print(
        'CallBloc: Suspending media (Physical Release). Video=$_isVideoEnabledBeforeSuspend, Audio=$_isAudioEnabledBeforeSuspend',
      );

      _localRenderer?.srcObject = null;
      await _mediaDeviceService.dispose();

      emit(s.copyWith(isVideoEnabled: false, isMuted: true));
    }
  }

  Future<void> _onResumeMedia(
    ResumeMedia event,
    Emitter<CallState> emit,
  ) async {
    if (state is CallConnected && _isSuspended) {
      final s = state as CallConnected;
      _isSuspended = false;

      print(
        'CallBloc: Resuming media (Physical Re-acquisition). Restoring: Video=$_isVideoEnabledBeforeSuspend, Audio=$_isAudioEnabledBeforeSuspend',
      );

      await _mediaDeviceService.initialize();

      _mediaDeviceService.toggleVideo(_isVideoEnabledBeforeSuspend);
      _mediaDeviceService.toggleMute(!_isAudioEnabledBeforeSuspend);

      final newStream = _mediaDeviceService.localStream;
      if (newStream != null) {
        _localRenderer?.srcObject = newStream;

        final videoTrack = newStream.getVideoTracks().firstOrNull;
        if (videoTrack != null) {
          await _callService.replaceLocalAllVideoTrack(videoTrack);
        }

        final audioTrack = newStream.getAudioTracks().firstOrNull;
        if (audioTrack != null) {
          await _callService.replaceLocalAllAudioTrack(audioTrack);
        }

        _callService.updateLocalStream(newStream);
      }

      emit(
        s.copyWith(
          isVideoEnabled: _isVideoEnabledBeforeSuspend,
          isMuted: !_isAudioEnabledBeforeSuspend,
        ),
      );

      if (_roomId != null && _userId != null) {
        _syncState(
          _roomId!,
          _userId!,
          video: _isVideoEnabledBeforeSuspend,
          audio: _isAudioEnabledBeforeSuspend,
        );
      }
    }
  }

  void _onToggleVideo(ToggleVideo event, Emitter<CallState> emit) {
    if (state is CallConnected) {
      final s = state as CallConnected;
      final newVideo = !s.isVideoEnabled;
      _mediaDeviceService.toggleVideo(newVideo);

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
