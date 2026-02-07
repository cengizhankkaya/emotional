import '../repositories/room_repository.dart';

class CreateRoomUseCase {
  final RoomRepository _repository;

  CreateRoomUseCase(this._repository);

  Future<String> call(String userId, String userName) {
    return _repository.createRoom(userId, userName);
  }
}
