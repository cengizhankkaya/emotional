import 'package:equatable/equatable.dart';

class UserMediaState extends Equatable {
  final bool isVideoEnabled;
  final bool isAudioEnabled;
  final bool isScreenSharing; // New field
  final int lastUpdatedAt;

  const UserMediaState({
    required this.isVideoEnabled,
    required this.isAudioEnabled,
    this.isScreenSharing = false, // Default to false
    required this.lastUpdatedAt,
  });

  @override
  List<Object?> get props => [
    isVideoEnabled,
    isAudioEnabled,
    isScreenSharing,
    lastUpdatedAt,
  ];
}

class RoomEntity extends Equatable {
  final String id;
  final String hostId;
  final Map<String, String> users; // userId -> userName
  final Map<String, UserMediaState> usersState; // userId -> State
  final String status;
  final String? driveFileId;
  final String? driveFileName;
  final String? driveFileSize;
  final bool isPlaying;
  final int position;
  final String? updatedBy;
  final int lastUpdatedAt;
  final double speed;
  final String? selectedAudioTrack;
  final String? selectedSubtitleTrack;
  final String? armchairStyle;

  const RoomEntity({
    required this.id,
    required this.hostId,
    required this.users,
    this.usersState = const {},
    required this.status,
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
    id,
    hostId,
    users,
    usersState,
    status,
    driveFileId,
    driveFileName,
    driveFileSize,
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
