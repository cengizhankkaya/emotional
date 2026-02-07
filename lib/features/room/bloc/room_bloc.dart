import 'dart:async';

import 'package:emotional/features/room/domain/entities/room_entity.dart';
import 'package:emotional/features/room/domain/usecases/create_room_usecase.dart';
import 'package:emotional/features/room/domain/usecases/join_room_usecase.dart';
import 'package:emotional/features/room/domain/usecases/leave_room_usecase.dart';
import 'package:emotional/features/room/domain/usecases/reassign_host_usecase.dart';
import 'package:emotional/features/room/domain/usecases/stream_room_usecase.dart';
import 'package:emotional/features/room/domain/usecases/sync_settings_usecase.dart';
import 'package:emotional/features/room/domain/usecases/sync_video_usecase.dart';
import 'package:emotional/features/room/domain/usecases/update_room_video_usecase.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'room_event.dart';
part 'room_state.dart';

class RoomBloc extends Bloc<RoomEvent, RoomState> {
  final CreateRoomUseCase _createRoom;
  final JoinRoomUseCase _joinRoom;
  final LeaveRoomUseCase _leaveRoom;
  final StreamRoomUseCase _streamRoom;
  final SyncVideoUseCase _syncVideo;
  final SyncSettingsUseCase _syncSettings;
  final UpdateRoomVideoUseCase _updateRoomVideo;
  final ReassignHostUseCase _reassignHost;

  StreamSubscription<RoomEntity?>? _roomSubscription;
  String? _currentUserId;
  String? _currentUserName;
  bool _isAppInBackgrounded = false;
  bool _isLeavingRoom = false;

  RoomBloc({
    required CreateRoomUseCase createRoom,
    required JoinRoomUseCase joinRoom,
    required LeaveRoomUseCase leaveRoom,
    required StreamRoomUseCase streamRoom,
    required SyncVideoUseCase syncVideo,
    required SyncSettingsUseCase syncSettings,
    required UpdateRoomVideoUseCase updateRoomVideo,
    required ReassignHostUseCase reassignHost,
  }) : _createRoom = createRoom,
       _joinRoom = joinRoom,
       _leaveRoom = leaveRoom,
       _streamRoom = streamRoom,
       _syncVideo = syncVideo,
       _syncSettings = syncSettings,
       _updateRoomVideo = updateRoomVideo,
       _reassignHost = reassignHost,
       super(const RoomInitial()) {
    on<CreateRoomRequested>(_onCreateRoomRequested);
    on<JoinRoomRequested>(_onJoinRoomRequested);
    on<LeaveRoomRequested>(_onLeaveRoomRequested);
    on<RoomUpdated>(_onRoomUpdated);
    on<UpdateRoomVideoRequested>(_onUpdateRoomVideoRequested);
    on<SyncVideoAction>(_onSyncVideoAction);
    on<SyncSettingsAction>(_onSyncSettingsAction);
    on<TransferHostRequested>(_onTransferHostRequested);
    on<SetRoomAppBackgrounded>(_onSetRoomAppBackgrounded);
  }

  void _onSetRoomAppBackgrounded(
    SetRoomAppBackgrounded event,
    Emitter<RoomState> emit,
  ) {
    _isAppInBackgrounded = event.isBackgrounded;
    print('RoomBloc: App background state changed to: $_isAppInBackgrounded');
  }

  Future<void> _onTransferHostRequested(
    TransferHostRequested event,
    Emitter<RoomState> emit,
  ) async {
    try {
      await _reassignHost(event.roomId, event.newHostId);
    } catch (e) {
      print('RoomBloc: Error transferring host: $e');
    }
  }

  @override
  Future<void> close() {
    _roomSubscription?.cancel();
    return super.close();
  }

  Future<void> _onCreateRoomRequested(
    CreateRoomRequested event,
    Emitter<RoomState> emit,
  ) async {
    emit(RoomLoading());
    try {
      _currentUserId = event.userId;
      _currentUserName = event.userName;
      _isLeavingRoom = false;
      final roomId = await _createRoom(event.userId, event.userName);
      emit(RoomCreated(roomId, event.userId));
      _subscribeToRoom(roomId);
    } catch (e) {
      emit(RoomError(e.toString()));
    }
  }

  Future<void> _onJoinRoomRequested(
    JoinRoomRequested event,
    Emitter<RoomState> emit,
  ) async {
    emit(RoomLoading());
    try {
      _currentUserId = event.userId;
      _currentUserName = event.userName;
      _isLeavingRoom = false;
      await _joinRoom(event.roomId, event.userId, event.userName);
      _subscribeToRoom(event.roomId);
    } catch (e) {
      emit(RoomError(e.toString()));
    }
  }

  Future<void> _onLeaveRoomRequested(
    LeaveRoomRequested event,
    Emitter<RoomState> emit,
  ) async {
    _isLeavingRoom = true;
    _roomSubscription?.cancel();
    _roomSubscription = null;
    final uid = _currentUserId ?? event.userId;
    _currentUserId = null;
    _currentUserName = null;
    emit(RoomInitial());

    try {
      await _leaveRoom(event.roomId, uid);
    } catch (e) {
      print('RoomBloc: Error leaving room in repository: $e');
    }
  }

  void _subscribeToRoom(String roomId) {
    _roomSubscription?.cancel();
    _roomSubscription = _streamRoom(roomId).listen(
      (roomEntity) {
        // Handle room deletion
        if (roomEntity == null) {
          if (_currentUserId != null) {
            print(
              'RoomBloc: Room node DELETED from database. Kicking out. User ID: $_currentUserId',
            );
            add(LeaveRoomRequested(roomId: roomId, userId: _currentUserId!));
          }
          return;
        }

        // --- Re-entry / Session Recovery ---
        if (_currentUserId != null &&
            !roomEntity.users.containsKey(_currentUserId)) {
          if (state is RoomLoading || state is RoomCreated) {
            print(
              'RoomBloc: [GRACE] User $_currentUserId not found in usersMap yet. Waiting...',
            );
          } else if (state is RoomJoined) {
            // SESSION RECOVERY
            if (_isAppInBackgrounded) {
              print(
                'RoomBloc: User $_currentUserId MISSING from usersMap, but app is in BACKGROUND. Delaying re-join until resumed.',
              );
              return;
            }
            if (_isLeavingRoom) {
              print(
                'RoomBloc: User is leaving, ignoring missing member check.',
              );
              return;
            }
            print(
              'RoomBloc: User $_currentUserId MISSING from usersMap while joined. Re-joining automatically...',
            );
            _joinRoom(roomId, _currentUserId!, _currentUserName ?? "Kullanıcı");
            return;
          } else {
            print(
              'RoomBloc: User $_currentUserId NOT found in usersMap. State is ${state.runtimeType}. Kicking out.',
            );
            add(LeaveRoomRequested(roomId: roomId, userId: _currentUserId!));
            return;
          }
        }

        // Map participant IDs to list and SORT alphabetically
        final participants = roomEntity.users.keys.toList();
        participants.sort();

        // Host Repair Logic handled in Repo?
        // Actually, repo doesn't handle host reassignment if stream watchers exist.
        // It does it on 'leaveRoom'.
        // But what if host crashes?
        // The original logic had:
        // if (hostId.isEmpty || !usersMap.containsKey(hostId)) ...
        // I should probably keep this logic in the UseCase or Repository, OR keep it here for now.
        // Since I moved 'reassignHost' to a UseCase, I can call it here.

        String hostId = roomEntity.hostId;
        if (hostId.isEmpty || !roomEntity.users.containsKey(hostId)) {
          if (participants.isNotEmpty) {
            final newHostId = participants.first;
            hostId = newHostId; // Update locally

            if (_currentUserId == newHostId) {
              print(
                'RoomBloc: Host missing or left. I am the new host: $newHostId',
              );
              _reassignHost(roomId, newHostId).catchError((e) {
                print('RoomBloc: Failed to reassign host: $e');
              });
            }
          }
        }

        add(
          RoomUpdated(
            roomId: roomId,
            participants: participants,
            userNames: roomEntity.users,
            driveFileId: roomEntity.driveFileId,
            driveFileName: roomEntity.driveFileName,
            driveFileSize: roomEntity.driveFileSize,
            hostId: hostId,
            isPlaying: roomEntity.isPlaying,
            position: roomEntity.position,
            updatedBy: roomEntity.updatedBy,
            lastUpdatedAt: roomEntity.lastUpdatedAt,
            speed: roomEntity.speed,
            selectedAudioTrack: roomEntity.selectedAudioTrack,
            selectedSubtitleTrack: roomEntity.selectedSubtitleTrack,
            armchairStyle: roomEntity.armchairStyle,
          ),
        );
      },
      onError: (error) {
        print('RoomBloc: Error observing room: $error');
      },
    );
  }

  void _onRoomUpdated(RoomUpdated event, Emitter<RoomState> emit) {
    final uid = _currentUserId ?? '';

    // If we are not in a room-related state, ignore updates
    if (state is! RoomJoined &&
        state is! RoomCreated &&
        state is! RoomLoading) {
      return;
    }

    final List<String> oldParticipants = state is RoomJoined
        ? (state as RoomJoined).participants
        : [];

    final currentRoomId = event.roomId;
    final newParticipants = event.participants;
    final userNames = event.userNames;
    String? notification;

    // Detect join/leave for notification
    for (final participant in newParticipants) {
      if (!oldParticipants.contains(participant)) {
        final userName = userNames[participant] ?? participant;
        notification = '$userName odaya katıldı';
        break;
      }
    }

    if (notification == null) {
      for (final participant in oldParticipants) {
        if (!newParticipants.contains(participant)) {
          final userName = userNames[participant] ?? participant;
          notification = '$userName odadan ayrıldı';
          break;
        }
      }
    }

    emit(
      RoomJoined(
        currentRoomId,
        userId: uid,
        participants: newParticipants,
        userNames: event.userNames,
        notificationMessage: notification,
        driveFileId: event.driveFileId,
        driveFileName: event.driveFileName,
        driveFileSize: event.driveFileSize,
        hostId: event.hostId,
        isPlaying: event.isPlaying,
        position: event.position,
        updatedBy: event.updatedBy,
        lastUpdatedAt: event.lastUpdatedAt,
        speed: event.speed,
        selectedAudioTrack: event.selectedAudioTrack,
        selectedSubtitleTrack: event.selectedSubtitleTrack,
        armchairStyle: event.armchairStyle,
      ),
    );
  }

  Future<void> _onUpdateRoomVideoRequested(
    UpdateRoomVideoRequested event,
    Emitter<RoomState> emit,
  ) async {
    try {
      await _updateRoomVideo(
        roomId: event.roomId,
        fileId: event.fileId,
        fileName: event.fileName,
        fileSize: event.fileSize,
      );
    } catch (e) {
      emit(RoomError('Failed to update room video: $e'));
    }
  }

  Future<void> _onSyncVideoAction(
    SyncVideoAction event,
    Emitter<RoomState> emit,
  ) async {
    try {
      await _syncVideo(
        roomId: event.roomId,
        isPlaying: event.isPlaying,
        position: event.position,
        userId: event.userId,
      );
    } catch (e) {
      print('RoomBloc: Error syncing video: $e');
      if (state is RoomJoined) {
        final currentState = state as RoomJoined;
        emit(
          currentState.copyWith(
            notificationMessage: 'Senkronizasyon hatası (Yetki?): $e',
          ),
        );
      }
    }
  }

  Future<void> _onSyncSettingsAction(
    SyncSettingsAction event,
    Emitter<RoomState> emit,
  ) async {
    try {
      await _syncSettings(
        roomId: event.roomId,
        speed: event.speed,
        audioTrack: event.audioTrack,
        subtitleTrack: event.subtitleTrack,
        userId: event.userId,
      );
    } catch (e) {
      print('RoomBloc: Error syncing settings: $e');
    }
  }
}
