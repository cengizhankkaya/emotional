import 'dart:math';

import 'package:firebase_database/firebase_database.dart';

class RoomRepository {
  final FirebaseDatabase _database;

  RoomRepository({FirebaseDatabase? database})
    : _database = database ?? FirebaseDatabase.instance;

  Future<String> createRoom(String userId, String userName) async {
    final roomId = _generateRoomId();
    print(
      'RoomRepository: Generated room ID $roomId. Attempting to set data in DB...',
    );
    final roomRef = _database.ref('rooms/$roomId');

    try {
      await roomRef.set({
        'createdAt': ServerValue.timestamp,
        'host': userId,
        'users': {userId: userName},
        'status': 'waiting',
        'driveFileId': null,
        'driveFileName': null,
        'driveFileSize': null,
      });
      print('RoomRepository: Data written to DB successfully.');
    } catch (e) {
      print('RoomRepository: Failed to write to DB: $e');
      rethrow;
    }

    return roomId;
  }

  Future<void> joinRoom(String roomId, String userId, String userName) async {
    final roomRef = _database.ref('rooms/$roomId');
    final snapshot = await roomRef.get();

    if (snapshot.exists) {
      await roomRef.child('users/$userId').set(userName);
    } else {
      throw Exception('Room not found');
    }
  }

  Future<void> leaveRoom(String roomId, String userId) async {
    final roomRef = _database.ref('rooms/$roomId');

    // Use a transaction to ensure atomic update and cleanup
    await roomRef.runTransaction((Object? post) {
      if (post == null) {
        return Transaction.success(post);
      }

      final Map<dynamic, dynamic> roomData = post as Map<dynamic, dynamic>;
      final users = roomData['users'] as Map<dynamic, dynamic>? ?? {};

      if (users.containsKey(userId)) {
        users.remove(userId);
      }

      // If no users left, delete the room
      if (users.isEmpty) {
        // Return null to delete the node
        return Transaction.success(null);
      }

      // Update the user list
      roomData['users'] = users;
      return Transaction.success(roomData);
    });
  }

  Future<void> updateRoomVideo(
    String roomId,
    String fileId,
    String fileName,
    String fileSize,
  ) async {
    final roomRef = _database.ref('rooms/$roomId');
    await roomRef.update({
      'driveFileId': fileId,
      'driveFileName': fileName,
      'driveFileSize': fileSize,
      'status': 'picking_video',
    });
  }

  Future<void> updateVideoState(
    String roomId,
    bool isPlaying,
    int position,
    String userId,
  ) async {
    final roomRef = _database.ref('rooms/$roomId/videoState');
    await roomRef.update({
      'isPlaying': isPlaying,
      'position': position,
      'updatedBy': userId,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> updateRoomSettings(
    String roomId,
    double? speed,
    String? audioTrack,
    String? subtitleTrack,
    String userId,
  ) async {
    final roomRef = _database.ref('rooms/$roomId/videoState');
    final Map<String, dynamic> updates = {
      'updatedBy': userId,
      'updatedAt': ServerValue.timestamp,
    };

    if (speed != null) updates['speed'] = speed;
    if (audioTrack != null) updates['audioTrack'] = audioTrack;
    if (subtitleTrack != null) updates['subtitleTrack'] = subtitleTrack;

    await roomRef.update(updates);
  }

  Stream<DatabaseEvent> streamRoom(String roomId) {
    return _database.ref('rooms/$roomId').onValue;
  }

  String _generateRoomId() {
    // Generate a 6-digit random number string
    var rng = Random();
    return (100000 + rng.nextInt(900000)).toString();
  }
}
