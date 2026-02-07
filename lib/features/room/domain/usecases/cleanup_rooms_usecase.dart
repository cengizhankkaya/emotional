import '../repositories/room_repository.dart';
// Note: You might need to add cleanupEmptyRooms to the interface first if not already there.
// Checking interface... I forgot to add it to the interface in Step 38!
// I need to update the interface first.

class CleanupRoomsUseCase {
  final RoomRepository _repository;

  CleanupRoomsUseCase(this._repository);

  Future<void> call() {
    // casting to dynamic to call the method if it's not in the interface yet,
    // OR better, update the interface. I will update the interface.
    // For now, assuming I will update the interface.
    return (_repository as dynamic).cleanupEmptyRooms();
  }
}
