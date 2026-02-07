import '../entities/room_entity.dart';

abstract class RoomRepository {
  Future<String> createRoom(String userId, String userName);

  Future<void> joinRoom(String roomId, String userId, String userName);

  Future<void> leaveRoom(String roomId, String userId);

  Stream<RoomEntity?> streamRoom(String roomId);

  Future<void> updateRoomVideo(
    String roomId,
    String fileId,
    String fileName,
    String fileSize,
  );

  Future<void> updateVideoState(
    String roomId,
    bool isPlaying,
    int position,
    String userId,
  );

  Future<void> updateRoomSettings(
    String roomId,
    double? speed,
    String? audioTrack,
    String? subtitleTrack,
    String userId,
  );

  Future<void> reassignHost(String roomId, String newHostId);

  Future<void> cleanupEmptyRooms();

  Future<void> updateUserMediaState(
    String roomId,
    String userId, {
    required bool isVideoEnabled,
    required bool isAudioEnabled,
  });

  Future<void> updateArmchairStyle(String roomId, String styleName);
}
