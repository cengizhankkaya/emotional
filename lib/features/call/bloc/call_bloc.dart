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
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

const channel = MethodChannel('com.example.emotional/screen_share');

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
  Map<String, bool> _userScreenSharingStates = {};

  final Set<String> _connectionInitiated = {};

  StreamSubscription<RoomEntity?>? _roomSubscription;

  String? _roomId;
  String? _userId;
  String? get userId => _userId;

  MediaStream? _compositeStream; // Combined stream for sharing (audio + screen)

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
    // Device & Quality Events
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
  bool _isRequestingScreenShare =
      false; // Flag to prevent suspend during permission dialog
  bool _isVideoEnabledBeforeScreenShare = false;

  Future<void> _onJoinCall(JoinCall event, Emitter<CallState> emit) async {
    // ... existing ...
    emit(CallLoading());
    try {
      _roomId = event.roomId;
      _userId = event.userId;

      if (_isSuspended) {
        debugPrint(
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
      // Also request notification permission so the foreground service shows up
      await permissionService.requestNotificationPermission();

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

      // Start Android Foreground Service for Voice
      if (Platform.isAndroid) {
        try {
          await channel.invokeMethod('startVoiceService');
        } catch (e) {
          debugPrint('CallBloc: Failed to start startVoiceService: $e');
        }
      }

      // 6. Setup Room Listeners (User Discovery)
      _setupRoomListeners();

      // 7. Initialize User Media State
      await roomRepository.updateUserMediaState(
        _roomId!,
        _userId!,
        isVideoEnabled: false,
        isAudioEnabled: true,
        isScreenSharing: false,
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

        // Skip if user is muted known by room state
        if (_userAudioStates[userId] == false) continue;

        final level = await _callService.getRemoteAudioLevel(userId);
        // Debug log
        if (level > 0) {
          debugPrint("[CallBloc] Audio level for $userId: $level");
        }

        if (level > maxAudioLevel && level > 0.01) {
          // Lowered threshold to 0.01
          // Threshold
          maxAudioLevel = level;
          currentActiveSpeaker = userId;
        }
      }

      // Check Local User
      if (_userId != null && state is CallConnected) {
        final s = state as CallConnected;
        // Only check local audio level if NOT muted
        if (!s.isMuted) {
          final localLevel = await _callService.getLocalAudioLevel();
          if (localLevel > 0) {
            debugPrint("[CallBloc] Local Audio level: $localLevel");
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
          "[CallBloc] Active Speaker changed: $currentActiveSpeaker (Level: $maxAudioLevel)",
        );
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
      _userScreenSharingStates.clear();
      roomEntity.usersState.forEach((uid, state) {
        _userVideoStates[uid] = state.isVideoEnabled;
        _userAudioStates[uid] = state.isAudioEnabled;
        _userScreenSharingStates[uid] = state.isScreenSharing;
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
          userScreenSharingStates: Map.from(_userScreenSharingStates),
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
    // Stop Android Foreground Service
    if (Platform.isAndroid) {
      try {
        await channel.invokeMethod('stopVoiceService');
      } catch (e) {
        debugPrint('CallBloc: Failed to stop stopVoiceService: $e');
      }
    }

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
    _userScreenSharingStates.clear();

    await _callService.dispose();
    await _mediaDeviceService.dispose();
    await _compositeStream?.dispose();
    _compositeStream = null;
    await _audioSessionService.deactivate();
  }

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

  Future<void> _onSuspendMedia(
    SuspendMedia event,
    Emitter<CallState> emit,
  ) async {
    if (state is CallConnected && !_isSuspended) {
      final s = state as CallConnected;

      // CRITICAL: Do not suspend if we are screen sharing or requesting it (permission dialog open)
      // Screen share implies background execution is allowed/expected.
      if (s.isScreenSharing || _isRequestingScreenShare) {
        print(
          'CallBloc: SuspendMedia ignored because screen share is active/requesting.',
        );
        return;
      }

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
          screen: s
              .isScreenSharing, // Resume might need to handle screen share too?
          // For now assuming resume implies restoring audio/video,
          // screen share might be lost on suspend/resume cycle if we didn't store it.
          // But 's' here is the state BEFORE resume finished? No, 's' is state at start of method.
          // IsScreenSharing is in state.
        );
      }
    }
  }

  Future<void> _onToggleVideo(
    ToggleVideo event,
    Emitter<CallState> emit,
  ) async {
    if (state is CallConnected) {
      final s = state as CallConnected;
      final newVideoState = !s.isVideoEnabled;

      if (newVideoState) {
        // If we are turning video ON, check if we have a video track
        final hasVideoTrack =
            _mediaDeviceService.localStream?.getVideoTracks().isNotEmpty ??
            false;

        if (!hasVideoTrack) {
          debugPrint(
            '[CallBloc] No video track found while toggling ON. Re-initializing stream...',
          );
          await _mediaDeviceService.initialize(enableVideo: true);

          // Update everyone with the new stream/track
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
        } else {
          _mediaDeviceService.toggleVideo(true);
        }
      } else {
        // Toggling OFF is easy
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
  }

  Future<void> _onToggleScreenShare(
    ToggleScreenShare event,
    Emitter<CallState> emit,
  ) async {
    if (state is CallConnected) {
      final s = state as CallConnected;

      // Guard against rapid double-toggle
      if (_isRequestingScreenShare) {
        debugPrint('[CallBloc] ToggleScreenShare ignored: already processing.');
        return;
      }

      debugPrint(
        '[CallBloc] ToggleScreenShare event processing. Current state: isScreenSharing=${s.isScreenSharing}',
      );
      _isRequestingScreenShare = true; // Protect against SuspendMedia

      try {
        if (s.isScreenSharing) {
          // STOP Screen Share
          final shouldRestoreCamera = _isVideoEnabledBeforeScreenShare;
          debugPrint(
            '[CallBloc] Stopping screen share. Restore camera? $shouldRestoreCamera',
          );

          // 1. Unbind renderer FIRST to stop UI from trying to draw native textures
          if (_localRenderer != null) {
            debugPrint('[CallBloc] Unbinding local renderer source...');
            _localRenderer!.srcObject = null;
            // Short delay to let the UI thread process the unbind before we touch tracks
            await Future.delayed(const Duration(milliseconds: 100));
          }

          // 2. Stop streams and tracks
          await _mediaDeviceService.stopScreenShare();

          if (Platform.isAndroid) {
            try {
              // Safety delay: Ensure MediaProjection is fully released before killing FGS
              debugPrint('[CallBloc] Waiting 500ms for safety...');
              await Future.delayed(const Duration(milliseconds: 500));
              await channel.invokeMethod('stopService');
              await channel.invokeMethod('startVoiceService');
            } catch (e) {
              print("Failed to stop Android foreground service: $e");
            }
          }

          // RE-INITIALIZE Camera stream fresh with the PREVIOUS camera preference
          debugPrint(
            '[CallBloc] Re-initializing camera with enableVideo: $shouldRestoreCamera',
          );
          await _mediaDeviceService.initialize(
            enableVideo: shouldRestoreCamera,
          );

          // Clear any old composite stream
          await _compositeStream?.dispose();
          _compositeStream = null;

          _callService.updateLocalStream(_mediaDeviceService.localStream);

          if (shouldRestoreCamera) {
            debugPrint(
              '[CallBloc] Enabling camera as it was ON before screen share',
            );
            _mediaDeviceService.toggleVideo(true);
          }

          if (_localRenderer != null) {
            _localRenderer!.srcObject = _mediaDeviceService.localStream;
          }

          final videoTrack = _mediaDeviceService.localStream
              ?.getVideoTracks()
              .firstOrNull;
          if (videoTrack != null) {
            await _callService.replaceLocalAllVideoTrack(videoTrack);
          }

          debugPrint(
            "[CallBloc] SUCCESS: Emitting CallConnected with isScreenSharing=false, isVideoEnabled=$shouldRestoreCamera",
          );
          emit(
            s.copyWith(
              isScreenSharing: false,
              isVideoEnabled: shouldRestoreCamera,
            ),
          );

          // Synchronize state IMMEDIATELY for responsive transition across all users
          if (_roomId != null && userId != null) {
            _syncState(
              _roomId!,
              userId!,
              video: shouldRestoreCamera,
              audio: !s.isMuted,
              screen: false,
            );
          }
          return; // Exit early to avoid the redundant sync at the end
        } else {
          // START Screen Share
          _isVideoEnabledBeforeScreenShare = s.isVideoEnabled;
          debugPrint(
            "[CallBloc] Storing camera state: $_isVideoEnabledBeforeScreenShare",
          );

          try {
            if (Platform.isAndroid) {
              debugPrint("[CallBloc] Requesting screen capture permission...");
              final hasPermission = await Helper.requestCapturePermission();
              if (hasPermission != true) {
                debugPrint(
                  "[CallBloc] Screen capture permission denied by user.",
                );
                _isRequestingScreenShare = false;
                return;
              }

              try {
                debugPrint(
                  "[CallBloc] Permission granted. Starting Foreground Service with PROJECTION_READY...",
                );
                await channel.invokeMethod('stopVoiceService');
                await channel.invokeMethod('startService', {
                  'action': 'PROJECTION_READY',
                });
                await Future.delayed(const Duration(milliseconds: 500));
              } catch (e) {
                debugPrint("Failed to start Android foreground service: $e");
                await channel.invokeMethod(
                  'startVoiceService',
                ); // fallback if start fails
                rethrow; // Re-throw to trigger cleanup below
              }
            }

            try {
              debugPrint("[CallBloc] Initiating getDisplayMedia...");
              await _mediaDeviceService.startScreenShare();
            } catch (e) {
              debugPrint("[CallBloc] getDisplayMedia failed: $e");
              rethrow;
            }

            // Update tracks
            debugPrint(
              "[CallBloc] Creating composite stream (Camera Audio + Screen Video)...",
            );
            final screenStream = _mediaDeviceService.screenStream;
            final cameraStream = _mediaDeviceService.localStream;

            if (screenStream != null) {
              final screenVideoTrack = screenStream
                  .getVideoTracks()
                  .firstOrNull;

              if (screenVideoTrack != null) {
                // 1. UI update
                if (_localRenderer != null) {
                  _localRenderer!.srcObject = screenStream;
                }

                // 2. Create composite stream for WebRTC service (for NEW connections)
                final composite = await createLocalMediaStream(
                  'sharing_stream',
                );
                _compositeStream = composite; // Store for cleanup
                if (cameraStream != null) {
                  for (var track in cameraStream.getAudioTracks()) {
                    await composite.addTrack(track);
                  }
                }
                await composite.addTrack(screenVideoTrack);

                _callService.updateLocalStream(composite);

                // 3. Update EXISTING connections
                debugPrint(
                  "[CallBloc] Replacing local video track for all peers...",
                );
                await _callService.replaceLocalAllVideoTrack(screenVideoTrack);
              }
            }

            debugPrint(
              "[CallBloc] SUCCESS: Emitting CallConnected with isScreenSharing=true",
            );
            emit(s.copyWith(isScreenSharing: true, isVideoEnabled: true));
          } catch (e) {
            debugPrint("[CallBloc] Screen share startup phase failed: $e");

            // CRITICAL CLEANUP: If anything failed during START, ensure service is stopped
            if (Platform.isAndroid) {
              try {
                debugPrint(
                  "[CallBloc] Fatal error during start. Stopping service...",
                );
                await channel.invokeMethod('stopService');
                await channel.invokeMethod('startVoiceService');
              } catch (se) {
                // ignore
              }
            }

            // Restore camera if we were in the middle of transitioning
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
              debugPrint("[CallBloc] Failed to revert to camera: $re");
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
            return; // Exit early as we already handled the error
          }
        }

        if (_roomId != null && userId != null) {
          // We treat screen share as "video enabled"
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
        debugPrint("Error toggling screen share: $e");
      } finally {
        _isRequestingScreenShare = false; // Release protection
      }
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
    final currentState = state;
    if (currentState is! CallConnected) return;

    try {
      await _mediaDeviceService.setQuality(event.preset);

      // Give a small delay to allow tracks to stabilize after restart
      await Future.delayed(const Duration(milliseconds: 300));

      // Re-verify state after async call
      final nextState = state;
      if (nextState is! CallConnected) return;

      // If Screen Sharing is active, we need to update the composite stream and send the new tracks
      if (nextState.isScreenSharing) {
        final screenStream = _mediaDeviceService.screenStream;
        final cameraStream = _mediaDeviceService.localStream;

        if (screenStream != null) {
          final screenVideoTrack = screenStream.getVideoTracks().firstOrNull;
          if (screenVideoTrack != null) {
            // 1. Update UI renderer
            if (_localRenderer != null) {
              _localRenderer!.srcObject = screenStream;
            }

            // 2. Clear and Recreate composite stream (Camera Audio + NEW Screen Video)
            await _compositeStream?.dispose();
            final composite = await createLocalMediaStream('sharing_stream');
            _compositeStream = composite;

            final audioTracks = cameraStream?.getAudioTracks() ?? [];
            for (var track in audioTracks) {
              try {
                await composite.addTrack(track);
              } catch (e) {
                print("[CallBloc] Failed to add audio track: $e");
              }
            }

            if (screenVideoTrack != null) {
              try {
                await composite.addTrack(screenVideoTrack);
              } catch (e) {
                print("[CallBloc] Failed to add screen track: $e");
              }
            }

            // 3. Update WebRTC Service and peers
            _callService.updateLocalStream(composite);
            await _callService.replaceLocalAllVideoTrack(screenVideoTrack);
          }
        }
      } else {
        // Normal camera mode
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
      final s = state as CallConnected;
      emit(s.copyWith(videoSize: event.size));
    }
  }

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
