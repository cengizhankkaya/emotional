import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/call/domain/screen_share/screen_share_options.dart';
import 'package:emotional/features/call/domain/screen_share/outgoing_video_stats.dart';
import 'package:emotional/features/call/service/media_device_service.dart';
import 'package:emotional/features/call/service/screen_share/browser_screen_capture.dart';
import 'package:emotional/features/call/domain/client_platform.dart';
import 'package:emotional/features/call/service/device_changes/device_changes.dart';
import 'package:emotional/features/call/service/peer_reconciler.dart';
import 'package:emotional/features/call/service/webrtc_service.dart';
import 'package:emotional/features/call/service/audio_session_service.dart';
import 'package:emotional/features/room/domain/entities/room_entity.dart';
import 'package:emotional/features/room/domain/repositories/room_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:emotional/core/services/permission_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

const channel = MethodChannel('com.example.emotional/screen_share');

class CallBloc extends Bloc<CallEvent, CallState> {
  final RoomRepository roomRepository;

  final WebRTCService _callService;
  final MediaDeviceService _mediaDeviceService;
  final AudioSessionService _audioSessionService;

  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  RTCVideoRenderer? _localRenderer;
  Map<String, String> _activeUsers = {};
  final Map<String, bool> _userVideoStates = {};
  final Map<String, bool> _userAudioStates = {};
  final Map<String, bool> _userScreenSharingStates = {};
  final Map<String, ClientPlatform> _userPlatforms = {};

  // Camera next to a screen share: theirs (received) and yours (preview).
  final Map<String, RTCVideoRenderer> _shareCameraRenderers = {};
  final Map<String, bool> _userShareCameraStates = {};
  RTCVideoRenderer? _localShareCameraRenderer;
  bool _shareCameraOn = false;

  /// Debounce timers for "user left" detection.
  /// Firebase can emit a stale/partial snapshot when the network briefly
  /// drops and reconnects, making a user appear absent for one update cycle.
  /// We wait 1500ms before actually calling forgetUser — if the user
  /// reappears in a subsequent snapshot the timer is cancelled.
  final Map<String, Timer> _leaveDebounceTimers = {};

  /// Re-offers to peers that aren't connected (late joiners, rejoins, stuck
  /// connections); runs on each room update and on [_reconcileInterval].
  final PeerReconciler _peers = PeerReconciler();
  static const Duration _reconcileInterval = Duration(seconds: 3);
  Timer? _reconcileTimer;

  void Function()? _stopWatchingDevices;

  StreamSubscription<RoomEntity?>? _roomSubscription;

  String? _roomId;
  String? _userId;
  String? get userId => _userId;

  /// Incremented on every JoinCall — used to invalidate delayed callbacks
  /// from a previous session (e.g. Future.delayed connect, audio timer).
  int _sessionId = 0;

  MediaStream? _compositeStream;

  /// Constructor supports optional service injection for testability.
  /// In production, services are created internally.
  CallBloc({
    required this.roomRepository,
    WebRTCService? callService,
    MediaDeviceService? mediaDeviceService,
    AudioSessionService? audioSessionService,
  }) : _callService = callService ?? WebRTCService(),
       _mediaDeviceService = mediaDeviceService ?? MediaDeviceService(),
       _audioSessionService = audioSessionService ?? AudioSessionService(),
       super(const CallInitial()) {
    on<JoinCall>(_onJoinCall);
    on<LeaveCall>(_onLeaveCall);
    on<InternalUpdateState>(_onInternalUpdateState);
    on<InternalIncomingStream>(_onInternalIncomingStream);
    on<InternalStreamRemoved>(_onInternalStreamRemoved);
    on<InternalShareCameraStream>(_onShareCameraStream);
    on<ToggleMute>(_onToggleMute);
    on<ToggleVideo>(_onToggleVideo);
    on<ToggleScreenShare>(_onToggleScreenShare);
    on<ScreenShareEnded>(_onScreenShareEnded);
    on<SwitchCamera>(_onSwitchCamera);
    on<ChangeVideoInput>(_onChangeVideoInput);
    on<ChangeAudioInput>(_onChangeAudioInput);
    on<ChangeAudioOutput>(_onChangeAudioOutput);
    on<ChangeQuality>(_onChangeQuality);
    on<ChangeVideoSize>(_onChangeVideoSize);
    on<InternalUpdateActiveSpeaker>(_onInternalUpdateActiveSpeaker);
    on<InternalMicrophoneLost>(_onMicrophoneLost);
    on<InternalCameraLost>(_onCameraLost);
    on<InternalDevicesChanged>(_onDevicesChanged);
    on<SuspendMedia>(_onSuspendMedia);
    on<ResumeMedia>(_onResumeMedia);
  }

  bool _isVideoEnabledBeforeSuspend = false;
  bool _isAudioEnabledBeforeSuspend = true;
  bool _isSuspended = false;
  bool _isCallActive = false;
  bool _isRequestingScreenShare = false;
  bool _isVideoEnabledBeforeScreenShare = false;

  // ─── JoinCall ─────────────────────────────────────────────────────────────

  Future<void> _onJoinCall(JoinCall event, Emitter<CallState> emit) async {
    emit(const CallLoading());
    try {
      _sessionId++;
      _roomId = event.roomId;
      _userId = event.userId;

      _peers.reset();
      _activeUsers.clear();
      _remoteRenderers.clear();

      if (_isSuspended) {
        debugPrint('[CallBloc] JoinCall while SUSPENDED — background mode.');
        emit(
          CallConnected(
            localRenderer: RTCVideoRenderer(),
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

      final permissionService = PermissionService();
      await permissionService.requestNotificationPermission();

      // The camera is optional: it's only asked for when turned on.
      final microphoneGranted = await permissionService
          .requestMicrophonePermission();

      if (!microphoneGranted) {
        emit(CallError(LocaleKeys.call_error_permissionRequired.tr()));
        return;
      }

      // _cleanup() calls deactivate() internally. We must wait for the OS
      // to fully release the audio session before re-acquiring it, otherwise
      // Android fires a spurious Audio Session Interrupted event.
      await _cleanup();

      // FIX: Give the OS a moment to settle after deactivate() before we
      // call getUserMedia + activate(). Without this delay Android reports
      // an audio session interruption mid-stream-open, which shows up in
      // logs as the double "Audio Session Interrupted (Pause/Unknown)" seen
      // immediately after AudioSession Activated.
      if ((!kIsWeb && Platform.isAndroid)) {
        await Future.delayed(const Duration(milliseconds: 300));
      }

      try {
        await WakelockPlus.enable().timeout(_optionalServiceTimeout);
      } catch (e) {
        debugPrint('CallBloc: Failed to enable wakelock: $e');
      }

      // FIX: Initialize media (getUserMedia) BEFORE activating the audio
      // session. On Android, getUserMedia itself temporarily interrupts the
      // audio focus. If activate() runs first, the OS sees:
      //   activate → getUserMedia interrupt → resume
      // which is the double-interrupt pattern visible in the log.
      // Correct order:
      //   getUserMedia → activate (session takes ownership cleanly)
      _mediaDeviceService.onMicrophoneLost = () {
        if (!isClosed) add(const InternalMicrophoneLost());
      };
      _mediaDeviceService.onCameraLost = () {
        if (!isClosed) add(const InternalCameraLost());
      };
      _stopWatchingDevices?.call();
      _stopWatchingDevices = listenForDeviceChanges(() {
        if (!isClosed) add(const InternalDevicesChanged());
      });

      // Microphone only: the camera (and its light) stays off until the
      // user turns it on.
      await _mediaDeviceService.initialize(enableVideo: false);
      _mediaDeviceService.toggleMute(false);

      // Activate AFTER getUserMedia so the session takes ownership of an
      // already-open mic/camera without a mid-acquisition interrupt.
      await _activateAudioSession();

      _callService.updateLocalStream(_mediaDeviceService.localStream);

      _localRenderer = RTCVideoRenderer();
      await _localRenderer!.initialize();
      if (_mediaDeviceService.localStream != null) {
        _localRenderer!.srcObject = _mediaDeviceService.localStream!;
      }

      // Guard isClosed before adding internal events
      _callService.onRemoteStream = (stream, userId) {
        if (!isClosed) add(InternalIncomingStream(userId, stream));
      };
      _callService.onRemoteStreamRemoved = (userId) {
        if (!isClosed) add(InternalStreamRemoved(userId));
      };
      _callService.onRemoteShareCamera = (stream, userId) {
        if (!isClosed) add(InternalShareCameraStream(userId, stream));
      };
      _callService.onRemoteBye = (userId) {
        if (isClosed) return;
        debugPrint('[CallBloc] $userId left the call.');
        _peers.peerLeftCall(userId);
      };

      final roomEntity = await roomRepository.getRoom(_roomId!);
      final isHost = roomEntity?.hostId == _userId;
      await _callService.joinRoom(_roomId!, _userId!, isHost: isHost);

      if ((!kIsWeb && Platform.isAndroid)) {
        try {
          await channel.invokeMethod('startVoiceService');
        } catch (e) {
          debugPrint('CallBloc: Failed to start startVoiceService: $e');
        }
      }

      _setupRoomListeners();
      _reconcileTimer?.cancel();
      _reconcileTimer = Timer.periodic(
        _reconcileInterval,
        (_) => _reconcileConnections(),
      );

      await roomRepository.updateUserMediaState(
        _roomId!,
        _userId!,
        isVideoEnabled: false,
        isAudioEnabled: true,
        isScreenSharing: false,
        // Lets the others tell a wide laptop camera from a tall phone one.
        platform: ClientPlatform.current.name,
        acceptsShareCamera: true,
      );

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
          selectedVideoInputId: _mediaDeviceService.selectedVideoDeviceId,
          selectedAudioInputId: _mediaDeviceService.selectedAudioDeviceId,
          selectedAudioOutputId: _mediaDeviceService.selectedAudioOutputId,
          isVideoEnabled: false,
          isMuted: false,
        ),
      );
      _isCallActive = true;
      _reconcileConnections();
      _startAudioLevelMonitor();
    } catch (e, stack) {
      debugPrint('[CallBloc] Joining the call failed: $e\n$stack');
      emit(
        CallError(LocaleKeys.call_error_joinFailed.tr(args: [e.toString()])),
      );
    }
  }

  // ─── Audio level monitor ──────────────────────────────────────────────────

  Timer? _audioMonitorTimer;

  void _startAudioLevelMonitor() {
    // Capture session so the timer self-cancels if a new session starts
    final sessionId = _sessionId;
    _audioMonitorTimer?.cancel();
    _audioMonitorTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) async {
      if (!_isCallActive || _sessionId != sessionId) {
        timer.cancel();
        return;
      }

      String? currentActiveSpeaker;
      double maxAudioLevel = 0.0;

      for (final userId in _activeUsers.keys) {
        if (userId == _userId) continue;
        if (_userAudioStates[userId] == false) continue;

        final level = await _callService.getRemoteAudioLevel(userId);
        if (level > 0) debugPrint("[CallBloc] Audio level for $userId: $level");
        if (level > maxAudioLevel && level > 0.01) {
          maxAudioLevel = level;
          currentActiveSpeaker = userId;
        }
      }

      if (_userId != null && state is CallConnected) {
        final s = state as CallConnected;
        if (!s.isMuted) {
          final localLevel = await _callService.getLocalAudioLevel();
          if (localLevel > 0) {
            debugPrint("[CallBloc] Local audio level: $localLevel");
          }
          if (localLevel > maxAudioLevel && localLevel > 0.01) {
            maxAudioLevel = localLevel;
            currentActiveSpeaker = _userId;
          }
        }
      }

      final currentActiveSpeakerId = state is CallConnected
          ? (state as CallConnected).activeSpeakerId
          : null;

      if (currentActiveSpeaker != currentActiveSpeakerId) {
        debugPrint(
          "[CallBloc] Active speaker changed: $currentActiveSpeaker (level: $maxAudioLevel)",
        );
        if (!isClosed) add(InternalUpdateActiveSpeaker(currentActiveSpeaker));
      }
    });
  }

  // ─── Room listeners ───────────────────────────────────────────────────────

  void _setupRoomListeners() {
    // FIX: cancel any existing subscription before creating a new one.
    // Without this, a rapid rejoin would leave the old Firebase listener
    // alive and fire duplicate InternalUpdateState events.
    _roomSubscription?.cancel();
    if (_roomId == null || _userId == null) return;

    _roomSubscription = roomRepository.streamRoom(_roomId!).listen((
      roomEntity,
    ) {
      if (roomEntity == null) return;

      // FIX: Update host status dynamically on every room update.
      // If a host-transfer happens (or the original host leaves and rejoins),
      // _isHost must reflect the current truth so glare-resolution stays
      // correct. We push the updated value into WebRTCService so the
      // impolite/polite roles remain accurate without needing a full rejoin.
      final isNowHost = roomEntity.hostId == _userId;
      _callService.updateHostStatus(isNowHost);

      final users = roomEntity.users;
      final currentUserIds = users.keys.toSet();

      // ── Users who disappeared from this snapshot ──────────────────────────
      final missingUserIds = _activeUsers.keys.toSet().difference(
        currentUserIds,
      );

      for (final missingUid in missingUserIds) {
        // FIX: Debounce "user left" by 1500ms before acting on it.
        // Firebase emits a stale/partial snapshot when the network briefly
        // drops and reconnects — causing a user to appear absent for exactly
        // one update cycle even though they never left. Without this guard,
        // we call forgetUser() and close the PC mid-handshake, which is the
        // root cause of the WiFi↔mobile connection failure:
        //   offer sent → ICE gathered → Firebase stale snapshot → "User left"
        //   → forgetUser → PC closed → guest's answer arrives, no PC → fail.
        if (!_leaveDebounceTimers.containsKey(missingUid)) {
          debugPrint(
            "[CallBloc] User $missingUid absent from snapshot — debouncing 1500ms.",
          );
          final sessionId = _sessionId;
          _leaveDebounceTimers[missingUid] = Timer(
            const Duration(milliseconds: 1500),
            () {
              _leaveDebounceTimers.remove(missingUid);
              // Only act if the user is still absent AND we're in the same session
              if (!_isCallActive || _sessionId != sessionId) return;
              if (_activeUsers.containsKey(missingUid)) return; // came back
              debugPrint(
                "[CallBloc] User $missingUid confirmed left after debounce.",
              );
              // Clean slate for when they come back.
              _peers.forget(missingUid);
              _callService.forgetUser(missingUid);
              if (!isClosed) add(InternalUpdateState());
            },
          );
        }
      }

      // ── Users who came back (cancel pending leave timer) ──────────────────
      for (final uid in currentUserIds) {
        final timer = _leaveDebounceTimers.remove(uid);
        if (timer != null) {
          debugPrint(
            "[CallBloc] User $uid reappeared — cancelling leave debounce.",
          );
          timer.cancel();
        }
      }

      _activeUsers = Map.from(users);

      _userVideoStates.clear();
      _userAudioStates.clear();
      _userScreenSharingStates.clear();
      _userPlatforms.clear();
      _userShareCameraStates.clear();
      roomEntity.usersState.forEach((uid, state) {
        _userVideoStates[uid] = state.isVideoEnabled;
        _userAudioStates[uid] = state.isAudioEnabled;
        _userScreenSharingStates[uid] = state.isScreenSharing;
        final platform = ClientPlatform.fromName(state.platform);
        if (platform != null) _userPlatforms[uid] = platform;
        _userShareCameraStates[uid] = state.isShareCameraOn;
        if (uid != _userId) _peers.trackPeerState(uid, state.lastUpdatedAt);
      });

      _reconcileConnections();
      unawaited(
        _callService.setShareCameraPeers({
          for (final MapEntry(key: uid, value: state)
              in roomEntity.usersState.entries)
            if (uid != _userId && state.acceptsShareCamera) uid,
        }),
      );

      if (!isClosed) add(InternalUpdateState());
    });
  }

  // ─── Connection upkeep ────────────────────────────────────────────────────

  void _reconcileConnections() {
    final me = _userId;
    if (!_isCallActive || _isSuspended || me == null) return;
    final offers = _peers.peersToOffer(
      me: me,
      roomUsers: _activeUsers.keys,
      statusOf: _callService.peerStatus,
      isLeaving: _callService.isUserPendingBye,
    );
    for (final uid in offers) {
      debugPrint(
        '[CallBloc] Not connected to $uid; offering, '
        'attempt ${_peers.attemptsFor(uid)}.',
      );
      _callService.connect(uid);
    }
  }

  // ─── Internal event handlers ──────────────────────────────────────────────

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
          userScreenSharingStates: Map.from(_userScreenSharingStates),
          userPlatforms: Map.from(_userPlatforms),
          shareCameraRenderers: Map.from(_shareCameraRenderers),
          userShareCameraStates: Map.from(_userShareCameraStates),
        ),
      );
    }
  }

  Future<void> _onInternalIncomingStream(
    InternalIncomingStream event,
    Emitter<CallState> emit,
  ) async {
    debugPrint("[CallBloc] Incoming stream from ${event.userId}.");

    final oldRenderer = _remoteRenderers.remove(event.userId);
    if (oldRenderer != null) {
      oldRenderer.srcObject = null;
      await oldRenderer.dispose();
    }

    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    renderer.srcObject = event.stream;
    final s = state;
    if (kIsWeb && s is CallConnected && s.selectedAudioOutputId != null) {
      await renderer.audioOutput(s.selectedAudioOutputId!);
    }
    _remoteRenderers[event.userId] = renderer;
    if (!isClosed) add(InternalUpdateState());
  }

  Future<void> _onShareCameraStream(
    InternalShareCameraStream event,
    Emitter<CallState> emit,
  ) async {
    final old = _shareCameraRenderers.remove(event.userId);
    if (old != null) {
      old.srcObject = null;
      await old.dispose();
    }
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    renderer.srcObject = event.stream;
    _shareCameraRenderers[event.userId] = renderer;
    if (!isClosed) add(InternalUpdateState());
  }

  /// Shows [camera] to you next to your share and sends it to everyone
  /// whose app can show it.
  Future<void> _startShareCamera(MediaStreamTrack camera) async {
    _shareCameraOn = true;
    await _callService.setShareCamera(camera);
    final old = _localShareCameraRenderer;
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    renderer.srcObject = _mediaDeviceService.localStream;
    _localShareCameraRenderer = renderer;
    if (old != null) {
      old.srcObject = null;
      await old.dispose();
    }
  }

  Future<void> _stopShareCamera() async {
    _shareCameraOn = false;
    await _callService.setShareCamera(null);
    final renderer = _localShareCameraRenderer;
    _localShareCameraRenderer = null;
    if (renderer != null) {
      renderer.srcObject = null;
      await renderer.dispose();
    }
  }

  Future<void> _onInternalStreamRemoved(
    InternalStreamRemoved event,
    Emitter<CallState> emit,
  ) async {
    // FIX: Both _handleRemoteBye and forgetUser call onRemoteStreamRemoved,
    // which adds InternalStreamRemoved. This means the event can arrive twice
    // for the same user (once from bye, once from room-update → forgetUser).
    // The second call is a no-op for the renderer (already removed) — skip.
    final shareCamera = _shareCameraRenderers.remove(event.userId);
    if (shareCamera != null) {
      shareCamera.srcObject = null;
      await shareCamera.dispose();
    }
    final renderer = _remoteRenderers.remove(event.userId);
    if (renderer == null) {
      if (shareCamera != null && !isClosed) add(InternalUpdateState());
      return;
    }

    debugPrint("[CallBloc] Stream removed for ${event.userId}.");

    // The connection itself is already closed (bye or forgetUser);
    // _reconcileConnections() reconnects if the peer is still in the call.
    renderer.srcObject = null;
    await renderer.dispose();
    if (!isClosed) add(InternalUpdateState());
  }

  // ─── Leave & cleanup ──────────────────────────────────────────────────────

  Future<void> _onLeaveCall(LeaveCall event, Emitter<CallState> emit) async {
    await _cleanup();
    emit(const CallInitial());
  }

  Future<void> _cleanup() async {
    if ((!kIsWeb && Platform.isAndroid)) {
      try {
        await channel.invokeMethod('stopVoiceService');
      } catch (e) {
        debugPrint('CallBloc: Failed to stop stopVoiceService: $e');
      }
    }

    // Reset all flags immediately so no in-flight callbacks can act on
    // stale state while the async teardown below is running.
    _isCallActive = false;
    _isSuspended = false;
    _isRequestingScreenShare = false;
    _isVideoEnabledBeforeScreenShare = false;
    _isVideoEnabledBeforeSuspend = false;
    _isAudioEnabledBeforeSuspend = true;

    _audioMonitorTimer?.cancel();
    _audioMonitorTimer = null;
    _roomSubscription?.cancel();
    _roomSubscription = null;

    // Cancel all debounce and offer-timeout timers so no stale callbacks
    // fire into the new session after cleanup.
    for (final t in _leaveDebounceTimers.values) {
      t.cancel();
    }
    _leaveDebounceTimers.clear();
    _reconcileTimer?.cancel();
    _reconcileTimer = null;
    _peers.reset();
    _stopWatchingDevices?.call();
    _stopWatchingDevices = null;
    _mediaDeviceService.onMicrophoneLost = null;
    _mediaDeviceService.onCameraLost = null;

    // Brief wait for any in-flight async timer tick to finish before
    // we dispose the services it may still be calling into.
    await Future.delayed(const Duration(milliseconds: 100));

    if (_localRenderer != null) {
      _localRenderer!.srcObject = null;
      _localRenderer!.dispose();
      _localRenderer = null;
    }

    try {
      await WakelockPlus.disable().timeout(_optionalServiceTimeout);
    } catch (e) {
      debugPrint('CallBloc: Failed to disable wakelock: $e');
    }

    for (final r in _remoteRenderers.values) {
      r.srcObject = null;
      r.dispose();
    }
    _remoteRenderers.clear();
    for (final r in _shareCameraRenderers.values) {
      r.srcObject = null;
      r.dispose();
    }
    _shareCameraRenderers.clear();
    _userShareCameraStates.clear();
    _shareCameraOn = false;
    _localShareCameraRenderer?.dispose();
    _localShareCameraRenderer = null;
    _activeUsers.clear();
    _userVideoStates.clear();
    _userAudioStates.clear();
    _userScreenSharingStates.clear();
    _userPlatforms.clear();

    // FIX: Dispose media streams BEFORE deactivating the audio session.
    // If deactivate() runs first, the OS sees the mic/camera being released
    // without an active session owner, which triggers a spurious interruption
    // event on the next activate() call. Correct teardown order:
    //   callService.dispose → mediaDevice.dispose → compositeStream.dispose
    //   → audioSession.deactivate  (session released last, cleanly)
    await _callService.dispose();
    await _screenAudioMixer.dispose();
    await _mediaDeviceService.dispose();
    await _compositeStream?.dispose();
    _compositeStream = null;

    // Deactivate last so the OS sees a clean handoff.
    try {
      await _audioSessionService.deactivate().timeout(_optionalServiceTimeout);
    } catch (e) {
      debugPrint('CallBloc: Audio session did not deactivate: $e');
    }
  }

  /// Wakelock and the audio session only refine a call; one that never
  /// answers (missing plugin, stuck OS service) must not keep the call from
  /// starting or ending.
  static const Duration _optionalServiceTimeout = Duration(seconds: 3);

  Future<void> _activateAudioSession() async {
    try {
      await _audioSessionService.activate().timeout(_optionalServiceTimeout);
    } catch (e) {
      debugPrint('CallBloc: Audio session did not activate: $e');
    }
  }

  // ─── Media controls ───────────────────────────────────────────────────────

  void _onToggleMute(ToggleMute event, Emitter<CallState> emit) {
    if (state is! CallConnected || _isRequestingScreenShare) return;
    final s = state as CallConnected;
    final newMuted = !s.isMuted;

    try {
      _mediaDeviceService.toggleMute(newMuted);
      emit(s.copyWith(isMuted: newMuted));
      if (_roomId != null && userId != null) {
        _syncState(
          _roomId!,
          userId!,
          video: s.isVideoEnabled,
          audio: !newMuted,
          screen: s.isScreenSharing,
        );
      }
    } catch (e) {
      debugPrint("[CallBloc] Error toggling mute: $e");
    }
  }

  Future<void> _onToggleVideo(
    ToggleVideo event,
    Emitter<CallState> emit,
  ) async {
    if (state is! CallConnected) return;
    final s = state as CallConnected;

    if (s.isScreenSharing) {
      // The screen keeps the main video (and isVideoEnabled, see
      // CallConnected.cameraAfterShare); the camera goes next to it.
      final turnOn = !_isVideoEnabledBeforeScreenShare;
      if (turnOn) {
        if (!kIsWeb && !await PermissionService().requestCameraPermission()) {
          _reportMediaIssue(MediaIssue.cameraPermissionDenied, emit);
          return;
        }
        final camera = await _mediaDeviceService.startCamera();
        if (camera == null) {
          _reportMediaIssue(MediaIssue.cameraUnavailable, emit);
          return;
        }
        await _startShareCamera(camera);
      } else {
        await _stopShareCamera();
        await _mediaDeviceService.stopCamera();
      }
      _isVideoEnabledBeforeScreenShare = turnOn;
      final current = state;
      if (current is! CallConnected) return;
      emit(
        current.copyWith(
          cameraAfterShare: turnOn,
          localShareCameraRenderer: _localShareCameraRenderer,
        ),
      );
      if (_roomId != null && userId != null) {
        _syncState(
          _roomId!,
          userId!,
          video: current.isVideoEnabled,
          audio: !current.isMuted,
          screen: current.isScreenSharing,
        );
      }
      return;
    }

    final newVideoState = !s.isVideoEnabled;
    if (newVideoState) {
      if (!kIsWeb && !await PermissionService().requestCameraPermission()) {
        debugPrint('[CallBloc] Camera permission denied.');
        _reportMediaIssue(MediaIssue.cameraPermissionDenied, emit);
        return;
      }
      final camera = await _mediaDeviceService.startCamera();
      if (camera == null) {
        debugPrint('[CallBloc] No camera could be opened.');
        _reportMediaIssue(MediaIssue.cameraUnavailable, emit);
        return;
      }
      if (state is! CallConnected) return;
      _callService.updateLocalStream(_mediaDeviceService.localStream);
      _localRenderer?.srcObject = _mediaDeviceService.localStream;
      await _callService.replaceLocalAllVideoTrack(camera);
    } else {
      await _mediaDeviceService.stopCamera();
      await _callService.removeLocalVideoTrack();
      _localRenderer?.srcObject = _mediaDeviceService.localStream;
    }

    // Peers may have come or gone while the camera was opening.
    final current = state;
    if (current is! CallConnected) return;
    emit(current.copyWith(isVideoEnabled: newVideoState));
    if (_roomId != null && userId != null) {
      _syncState(
        _roomId!,
        userId!,
        video: newVideoState,
        audio: !current.isMuted,
        screen: current.isScreenSharing,
      );
    }
  }

  void _reportMediaIssue(MediaIssue issue, Emitter<CallState> emit) {
    final current = state;
    if (current is! CallConnected) return;
    emit(
      current.copyWith(
        mediaIssue: issue,
        mediaIssueCount: current.mediaIssueCount + 1,
      ),
    );
  }

  // ─── Device loss ──────────────────────────────────────────────────────────

  /// The microphone went away mid-call: move to the default one so peers
  /// don't silently hear nothing.
  Future<void> _onMicrophoneLost(
    InternalMicrophoneLost event,
    Emitter<CallState> emit,
  ) async {
    if (state is! CallConnected) return;
    final microphone = await _mediaDeviceService.restartMicrophone();
    if (state is! CallConnected) return;
    if (microphone == null) {
      _reportMediaIssue(MediaIssue.microphoneLost, emit);
      return;
    }
    // Keeps mute, the camera and an active share (incl. its audio mix).
    await _republishCameraStream();
    final current = state;
    if (current is! CallConnected) return;
    emit(
      current.copyWith(
        selectedAudioInputId: _mediaDeviceService.selectedAudioDeviceId,
        audioInputs: await _mediaDeviceService.getAudioInputs(),
        mediaIssue: MediaIssue.microphoneSwitched,
        mediaIssueCount: current.mediaIssueCount + 1,
      ),
    );
  }

  /// The camera went away mid-call: turn video off rather than send a
  /// frozen picture.
  Future<void> _onCameraLost(
    InternalCameraLost event,
    Emitter<CallState> emit,
  ) async {
    final s = state;
    if (s is! CallConnected) return;
    await _mediaDeviceService.stopCamera();
    if (s.isScreenSharing) {
      _isVideoEnabledBeforeScreenShare = false;
      await _stopShareCamera();
      emit(s.copyWith(cameraAfterShare: false, localShareCameraRenderer: null));
    } else {
      await _callService.removeLocalVideoTrack();
      _localRenderer?.srcObject = _mediaDeviceService.localStream;
    }
    final current = state;
    if (current is! CallConnected) return;
    emit(
      current.copyWith(
        isVideoEnabled: current.isScreenSharing ? null : false,
        videoInputs: await _mediaDeviceService.getVideoInputs(),
        mediaIssue: MediaIssue.cameraLost,
        mediaIssueCount: current.mediaIssueCount + 1,
      ),
    );
    if (_roomId != null && userId != null) {
      _syncState(
        _roomId!,
        userId!,
        video: current.isScreenSharing,
        audio: !current.isMuted,
        screen: current.isScreenSharing,
      );
    }
  }

  Future<void> _onDevicesChanged(
    InternalDevicesChanged event,
    Emitter<CallState> emit,
  ) async {
    if (state is! CallConnected) return;
    final videoInputs = await _mediaDeviceService.getVideoInputs();
    final audioInputs = await _mediaDeviceService.getAudioInputs();
    final audioOutputs = await _mediaDeviceService.getAudioOutputs();
    final current = state;
    if (current is! CallConnected) return;
    emit(
      current.copyWith(
        videoInputs: videoInputs,
        audioInputs: audioInputs,
        audioOutputs: audioOutputs,
      ),
    );
  }

  // ─── Suspend / Resume ─────────────────────────────────────────────────────

  Future<void> _onSuspendMedia(
    SuspendMedia event,
    Emitter<CallState> emit,
  ) async {
    if (state is! CallConnected || _isSuspended) return;
    final s = state as CallConnected;

    if (s.isScreenSharing || _isRequestingScreenShare) {
      debugPrint('CallBloc: SuspendMedia ignored — screen share active.');
      return;
    }

    _isVideoEnabledBeforeSuspend = s.isVideoEnabled;
    _isAudioEnabledBeforeSuspend = !s.isMuted;
    _isSuspended = true;

    _localRenderer?.srcObject = null;
    await _mediaDeviceService.dispose();
    emit(s.copyWith(isVideoEnabled: false, isMuted: true));
  }

  Future<void> _onResumeMedia(
    ResumeMedia event,
    Emitter<CallState> emit,
  ) async {
    if (state is! CallConnected || !_isSuspended) return;
    final s = state as CallConnected;
    _isSuspended = false;

    await _mediaDeviceService.initialize(
      enableVideo: _isVideoEnabledBeforeSuspend,
    );
    _mediaDeviceService.toggleMute(!_isAudioEnabledBeforeSuspend);

    final newStream = _mediaDeviceService.localStream;
    if (newStream != null) {
      _localRenderer?.srcObject = newStream;

      final videoTrack = newStream.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        await _callService.replaceLocalAllVideoTrack(videoTrack);
      } else {
        // Camera off: don't leave peers on the share or a stopped camera.
        await _callService.removeLocalVideoTrack();
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
        screen: s.isScreenSharing,
      );
    }
  }

  // ─── Screen share ─────────────────────────────────────────────────────────

  /// Web only: mixes the shared tab's audio into the outgoing microphone
  /// track while a share with audio is live.
  final ScreenAudioMixer _screenAudioMixer = ScreenAudioMixer();

  Future<void> _onScreenShareEnded(
    ScreenShareEnded event,
    Emitter<CallState> emit,
  ) async {
    final s = state;
    if (s is! CallConnected || !s.isScreenSharing) return;
    debugPrint('[CallBloc] Screen share ended by the browser.');
    await _onToggleScreenShare(const ToggleScreenShare(), emit);
  }

  Future<void> _onToggleScreenShare(
    ToggleScreenShare event,
    Emitter<CallState> emit,
  ) async {
    if (state is! CallConnected) return;
    final s = state as CallConnected;

    if (_isRequestingScreenShare) {
      debugPrint('[CallBloc] ToggleScreenShare ignored — already processing.');
      return;
    }

    final sessionId = _sessionId;
    _isRequestingScreenShare = true;

    try {
      if (s.isScreenSharing) {
        await _stopScreenShare(s, emit, sessionId);
      } else {
        await _startScreenShare(s, emit, sessionId, event.options);
      }
    } catch (e) {
      debugPrint('[CallBloc] Error toggling screen share: $e');
    } finally {
      _isRequestingScreenShare = false;
    }
  }

  Future<void> _stopScreenShare(
    CallConnected s,
    Emitter<CallState> emit,
    int sessionId,
  ) async {
    final shouldRestoreCamera = _isVideoEnabledBeforeScreenShare;
    // The camera moves back to the main video below.
    await _stopShareCamera();

    if (_localRenderer != null) {
      _localRenderer!.srcObject = null;
      await Future.delayed(const Duration(milliseconds: 100));
    }

    await _mediaDeviceService.stopScreenShare();
    if (kIsWeb) {
      await _screenAudioMixer.dispose();
      await _callService.setVideoSenderLimits();
    }

    if ((!kIsWeb && Platform.isAndroid)) {
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!_isCallActive || _sessionId != sessionId) return;
        await channel.invokeMethod('stopService');
        await channel.invokeMethod('startVoiceService');
      } catch (e) {
        debugPrint("[CallBloc] Failed to stop Android FGS: $e");
      }
    }

    await _mediaDeviceService.initialize(enableVideo: shouldRestoreCamera);
    await _compositeStream?.dispose();
    _compositeStream = null;

    _callService.updateLocalStream(_mediaDeviceService.localStream);
    if (shouldRestoreCamera) _mediaDeviceService.toggleVideo(true);
    // initialize() opens a fresh microphone; keep the user's mute choice.
    _mediaDeviceService.toggleMute(s.isMuted);
    if (_localRenderer != null) {
      _localRenderer!.srcObject = _mediaDeviceService.localStream;
    }

    final localStream = _mediaDeviceService.localStream;
    final videoTrack = localStream?.getVideoTracks().firstOrNull;
    if (videoTrack != null) {
      await _callService.replaceLocalAllVideoTrack(videoTrack);
    } else {
      // Camera off: don't leave peers on the share or a stopped camera.
      await _callService.removeLocalVideoTrack();
    }
    // Peers still hold the previous, now stopped, microphone track (or the
    // screen audio mix), so they need the new one too or they'd hear nothing.
    final audioTrack = localStream?.getAudioTracks().firstOrNull;
    if (audioTrack != null) {
      await _callService.replaceLocalAllAudioTrack(audioTrack);
    }

    emit(
      s.copyWith(
        isScreenSharing: false,
        isVideoEnabled: shouldRestoreCamera,
        activeScreenShare: null,
        localShareCameraRenderer: null,
      ),
    );
    if (_roomId != null && userId != null) {
      _syncState(
        _roomId!,
        userId!,
        video: shouldRestoreCamera,
        audio: !s.isMuted,
        screen: false,
      );
    }
  }

  Future<void> _startScreenShare(
    CallConnected s,
    Emitter<CallState> emit,
    int sessionId,
    ScreenShareOptions? requestedOptions,
  ) async {
    _isVideoEnabledBeforeScreenShare = s.isVideoEnabled;
    final options = requestedOptions ?? const ScreenShareOptions();
    var isMixingAudio = false;

    try {
      if ((!kIsWeb && Platform.isAndroid)) {
        final hasPermission = await Helper.requestCapturePermission();
        if (hasPermission != true) {
          debugPrint('[CallBloc] Screen capture permission denied.');
          return;
        }

        try {
          await channel.invokeMethod('stopVoiceService');
          await channel.invokeMethod('startService', {
            'action': 'PROJECTION_READY',
          });
          await Future.delayed(const Duration(milliseconds: 500));
          if (!_isCallActive || _sessionId != sessionId) return;
        } catch (e) {
          debugPrint('[CallBloc] Failed to start Android FGS: $e');
          await channel.invokeMethod('startVoiceService');
          rethrow;
        }
      }

      await _mediaDeviceService.startScreenShare(options: options);

      final screenStream = _mediaDeviceService.screenStream;
      final screenVideoTrack = screenStream?.getVideoTracks().firstOrNull;
      if (screenStream == null || screenVideoTrack == null) {
        throw StateError('Screen capture returned no video track');
      }
      ActiveScreenShare? activeShare;

      if (_localRenderer != null) {
        _localRenderer!.srcObject = screenStream;
      }

      final microphoneTrack = _mediaDeviceService.localStream
          ?.getAudioTracks()
          .firstOrNull;
      var outgoingAudio = microphoneTrack;

      if (kIsWeb) {
        BrowserScreenCapture.applyContentHint(
          screenVideoTrack,
          options.profile.contentHint,
        );
        // Fires when the browser ends the capture (its "Stop sharing" bar,
        // closing the shared tab); our own track.stop() doesn't trigger it.
        screenVideoTrack.onEnded = () {
          if (!isClosed && _sessionId == sessionId) {
            add(const ScreenShareEnded());
          }
        };

        final displayAudioTrack = screenStream.getAudioTracks().firstOrNull;
        if (displayAudioTrack != null) {
          try {
            outgoingAudio = await _screenAudioMixer.mix(
              microphone: microphoneTrack,
              display: displayAudioTrack,
            );
            isMixingAudio = true;
          } catch (e) {
            // Share the screen without its audio rather than failing.
            debugPrint('[CallBloc] Screen audio mixing unavailable: $e');
          }
        }

        activeShare = ActiveScreenShare(
          profile: options.profile,
          surface: BrowserScreenCapture.surfaceOf(screenVideoTrack),
          audioRequested: options.shareAudio,
          hasAudio: isMixingAudio,
        );
      }

      final composite = await createLocalMediaStream('sharing_stream');
      _compositeStream = composite;
      if (outgoingAudio != null) await composite.addTrack(outgoingAudio);
      await composite.addTrack(screenVideoTrack);
      _callService.updateLocalStream(composite);
      await _callService.replaceLocalAllVideoTrack(screenVideoTrack);
      if (isMixingAudio) {
        await _callService.replaceLocalAllAudioTrack(outgoingAudio!);
      }
      if (kIsWeb) {
        await _callService.setVideoSenderLimits(
          maxBitrate: options.profile.maxBitrate,
          maxFramerate: options.profile.frameRate,
        );
      }

      // A camera that was on keeps going, now next to the screen.
      final camera = _isVideoEnabledBeforeScreenShare
          ? _mediaDeviceService.localStream?.getVideoTracks().firstOrNull
          : null;
      if (camera != null) await _startShareCamera(camera);

      emit(
        s.copyWith(
          isScreenSharing: true,
          isVideoEnabled: true,
          activeScreenShare: activeShare,
          cameraAfterShare: _isVideoEnabledBeforeScreenShare,
          localShareCameraRenderer: _localShareCameraRenderer,
        ),
      );
    } catch (e) {
      debugPrint('[CallBloc] Screen share startup failed: $e');

      if ((!kIsWeb && Platform.isAndroid)) {
        try {
          await channel.invokeMethod('stopService');
          await channel.invokeMethod('startVoiceService');
        } catch (_) {}
      }

      try {
        await _stopShareCamera();
        await _mediaDeviceService.stopScreenShare();
        if (kIsWeb) {
          await _screenAudioMixer.dispose();
          await _callService.setVideoSenderLimits();
        }
        await _compositeStream?.dispose();
        _compositeStream = null;
        final localStream = _mediaDeviceService.localStream;
        _callService.updateLocalStream(localStream);
        if (_localRenderer != null) {
          _localRenderer!.srcObject = localStream;
        }
        final videoTrack = localStream?.getVideoTracks().firstOrNull;
        if (videoTrack != null) {
          await _callService.replaceLocalAllVideoTrack(videoTrack);
        } else {
          // Camera off: don't leave peers on the share or a stopped camera.
          await _callService.removeLocalVideoTrack();
        }
        final audioTrack = localStream?.getAudioTracks().firstOrNull;
        if (isMixingAudio && audioTrack != null) {
          await _callService.replaceLocalAllAudioTrack(audioTrack);
        }
      } catch (re) {
        debugPrint('[CallBloc] Failed to revert to camera: $re');
      }

      emit(
        s.copyWith(
          isScreenSharing: false,
          isVideoEnabled: _isVideoEnabledBeforeScreenShare,
          activeScreenShare: null,
          localShareCameraRenderer: null,
        ),
      );
      if (_roomId != null && userId != null) {
        _syncState(
          _roomId!,
          userId!,
          video: _isVideoEnabledBeforeScreenShare,
          audio: !s.isMuted,
          screen: false,
        );
      }
      return;
    }

    if (_roomId != null && userId != null) {
      final newS = state as CallConnected;
      _syncState(
        _roomId!,
        userId!,
        video: newS.isVideoEnabled,
        audio: !newS.isMuted,
        screen: newS.isScreenSharing,
      );
      if (newS.isScreenSharing) _scheduleScreenShareResync(sessionId);
    }
  }

  /// Receivers may keep showing a black share until their UI rebuilds after
  /// the first screen frames arrive (see ScreenShareVideoView). Released app
  /// versions lack that fix, so publish the share state again a little later:
  /// each write bumps `updatedAt`, which rebuilds their room screen.
  void _scheduleScreenShareResync(int sessionId) {
    for (final delay in const [
      Duration(milliseconds: 1500),
      Duration(seconds: 4),
    ]) {
      Timer(delay, () {
        final s = state;
        if (isClosed ||
            _sessionId != sessionId ||
            s is! CallConnected ||
            !s.isScreenSharing ||
            _roomId == null ||
            userId == null) {
          return;
        }
        _syncState(
          _roomId!,
          userId!,
          video: s.isVideoEnabled,
          audio: !s.isMuted,
          screen: true,
        );
      });
    }
  }

  // ─── Device controls ──────────────────────────────────────────────────────

  void _onSwitchCamera(SwitchCamera event, Emitter<CallState> emit) async {
    await _mediaDeviceService.switchCamera();
  }

  Future<void> _onChangeVideoInput(
    ChangeVideoInput event,
    Emitter<CallState> emit,
  ) async {
    await _mediaDeviceService.selectVideoInput(event.device);
    await _republishCameraStream();

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
    await _republishCameraStream();

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
    if (kIsWeb) {
      // Browsers play remote audio through each peer's media element.
      for (final renderer in _remoteRenderers.values) {
        await renderer.audioOutput(event.device.deviceId);
      }
    } else {
      await _mediaDeviceService.selectAudioOutput(event.device);
    }
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
    if (state is! CallConnected) return;

    try {
      await _mediaDeviceService.setQuality(event.preset);
      await Future.delayed(const Duration(milliseconds: 300));
      await _republishCameraStream();

      final nextState = state;
      if (nextState is! CallConnected) return;
      emit(nextState.copyWith(currentQuality: event.preset));
    } catch (e) {
      debugPrint("[CallBloc] Error changing quality: $e");
    }
  }

  /// Device and quality changes recreate the camera stream, which stops the
  /// old microphone and camera tracks. Point the peers and the preview at
  /// the new tracks, keep the user's mute and camera choices (new tracks
  /// start enabled), and keep an active screen share on air.
  /// What is being sent right now; polled by the sharer's quality chip.
  Future<OutgoingVideoStats?> outgoingVideoStats() =>
      _callService.getOutgoingVideoStats();

  Future<void> _republishCameraStream() async {
    final s = state;
    final stream = _mediaDeviceService.localStream;
    if (s is! CallConnected || stream == null) return;

    _mediaDeviceService.toggleMute(s.isMuted);
    final microphone = stream.getAudioTracks().firstOrNull;
    var outgoingAudio = microphone;

    if (s.isScreenSharing) {
      // Native setQuality restarts the capture, so take the current tracks.
      final screenStream = _mediaDeviceService.screenStream;
      final screenVideo = screenStream?.getVideoTracks().firstOrNull;
      final displayAudio = kIsWeb
          ? screenStream?.getAudioTracks().firstOrNull
          : null;
      if (displayAudio != null) {
        try {
          outgoingAudio = await _screenAudioMixer.mix(
            microphone: microphone,
            display: displayAudio,
          );
        } catch (e) {
          debugPrint('[CallBloc] Screen audio mixing unavailable: $e');
        }
      }

      await _compositeStream?.dispose();
      final composite = await createLocalMediaStream('sharing_stream');
      _compositeStream = composite;
      if (outgoingAudio != null) await composite.addTrack(outgoingAudio);
      if (screenVideo != null) await composite.addTrack(screenVideo);
      _callService.updateLocalStream(composite);

      if (screenVideo != null) {
        if (_localRenderer != null) _localRenderer!.srcObject = screenStream;
        await _callService.replaceLocalAllVideoTrack(screenVideo);
      }
    } else {
      _mediaDeviceService.toggleVideo(s.isVideoEnabled);
      _callService.updateLocalStream(stream);
      if (_localRenderer != null) _localRenderer!.srcObject = stream;
      final video = stream.getVideoTracks().firstOrNull;
      if (video != null) {
        await _callService.replaceLocalAllVideoTrack(video);
      } else {
        await _callService.removeLocalVideoTrack();
      }
    }

    if (outgoingAudio != null) {
      await _callService.replaceLocalAllAudioTrack(outgoingAudio);
    }
  }

  void _onChangeVideoSize(ChangeVideoSize event, Emitter<CallState> emit) {
    if (state is CallConnected) {
      emit((state as CallConnected).copyWith(videoSize: event.size));
    }
  }

  // ─── State sync ───────────────────────────────────────────────────────────

  Future<void> _syncState(
    String roomId,
    String userId, {
    required bool video,
    required bool audio,
    required bool screen,
  }) async {
    try {
      await roomRepository.updateUserMediaState(
        roomId,
        userId,
        isVideoEnabled: video,
        isAudioEnabled: audio,
        isScreenSharing: screen,
        isShareCameraOn: screen && _shareCameraOn,
      );
    } catch (e) {
      debugPrint("[CallBloc] Failed to sync media state: $e");
    }
  }
}
