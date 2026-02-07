import '../repositories/room_repository.dart';

class LeaveRoomUseCase {
  final RoomRepository _repository;

  LeaveRoomUseCase(this._repository);

  Future<void> call(String roomId, String userId) {
    return _repository.leaveRoom(roomId, userId);
  }
}
