part of 'room_bloc.dart';

abstract class RoomState extends Equatable {
  const RoomState();

  @override
  List<Object?> get props => [];
}

class RoomInitial extends RoomState {}

class RoomLoading extends RoomState {}

class RoomCreated extends RoomState {
  final String roomId;
  final String userId;

  const RoomCreated(this.roomId, this.userId);

  @override
  List<Object> get props => [roomId, userId];
}

class RoomJoined extends RoomState {
  final String roomId;
  final String userId;
  final List<String> participants;
  final String? notificationMessage;

  final String hostId;
  final String? driveFileId;
  final String? driveFileName;
  final String? driveFileSize;
  final bool isPlaying;
  final int position;
  final String? updatedBy;
  final int lastUpdatedAt;

  // New fields for settings sync
  final double speed;
  final String? selectedAudioTrack;
  final String? selectedSubtitleTrack;

  const RoomJoined(
    this.roomId, {
    required this.userId,
    this.participants = const [],
    this.notificationMessage,
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
  });

  @override
  List<Object?> get props => [
    roomId,
    userId,
    participants,
    notificationMessage,
    hostId,
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
  ];

  RoomJoined copyWith({
    String? roomId,
    String? userId,
    List<String>? participants,
    String? notificationMessage,
    String? hostId,
    String? driveFileId,
    String? driveFileName,
    String? driveFileSize,
    bool? isPlaying,
    int? position,
    String? updatedBy,
    int? lastUpdatedAt,
    double? speed,
    String? selectedAudioTrack,
    String? selectedSubtitleTrack,
  }) {
    return RoomJoined(
      roomId ?? this.roomId,
      userId: userId ?? this.userId,
      participants: participants ?? this.participants,
      notificationMessage: notificationMessage ?? this.notificationMessage,
      hostId: hostId ?? this.hostId,
      driveFileId: driveFileId ?? this.driveFileId,
      driveFileName: driveFileName ?? this.driveFileName,
      driveFileSize: driveFileSize ?? this.driveFileSize,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      updatedBy: updatedBy ?? this.updatedBy,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      speed: speed ?? this.speed,
      selectedAudioTrack: selectedAudioTrack ?? this.selectedAudioTrack,
      selectedSubtitleTrack:
          selectedSubtitleTrack ?? this.selectedSubtitleTrack,
    );
  }
}

class RoomError extends RoomState {
  final String message;

  const RoomError(this.message);

  @override
  List<Object> get props => [message];
}
