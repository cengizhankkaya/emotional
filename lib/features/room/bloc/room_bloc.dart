import 'dart:async';

import 'package:emotional/features/room/repository/room_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'room_event.dart';
part 'room_state.dart';

class RoomBloc extends Bloc<RoomEvent, RoomState> {
  final RoomRepository _roomRepository;
  StreamSubscription? _roomSubscription;
  String? _currentUserId;

  RoomBloc({required RoomRepository roomRepository})
    : _roomRepository = roomRepository,
      super(RoomInitial()) {
    on<CreateRoomRequested>(_onCreateRoomRequested);
    on<JoinRoomRequested>(_onJoinRoomRequested);
    on<LeaveRoomRequested>(_onLeaveRoomRequested);
    on<RoomUpdated>(_onRoomUpdated);
    on<UpdateRoomVideoRequested>(_onUpdateRoomVideoRequested);
    on<SyncVideoAction>(_onSyncVideoAction);
    on<SyncSettingsAction>(_onSyncSettingsAction);
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
    print(
      'RoomBloc: CreateRoomRequested for user ${event.userId}, name: ${event.userName}',
    );
    emit(RoomLoading());
    try {
      _currentUserId = event.userId;
      print('RoomBloc: Calling repository.createRoom...');
      final roomId = await _roomRepository.createRoom(
        event.userId,
        event.userName,
      );
      print('RoomBloc: Room created successfully with ID: $roomId');
      emit(RoomCreated(roomId, event.userId));
      _subscribeToRoom(roomId);
    } catch (e) {
      print('RoomBloc: Error creating room: $e');
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
      await _roomRepository.joinRoom(
        event.roomId,
        event.userId,
        event.userName,
      );
      _subscribeToRoom(event.roomId);
    } catch (e) {
      emit(RoomError(e.toString()));
    }
  }

  Future<void> _onLeaveRoomRequested(
    LeaveRoomRequested event,
    Emitter<RoomState> emit,
  ) async {
    try {
      await _roomRepository.leaveRoom(event.roomId, event.userId);
      _roomSubscription?.cancel();
      _currentUserId = null;
      emit(RoomInitial());
    } catch (e) {
      emit(RoomError('Failed to leave room: $e'));
    }
  }

  void _subscribeToRoom(String roomId) {
    _roomSubscription?.cancel();
    _roomSubscription = _roomRepository
        .streamRoom(roomId)
        .listen(
          (event) {
            final data = event.snapshot.value as Map<dynamic, dynamic>?;
            if (data != null && data['users'] != null) {
              final usersMap = data['users'] as Map<dynamic, dynamic>;
              final participants = usersMap.values
                  .map((e) => e.toString())
                  .toList();

              final driveFileId = data['driveFileId'] as String?;
              final driveFileName = data['driveFileName'] as String?;
              final driveFileSize = data['driveFileSize'] as String?;
              final hostId = data['host'] as String? ?? '';

              final videoState = data['videoState'] as Map<dynamic, dynamic>?;
              final isPlaying = videoState?['isPlaying'] as bool? ?? false;
              final position = videoState?['position'] as int? ?? 0;
              final updatedBy = videoState?['updatedBy'] as String?;
              final lastUpdatedAt = videoState?['updatedAt'] as int? ?? 0;
              final speed = (videoState?['speed'] as num?)?.toDouble() ?? 1.0;
              final audioTrack = videoState?['audioTrack'] as String?;
              final subtitleTrack = videoState?['subtitleTrack'] as String?;

              add(
                RoomUpdated(
                  roomId: roomId,
                  participants: participants,
                  driveFileId: driveFileId,
                  driveFileName: driveFileName,
                  driveFileSize: driveFileSize,
                  hostId: hostId,
                  isPlaying: isPlaying,
                  position: position,
                  updatedBy: updatedBy,
                  lastUpdatedAt: lastUpdatedAt,
                  speed: speed,
                  selectedAudioTrack: audioTrack,
                  selectedSubtitleTrack: subtitleTrack,
                ),
              );
            }
          },
          onError: (error) {
            print('RoomBloc: Error observing room: $error');
            // We can't emit State here directly, we use add event.
            // But we need to handle error state?
            // Existing code added RoomUpdated with empty participants.
            // We need to keep doing valid logic.
            add(
              RoomUpdated(roomId: roomId, participants: const [], hostId: ''),
            );
          },
        );
  }

  void _onRoomUpdated(RoomUpdated event, Emitter<RoomState> emit) {
    // If _currentUserId is somehow null (restore from kill?), we have an issue.
    // For now assume it's set. If null, we might default to '' or handle error.
    final uid = _currentUserId ?? '';

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
    String? notification;

    for (final participant in newParticipants) {
      if (!oldParticipants.contains(participant)) {
        notification = '$participant odaya katıldı';
        break;
      }
    }

    if (notification == null) {
      for (final participant in oldParticipants) {
        if (!newParticipants.contains(participant)) {
          notification = '$participant odadan ayrıldı';
          break;
        }
      }
    }

    emit(
      RoomJoined(
        currentRoomId,
        userId: uid,
        participants: newParticipants,
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
      ),
    );
  }

  Future<void> _onUpdateRoomVideoRequested(
    UpdateRoomVideoRequested event,
    Emitter<RoomState> emit,
  ) async {
    try {
      await _roomRepository.updateRoomVideo(
        event.roomId,
        event.fileId,
        event.fileName,
        event.fileSize,
      );
    } catch (e) {
      emit(RoomError('Failed to update room video: $e'));
    }
  }

  Future<void> _onSyncVideoAction(
    SyncVideoAction event,
    Emitter<RoomState> emit,
  ) async {
    print(
      'DEBUG: RoomBloc: Received SyncVideoAction. Updating Firebase... isPlaying: ${event.isPlaying}',
    );
    try {
      await _roomRepository.updateVideoState(
        event.roomId,
        event.isPlaying,
        event.position,
        event.userId,
      );
      print('DEBUG: RoomBloc: Firebase update completed successfully.');
    } catch (e) {
      print('RoomBloc: Error syncing video: $e');
      // If we are in RoomJoined state, emit an error notification
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
      await _roomRepository.updateRoomSettings(
        event.roomId,
        event.speed,
        event.audioTrack,
        event.subtitleTrack,
        event.userId,
      );
    } catch (e) {
      print('RoomBloc: Error syncing settings: $e');
    }
  }
}
