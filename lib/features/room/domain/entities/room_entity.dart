import 'package:equatable/equatable.dart';

class UserMediaState extends Equatable {
  final bool isVideoEnabled;
  final bool isAudioEnabled;
  final bool isScreenSharing; // New field
  final bool isWatchingVideo; // New field for video watching status
  final int lastUpdatedAt;

  /// `ClientPlatform.name` the user joined from; null for older versions.
  final String? platform;

  /// Sharing their screen with the camera on: the camera goes out as a
  /// second video, to those who [acceptsShareCamera].
  final bool isShareCameraOn;

  /// Can show a sharer's camera next to the share. Older versions show one
  /// video per person and would swap the screen for the camera.
  final bool acceptsShareCamera;

  const UserMediaState({
    required this.isVideoEnabled,
    required this.isAudioEnabled,
    this.isScreenSharing = false, // Default to false
    this.isWatchingVideo = false, // Default to false
    required this.lastUpdatedAt,
    this.platform,
    this.isShareCameraOn = false,
    this.acceptsShareCamera = false,
  });

  @override
  List<Object?> get props => [
    isVideoEnabled,
    isAudioEnabled,
    isScreenSharing,
    isWatchingVideo,
    lastUpdatedAt,
    platform,
    isShareCameraOn,
    acceptsShareCamera,
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
