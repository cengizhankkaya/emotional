import 'package:firebase_database/firebase_database.dart';
import '../../domain/entities/room_entity.dart';
import '../../domain/repositories/room_repository.dart';
import 'dart:math';

class RoomRepositoryImpl implements RoomRepository {
  final FirebaseDatabase _database;

  RoomRepositoryImpl({FirebaseDatabase? database})
    : _database = database ?? FirebaseDatabase.instance;

  Future<void> _clearUserSignals(String roomId, String userId) async {
    final signalRef = _database.ref('rooms/$roomId/signal/$userId');
    await signalRef.remove();
  }

  @override
  Future<String> createRoom(String userId, String userName) async {
    final roomId = _generateRoomId();

    // Clear any residual signals for this user before creating/joining
    await _clearUserSignals(roomId, userId);

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

      // Set up onDisconnect to remove the user if the app crashes/disconnects
      // Set up onDisconnect to remove the user if the app crashes/disconnects
      await roomRef.child('users/$userId').onDisconnect().remove();

      // Cleanup signaling paths on disconnect
      final signalRef = _database.ref('rooms/$roomId/signal/$userId');
      await signalRef.onDisconnect().remove();

      print('RoomRepository: Data written to DB successfully.');
    } catch (e) {
      print('RoomRepository: Failed to write to DB: $e');
      rethrow;
    }

    return roomId;
  }

  @override
  Future<void> joinRoom(String roomId, String userId, String userName) async {
    // Clear signals BEFORE joining to ensure we don't delete offers that arrive as soon as we appear in the room list
    await _clearUserSignals(roomId, userId);

    final roomRef = _database.ref('rooms/$roomId');

    final result = await roomRef.runTransaction((Object? post) {
      if (post == null) {
        return Transaction.abort();
      }

      final Map<dynamic, dynamic> roomData = post as Map<dynamic, dynamic>;
      final users = roomData['users'] as Map<dynamic, dynamic>? ?? {};

      // Check if user is already in the room (avoid redundant joins)
      if (users.containsKey(userId)) {
        return Transaction.success(roomData);
      }

      users[userId] = userName;
      roomData['users'] = users;
      return Transaction.success(roomData);
    });

    if (!result.committed) {
      final snapshot = await roomRef.get();
      if (!snapshot.exists) {
        // Gerçek hata: oda gerçekten yoksa kullanıcıya bildir.
        throw Exception('Oda bulunamadı');
      }
      // Oda var ama transaction commit edilmediyse (geçici çakışma vb.)
      // kullanıcıya hata göstermeden sessizce çıkıyoruz; kullanıcı
      // yeniden denediğinde normal şekilde katılabilecek.
      return;
    }

    // Set up onDisconnect ONLY after successful transaction
    await roomRef.child('users/$userId').onDisconnect().remove();

    // Cleanup signaling paths on disconnect
    final signalRef = _database.ref('rooms/$roomId/signal/$userId');
    await signalRef.onDisconnect().remove();

    print(
      'RoomRepository: User $userId successfully joined via transaction and onDisconnect setup.',
    );
  }

  @override
  Future<void> leaveRoom(String roomId, String userId) async {
    final roomRef = _database.ref('rooms/$roomId');

    print('RoomRepository: User $userId is leaving room $roomId manually.');
    // Cancel the onDisconnect listener since we are leaving manually
    await roomRef.child('users/$userId').onDisconnect().cancel();

    final signalRef = _database.ref('rooms/$roomId/signal/$userId');
    await signalRef.onDisconnect().cancel();

    // Use a transaction to ensure atomic update and cleanup
    final result = await roomRef.runTransaction((Object? post) {
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
        return Transaction.success(null);
      }

      // If the leaving user was the host, assign a new one
      final currentHost = roomData['host'] as String?;
      if (currentHost == userId) {
        // Assign the first available user as the new host
        roomData['host'] = users.keys.first.toString();
      }

      // Update the user list
      roomData['users'] = users;
      return Transaction.success(roomData);
    });
    print(
      'RoomRepository: LeaveRoom transaction finished for $userId with result: ${result.committed}',
    );
  }

  @override
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

  @override
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

  @override
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

  @override
  Future<void> updateUserMediaState(
    String roomId,
    String userId, {
    required bool isVideoEnabled,
    required bool isAudioEnabled,
    required bool isScreenSharing,
    bool? isWatchingVideo,
  }) async {
    final userStateRef = _database.ref('rooms/$roomId/usersState/$userId');
    final Map<String, dynamic> updates = {
      'video': isVideoEnabled,
      'audio': isAudioEnabled,
      'screen': isScreenSharing,
      'updatedAt': ServerValue.timestamp,
    };

    if (isWatchingVideo != null) {
      updates['watching'] = isWatchingVideo;
    }

    await userStateRef.update(updates);
  }

  @override
  Future<void> updateArmchairStyle(String roomId, String styleName) async {
    final roomRef = _database.ref('rooms/$roomId');
    await roomRef.update({'armchairStyle': styleName});
  }

  @override
  Future<void> reassignHost(String roomId, String newHostId) async {
    final roomRef = _database.ref('rooms/$roomId');
    await roomRef.update({'host': newHostId});
  }

  @override
  Stream<RoomEntity?> streamRoom(String roomId) {
    return _database.ref('rooms/$roomId').onValue.map((event) {
      if (event.snapshot.value == null) return null;

      final data = event.snapshot.value as Map<dynamic, dynamic>;

      final usersMap = data['users'] as Map<dynamic, dynamic>? ?? {};
      final users = Map<String, String>.fromEntries(
        usersMap.entries.map(
          (e) => MapEntry(e.key.toString(), e.value.toString()),
        ),
      );

      final videoState = data['videoState'] as Map<dynamic, dynamic>?;
      final isPlaying = videoState?['isPlaying'] as bool? ?? false;
      final position = videoState?['position'] as int? ?? 0;
      final updatedBy = videoState?['updatedBy'] as String?;
      final lastUpdatedAt = videoState?['updatedAt'] as int? ?? 0;
      final speed = (videoState?['speed'] as num?)?.toDouble() ?? 1.0;
      final audioTrack = videoState?['audioTrack'] as String?;
      final subtitleTrack = videoState?['subtitleTrack'] as String?;

      final usersStateMap = data['usersState'] as Map<dynamic, dynamic>? ?? {};
      final usersState = <String, UserMediaState>{};
      usersStateMap.forEach((key, value) {
        final valMap = value as Map<dynamic, dynamic>;
        usersState[key.toString()] = UserMediaState(
          isVideoEnabled: valMap['video'] as bool? ?? false,
          isAudioEnabled: valMap['audio'] as bool? ?? false,
          isScreenSharing: valMap['screen'] as bool? ?? false,
          isWatchingVideo: valMap['watching'] as bool? ?? false,
          lastUpdatedAt: valMap['updatedAt'] as int? ?? 0,
        );
      });

      return RoomEntity(
        id: roomId,
        hostId: data['host'] as String? ?? '',
        users: users,
        usersState: usersState,
        status: data['status'] as String? ?? 'waiting',
        driveFileId: data['driveFileId'] as String?,
        driveFileName: data['driveFileName'] as String?,
        driveFileSize: data['driveFileSize'] as String?,
        isPlaying: isPlaying,
        position: position,
        updatedBy: updatedBy,
        lastUpdatedAt: lastUpdatedAt,
        speed: speed,
        selectedAudioTrack: audioTrack,
        selectedSubtitleTrack: subtitleTrack,
        armchairStyle: data['armchairStyle'] as String?,
      );
    });
  }

  String _generateRoomId() {
    // Generate a 6-digit random number string
    var rng = Random();
    return (100000 + rng.nextInt(900000)).toString();
  }
}
