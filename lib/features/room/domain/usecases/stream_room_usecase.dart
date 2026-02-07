import '../entities/room_entity.dart';
import '../repositories/room_repository.dart';

class StreamRoomUseCase {
  final RoomRepository _repository;

  StreamRoomUseCase(this._repository);

  Stream<RoomEntity?> call(String roomId) {
    return _repository.streamRoom(roomId);
  }
}
