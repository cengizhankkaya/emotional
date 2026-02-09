part of 'room_bloc.dart';

abstract class RoomEvent extends Equatable {
  const RoomEvent();

  @override
  List<Object?> get props => [];
}

class CreateRoomRequested extends RoomEvent {
  final String userId;
  final String userName;

  const CreateRoomRequested(this.userId, this.userName);

  @override
  List<Object> get props => [userId, userName];
}

class JoinRoomRequested extends RoomEvent {
  final String roomId;
  final String userId;
  final String userName;

  const JoinRoomRequested({
    required this.roomId,
    required this.userId,
    required this.userName,
  });

  @override
  List<Object> get props => [roomId, userId, userName];
}

class LeaveRoomRequested extends RoomEvent {
  final String roomId;
  final String userId;

  const LeaveRoomRequested({required this.roomId, required this.userId});

  @override
  List<Object> get props => [roomId, userId];
}

class RoomUpdated extends RoomEvent {
  final String roomId;
  final List<String> participants;
  final Map<String, String> userNames; // userId -> userName mapping
  final Map<String, UserMediaState> usersState; // userId -> UserMediaState
  final String? driveFileId;
  final String? driveFileName;
  final String? driveFileSize;
  final String hostId;

  // New fields for video sync
  final bool isPlaying;
  final int position;
  final String? updatedBy;
  final int lastUpdatedAt;

  // Settings
  final double speed;
  final String? selectedAudioTrack;
  final String? selectedSubtitleTrack;
  final String? armchairStyle;

  const RoomUpdated({
    required this.roomId,
    required this.participants,
    this.userNames = const {},
    this.usersState = const {},
    required this.hostId,
    this.driveFileId,
    this.driveFileName,
    this.driveFileSize,
    this.isPlaying = false,
    this.position = 0,
    this.updatedBy,
    this.lastUpdatedAt = 0,
    this.speed = 1.0,
    this.selectedAudioTrack,
    this.selectedSubtitleTrack,
    this.armchairStyle,
  });

  @override
  List<Object?> get props => [
    roomId,
    participants,
    userNames,
    usersState,
    driveFileId,
    driveFileName,
    driveFileSize,
    hostId,
    isPlaying,
    position,
    updatedBy,
    lastUpdatedAt,
    speed,
    selectedAudioTrack,
    selectedSubtitleTrack,
    armchairStyle,
  ];
}

class SyncVideoAction extends RoomEvent {
  final String roomId;
  final bool isPlaying;
  final int position;
  final String userId;

  const SyncVideoAction({
    required this.roomId,
    required this.isPlaying,
    required this.position,
    required this.userId,
  });

  @override
  List<Object> get props => [roomId, isPlaying, position, userId];
}

class SyncSettingsAction extends RoomEvent {
  final String roomId;
  final double? speed;
  final String? audioTrack;
  final String? subtitleTrack;
  final String userId;

  const SyncSettingsAction({
    required this.roomId,
    this.speed,
    this.audioTrack,
    this.subtitleTrack,
    required this.userId,
  });

  @override
  List<Object?> get props => [roomId, speed, audioTrack, subtitleTrack, userId];
}

class UpdateRoomVideoRequested extends RoomEvent {
  final String roomId;
  final String fileId;
  final String fileName;
  final String fileSize;

  const UpdateRoomVideoRequested({
    required this.roomId,
    required this.fileId,
    required this.fileName,
    required this.fileSize,
  });

  @override
  List<Object> get props => [roomId, fileId, fileName, fileSize];
}

class TransferHostRequested extends RoomEvent {
  final String roomId;
  final String newHostId;

  const TransferHostRequested({required this.roomId, required this.newHostId});

  @override
  List<Object> get props => [roomId, newHostId];
}

class SetRoomAppBackgrounded extends RoomEvent {
  final bool isBackgrounded;
  const SetRoomAppBackgrounded(this.isBackgrounded);

  @override
  List<Object> get props => [isBackgrounded];
}
