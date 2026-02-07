import '../repositories/room_repository.dart';

class JoinRoomUseCase {
  final RoomRepository _repository;

  JoinRoomUseCase(this._repository);

  Future<void> call(String roomId, String userId, String userName) {
    return _repository.joinRoom(roomId, userId, userName);
  }
}
