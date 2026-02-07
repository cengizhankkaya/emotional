import '../repositories/room_repository.dart';

class SyncVideoUseCase {
  final RoomRepository _repository;

  SyncVideoUseCase(this._repository);

  Future<void> call({
    required String roomId,
    required bool isPlaying,
    required int position,
    required String userId,
  }) {
    return _repository.updateVideoState(roomId, isPlaying, position, userId);
  }
}
