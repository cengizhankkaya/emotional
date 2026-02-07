part of 'room_bloc.dart';

abstract class RoomState extends Equatable {
  const RoomState();

  @override
  List<Object?> get props => [];
}

class RoomInitial extends RoomState {
  const RoomInitial();
}

class RoomLoading extends RoomState {
  const RoomLoading();
}

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
  final Map<String, String> userNames; // userId -> userName mapping
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
  final String? armchairStyle;

  const RoomJoined(
    this.roomId, {
    required this.userId,
    this.participants = const [],
    this.userNames = const {},
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
    this.armchairStyle,
  });

  @override
  List<Object?> get props => [
    roomId,
    userId,
    participants,
    userNames,
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
    armchairStyle,
  ];

  RoomJoined copyWith({
    String? roomId,
    String? userId,
    List<String>? participants,
    Map<String, String>? userNames,
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
    String? armchairStyle,
  }) {
    return RoomJoined(
      roomId ?? this.roomId,
      userId: userId ?? this.userId,
      participants: participants ?? this.participants,
      userNames: userNames ?? this.userNames,
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
      armchairStyle: armchairStyle ?? this.armchairStyle,
    );
  }
}

class RoomError extends RoomState {
  final String message;

  const RoomError(this.message);

  @override
  List<Object> get props => [message];
}
