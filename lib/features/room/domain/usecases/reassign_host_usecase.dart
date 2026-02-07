import '../repositories/room_repository.dart';

class ReassignHostUseCase {
  final RoomRepository _repository;

  ReassignHostUseCase(this._repository);

  Future<void> call(String roomId, String newHostId) {
    return _repository.reassignHost(roomId, newHostId);
  }
}
