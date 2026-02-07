import '../repositories/room_repository.dart';

class UpdateRoomVideoUseCase {
  final RoomRepository _repository;

  UpdateRoomVideoUseCase(this._repository);

  Future<void> call({
    required String roomId,
    required String fileId,
    required String fileName,
    required String fileSize,
  }) {
    return _repository.updateRoomVideo(roomId, fileId, fileName, fileSize);
  }
}
