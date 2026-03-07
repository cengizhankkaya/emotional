import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/call/service/media_device_service.dart';
import 'package:emotional/features/call/service/webrtc_service.dart';
import 'package:emotional/features/call/service/audio_session_service.dart';
import 'package:emotional/features/room/domain/entities/room_entity.dart';
import 'package:emotional/features/room/domain/repositories/room_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:emotional/core/services/permission_service.dart';
import 'package:permission_handler/permission_handler.dart';
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

  final Set<String> _connectionInitiated = {};

  /// Debounce timers for "user left" detection.
  /// Firebase can emit a stale/partial snapshot when the network briefly
  /// drops and reconnects, making a user appear absent for one update cycle.
  /// We wait 1500ms before actually calling forgetUser — if the user
  /// reappears in a subsequent snapshot the timer is cancelled.
  final Map<String, Timer> _leaveDebounceTimers = {};

  /// Per-user offer answer timeout timers.
  /// When we send an offer, we start a 15s timer. If no answer arrives
  /// (onConnectionState never reaches CONNECTED), the timer fires and
  /// we give up — removing the user from _connectionInitiated so the
  /// room-update loop can try once more if the user is still present,
  /// or cleanly stop retrying if they've left.
  final Map<String, Timer> _offerTimeoutTimers = {};

  /// Per-user consecutive failure counter.
  /// After 3 consecutive unanswered offers we stop initiating until the
  /// user disappears from the room and reappears (genuine rejoin).
  final Map<String, int> _offerFailCount = {};

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
    on<ToggleMute>(_onToggleMute);
    on<ToggleVideo>(_onToggleVideo);
    on<ToggleScreenShare>(_onToggleScreenShare);
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
  bool _isRequestingScreenShare = false;
  bool _isVideoEnabledBeforeScreenShare = false;

  // ─── JoinCall ─────────────────────────────────────────────────────────────

  Future<void> _onJoinCall(JoinCall event, Emitter<CallState> emit) async {
    emit(const CallLoading());
    try {
      _sessionId++;
      _roomId = event.roomId;
      _userId = event.userId;

      _connectionInitiated.clear();
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

      final permissions = await permissionService
          .requestCameraAndMicrophonePermissions();
      final cameraGranted = permissions[Permission.camera] ?? false;
      final microphoneGranted = permissions[Permission.microphone] ?? false;

      if (!cameraGranted || !microphoneGranted) {
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
      if (Platform.isAndroid) {
        await Future.delayed(const Duration(milliseconds: 300));
      }

      try {
        await WakelockPlus.enable();
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
      await _mediaDeviceService.initialize();
      _mediaDeviceService.toggleVideo(false);
      _mediaDeviceService.toggleMute(false);

      // Activate AFTER getUserMedia so the session takes ownership of an
      // already-open mic/camera without a mid-acquisition interrupt.
      await _audioSessionService.activate();

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

      final roomEntity = await roomRepository.getRoom(_roomId!);
      final isHost = roomEntity?.hostId == _userId;
      await _callService.joinRoom(_roomId!, _userId!, isHost: isHost);

      if (Platform.isAndroid) {
        try {
          await channel.invokeMethod('startVoiceService');
        } catch (e) {
          debugPrint('CallBloc: Failed to start startVoiceService: $e');
        }
      }

      _setupRoomListeners();

      await roomRepository.updateUserMediaState(
        _roomId!,
        _userId!,
        isVideoEnabled: false,
        isAudioEnabled: true,
        isScreenSharing: false,
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
      _startAudioLevelMonitor();
    } catch (e) {
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
          print(
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
              print(
                "[CallBloc] User $missingUid confirmed left after debounce.",
              );
              _connectionInitiated.remove(missingUid);
              // FIX: Cancel pending offer timeout and reset fail count.
              // The user genuinely left — clean slate for when they rejoin.
              _offerTimeoutTimers.remove(missingUid)?.cancel();
              _offerFailCount.remove(missingUid);
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
          print("[CallBloc] User $uid reappeared — cancelling leave debounce.");
          timer.cancel();
        }
      }

      _activeUsers = Map.from(users);

      _userVideoStates.clear();
      _userAudioStates.clear();
      _userScreenSharingStates.clear();
      roomEntity.usersState.forEach((uid, state) {
        _userVideoStates[uid] = state.isVideoEnabled;
        _userAudioStates[uid] = state.isAudioEnabled;
        _userScreenSharingStates[uid] = state.isScreenSharing;
      });

      // ── Connect to new users ──────────────────────────────────────────────
      for (final otherUserId in currentUserIds) {
        if (otherUserId == _userId) continue;

        if (_userId!.compareTo(otherUserId) < 0) {
          if (!_connectionInitiated.contains(otherUserId)) {
            print("[CallBloc] Initiating connection to $otherUserId in 500ms.");
            _connectionInitiated.add(otherUserId);
            final sessionId = _sessionId;
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!_isCallActive ||
                  _sessionId != sessionId ||
                  !_connectionInitiated.contains(otherUserId) ||
                  !_activeUsers.containsKey(otherUserId) ||
                  _callService.isUserPendingBye(otherUserId)) {
                return;
              }

              // FIX: Check consecutive failure limit before attempting.
              // After 3 unanswered offers we stop retrying until the user
              // genuinely leaves and rejoins (forgetUser resets the counter).
              final failCount = _offerFailCount[otherUserId] ?? 0;
              if (failCount >= 3) {
                print(
                  "[CallBloc] Max offer attempts reached for $otherUserId — waiting for rejoin.",
                );
                return;
              }

              _callService.connect(otherUserId);

              // Start a 6s answer timeout. If we reach CONNECTED before it
              // fires, _onInternalIncomingStream cancels it. If it fires,
              // the offer went unanswered — release _connectionInitiated so
              // the next room update can retry (or stop if user is gone).
              _offerTimeoutTimers[otherUserId]?.cancel();
              _offerTimeoutTimers[otherUserId] = Timer(
                const Duration(seconds: 15),
                () {
                  _offerTimeoutTimers.remove(otherUserId);
                  if (!_isCallActive || _sessionId != sessionId) return;
                  // Only act if still not connected for this user
                  if (_remoteRenderers.containsKey(otherUserId)) return;
                  print(
                    "[CallBloc] Offer timeout for $otherUserId — no answer received.",
                  );
                  _offerFailCount[otherUserId] =
                      (_offerFailCount[otherUserId] ?? 0) + 1;
                  // Release the slot so the next room update can retry
                  _connectionInitiated.remove(otherUserId);
                },
              );
            });
          }
        }
        // Callee role: waits for initiator's offer via signaling
      }

      if (!isClosed) add(InternalUpdateState());
    });
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
        ),
      );
    }
  }

  Future<void> _onInternalIncomingStream(
    InternalIncomingStream event,
    Emitter<CallState> emit,
  ) async {
    print("[CallBloc] Incoming stream from ${event.userId}.");

    // FIX: Cancel offer timeout — connection established successfully.
    // Also reset the fail counter so future reconnects start fresh.
    _offerTimeoutTimers.remove(event.userId)?.cancel();
    _offerFailCount.remove(event.userId);

    final oldRenderer = _remoteRenderers.remove(event.userId);
    if (oldRenderer != null) {
      oldRenderer.srcObject = null;
      await oldRenderer.dispose();
    }

    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    renderer.srcObject = event.stream;
    _remoteRenderers[event.userId] = renderer;
    if (!isClosed) add(InternalUpdateState());
  }

  Future<void> _onInternalStreamRemoved(
    InternalStreamRemoved event,
    Emitter<CallState> emit,
  ) async {
    // FIX: Both _handleRemoteBye and forgetUser call onRemoteStreamRemoved,
    // which adds InternalStreamRemoved. This means the event can arrive twice
    // for the same user (once from bye, once from room-update → forgetUser).
    // The second call is a no-op for the renderer (already removed) — skip.
    final renderer = _remoteRenderers.remove(event.userId);
    if (renderer == null) return;

    print("[CallBloc] Stream removed for ${event.userId}.");

    // FIX: Do NOT remove from _connectionInitiated here.
    // This event fires on bye, but the user may still be in _activeUsers
    // (room update is delayed). If we remove from _connectionInitiated now,
    // the room-update loop will see the user still present and immediately
    // re-add them → new connect attempt → offer sent with no one to answer.
    // Instead, _connectionInitiated is only cleared when the room update
    // confirms the user is truly gone (missingUserIds debounce path) or
    // when the user reappears and a fresh connection is needed.
    //
    // The only safe removal here is the renderer — the WebRTC PC is already
    // closed by _handleRemoteBye before this event fires.
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
    if (Platform.isAndroid) {
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
    for (final t in _offerTimeoutTimers.values) {
      t.cancel();
    }
    _offerTimeoutTimers.clear();
    _offerFailCount.clear();

    // Brief wait for any in-flight async timer tick to finish before
    // we dispose the services it may still be calling into.
    await Future.delayed(const Duration(milliseconds: 100));

    if (_localRenderer != null) {
      _localRenderer!.srcObject = null;
      _localRenderer!.dispose();
      _localRenderer = null;
    }

    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('CallBloc: Failed to disable wakelock: $e');
    }

    for (final r in _remoteRenderers.values) {
      r.srcObject = null;
      r.dispose();
    }
    _remoteRenderers.clear();
    _connectionInitiated.clear();
    _activeUsers.clear();
    _userVideoStates.clear();
    _userAudioStates.clear();
    _userScreenSharingStates.clear();

    // FIX: Dispose media streams BEFORE deactivating the audio session.
    // If deactivate() runs first, the OS sees the mic/camera being released
    // without an active session owner, which triggers a spurious interruption
    // event on the next activate() call. Correct teardown order:
    //   callService.dispose → mediaDevice.dispose → compositeStream.dispose
    //   → audioSession.deactivate  (session released last, cleanly)
    await _callService.dispose();
    await _mediaDeviceService.dispose();
    await _compositeStream?.dispose();
    _compositeStream = null;

    // Deactivate last so the OS sees a clean handoff.
    await _audioSessionService.deactivate();
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
    final newVideoState = !s.isVideoEnabled;

    if (newVideoState) {
      final hasVideoTrack =
          _mediaDeviceService.localStream?.getVideoTracks().isNotEmpty ?? false;

      if (!hasVideoTrack) {
        debugPrint('[CallBloc] No video track — re-initializing stream.');
        await _mediaDeviceService.initialize(enableVideo: true);
        _callService.updateLocalStream(_mediaDeviceService.localStream);
        if (_localRenderer != null) {
          _localRenderer!.srcObject = _mediaDeviceService.localStream;
        }
        final videoTrack = _mediaDeviceService.localStream
            ?.getVideoTracks()
            .firstOrNull;
        if (videoTrack != null) {
          await _callService.replaceLocalAllVideoTrack(videoTrack);
        }

        final audioTrack = _mediaDeviceService.localStream
            ?.getAudioTracks()
            .firstOrNull;
        if (audioTrack != null) {
          await _callService.replaceLocalAllAudioTrack(audioTrack);
        }
      } else {
        _mediaDeviceService.toggleVideo(true);
      }
    } else {
      _mediaDeviceService.toggleVideo(false);
    }

    emit(s.copyWith(isVideoEnabled: newVideoState));
    if (_roomId != null && userId != null) {
      _syncState(
        _roomId!,
        userId!,
        video: newVideoState,
        audio: !s.isMuted,
        screen: s.isScreenSharing,
      );
    }
  }

  // ─── Suspend / Resume ─────────────────────────────────────────────────────

  Future<void> _onSuspendMedia(
    SuspendMedia event,
    Emitter<CallState> emit,
  ) async {
    if (state is! CallConnected || _isSuspended) return;
    final s = state as CallConnected;

    if (s.isScreenSharing || _isRequestingScreenShare) {
      print('CallBloc: SuspendMedia ignored — screen share active.');
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
        screen: s.isScreenSharing,
      );
    }
  }

  // ─── Screen share ─────────────────────────────────────────────────────────

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
        // ── STOP ──────────────────────────────────────────────
        final shouldRestoreCamera = _isVideoEnabledBeforeScreenShare;

        if (_localRenderer != null) {
          _localRenderer!.srcObject = null;
          await Future.delayed(const Duration(milliseconds: 100));
        }

        await _mediaDeviceService.stopScreenShare();

        if (Platform.isAndroid) {
          try {
            await Future.delayed(const Duration(milliseconds: 500));
            if (!_isCallActive || _sessionId != sessionId) return;
            await channel.invokeMethod('stopService');
            await channel.invokeMethod('startVoiceService');
          } catch (e) {
            print("[CallBloc] Failed to stop Android FGS: $e");
          }
        }

        await _mediaDeviceService.initialize(enableVideo: shouldRestoreCamera);
        await _compositeStream?.dispose();
        _compositeStream = null;

        _callService.updateLocalStream(_mediaDeviceService.localStream);
        if (shouldRestoreCamera) _mediaDeviceService.toggleVideo(true);
        if (_localRenderer != null) {
          _localRenderer!.srcObject = _mediaDeviceService.localStream;
        }

        final videoTrack = _mediaDeviceService.localStream
            ?.getVideoTracks()
            .firstOrNull;
        if (videoTrack != null) {
          await _callService.replaceLocalAllVideoTrack(videoTrack);
        }

        emit(
          s.copyWith(
            isScreenSharing: false,
            isVideoEnabled: shouldRestoreCamera,
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
        return;
      } else {
        // ── START ─────────────────────────────────────────────
        _isVideoEnabledBeforeScreenShare = s.isVideoEnabled;

        try {
          if (Platform.isAndroid) {
            final hasPermission = await Helper.requestCapturePermission();
            if (hasPermission != true) {
              debugPrint('[CallBloc] Screen capture permission denied.');
              _isRequestingScreenShare = false;
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

          await _mediaDeviceService.startScreenShare();

          final screenStream = _mediaDeviceService.screenStream;
          final cameraStream = _mediaDeviceService.localStream;

          if (screenStream != null) {
            final screenVideoTrack = screenStream.getVideoTracks().firstOrNull;
            if (screenVideoTrack != null) {
              if (_localRenderer != null) {
                _localRenderer!.srcObject = screenStream;
              }

              final composite = await createLocalMediaStream('sharing_stream');
              _compositeStream = composite;
              if (cameraStream != null) {
                for (final track in cameraStream.getAudioTracks()) {
                  await composite.addTrack(track);
                }
              }
              await composite.addTrack(screenVideoTrack);
              _callService.updateLocalStream(composite);
              await _callService.replaceLocalAllVideoTrack(screenVideoTrack);
            }
          }

          emit(s.copyWith(isScreenSharing: true, isVideoEnabled: true));
        } catch (e) {
          debugPrint('[CallBloc] Screen share startup failed: $e');

          if (Platform.isAndroid) {
            try {
              await channel.invokeMethod('stopService');
              await channel.invokeMethod('startVoiceService');
            } catch (_) {}
          }

          try {
            await _mediaDeviceService.stopScreenShare();
            await _compositeStream?.dispose();
            _compositeStream = null;
            _callService.updateLocalStream(_mediaDeviceService.localStream);
            if (_localRenderer != null) {
              _localRenderer!.srcObject = _mediaDeviceService.localStream;
            }
            final videoTrack = _mediaDeviceService.localStream
                ?.getVideoTracks()
                .firstOrNull;
            if (videoTrack != null) {
              await _callService.replaceLocalAllVideoTrack(videoTrack);
            }
          } catch (re) {
            debugPrint('[CallBloc] Failed to revert to camera: $re');
          }

          emit(
            s.copyWith(
              isScreenSharing: false,
              isVideoEnabled: _isVideoEnabledBeforeScreenShare,
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
      }
    } catch (e) {
      debugPrint('[CallBloc] Error toggling screen share: $e');
    } finally {
      _isRequestingScreenShare = false;
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
    final newStream = _mediaDeviceService.localStream;
    _callService.updateLocalStream(newStream);
    if (_localRenderer != null) {
      _localRenderer!.srcObject = newStream;
    }

    if (newStream != null) {
      final videoTrack = newStream.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        await _callService.replaceLocalAllVideoTrack(videoTrack);
      }

      final audioTrack = newStream.getAudioTracks().firstOrNull;
      if (audioTrack != null) {
        await _callService.replaceLocalAllAudioTrack(audioTrack);
      }
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
    final newStream = _mediaDeviceService.localStream;
    _callService.updateLocalStream(newStream);

    if (newStream != null) {
      final videoTrack = newStream.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        await _callService.replaceLocalAllVideoTrack(videoTrack);
      }

      final audioTrack = newStream.getAudioTracks().firstOrNull;
      if (audioTrack != null) {
        await _callService.replaceLocalAllAudioTrack(audioTrack);
      }
    }

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
    final currentState = state;
    if (currentState is! CallConnected) return;

    try {
      await _mediaDeviceService.setQuality(event.preset);
      await Future.delayed(const Duration(milliseconds: 300));

      final nextState = state;
      if (nextState is! CallConnected) return;

      if (nextState.isScreenSharing) {
        final screenStream = _mediaDeviceService.screenStream;
        final cameraStream = _mediaDeviceService.localStream;

        if (screenStream != null) {
          final screenVideoTrack = screenStream.getVideoTracks().firstOrNull;
          if (screenVideoTrack != null) {
            if (_localRenderer != null) {
              _localRenderer!.srcObject = screenStream;
            }

            await _compositeStream?.dispose();
            final composite = await createLocalMediaStream('sharing_stream');
            _compositeStream = composite;

            for (final track in cameraStream?.getAudioTracks() ?? []) {
              try {
                await composite.addTrack(track);
              } catch (e) {
                print("[CallBloc] Failed to add audio track: $e");
              }
            }
            try {
              await composite.addTrack(screenVideoTrack);
            } catch (e) {
              print("[CallBloc] Failed to add screen track: $e");
            }

            _callService.updateLocalStream(composite);
            await _callService.replaceLocalAllVideoTrack(screenVideoTrack);
          }
        }
      } else {
        _callService.updateLocalStream(_mediaDeviceService.localStream);
        if (_localRenderer != null) {
          _localRenderer!.srcObject = _mediaDeviceService.localStream;
        }
        final videoTrack = _mediaDeviceService.localStream
            ?.getVideoTracks()
            .firstOrNull;
        if (videoTrack != null) {
          await _callService.replaceLocalAllVideoTrack(videoTrack);
        }
      }

      emit(nextState.copyWith(currentQuality: event.preset));
    } catch (e) {
      print("[CallBloc] Error changing quality: $e");
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
      );
    } catch (e) {
      print("[CallBloc] Failed to sync media state: $e");
    }
  }
}
