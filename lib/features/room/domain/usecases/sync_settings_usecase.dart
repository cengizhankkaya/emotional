import '../repositories/room_repository.dart';

class SyncSettingsUseCase {
  final RoomRepository _repository;

  SyncSettingsUseCase(this._repository);

  Future<void> call({
    required String roomId,
    String? userId,
    double? speed,
    String? audioTrack,
    String? subtitleTrack,
  }) {
    // userId might be needed for 'updatedBy' field
    return _repository.updateRoomSettings(
      roomId,
      speed,
      audioTrack,
      subtitleTrack,
      userId ?? '',
    );
  }
}
