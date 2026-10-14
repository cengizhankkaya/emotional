import 'package:emotional/features/chat/data/message_model.dart';
import 'package:firebase_database/firebase_database.dart';

class ChatRepository {
  /// How many of the latest messages a room keeps on screen.
  static const int historyLimit = 200;

  final FirebaseDatabase _database;

  ChatRepository({FirebaseDatabase? database})
    : _database = database ?? FirebaseDatabase.instance;

  Future<void> sendMessage(
    String roomId,
    String text,
    String userId,
    String userName,
  ) async {
    final messagesRef = _database.ref('rooms/$roomId/messages');
    final newMessageRef = messagesRef.push();

    final message = ChatMessage(
      id: newMessageRef
          .key!, // Actually this ID is not used in payload usually, but good to have
      roomId: roomId,
      senderId: userId,
      senderName: userName,
      text: text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    // Server time, so devices with skewed clocks still agree on the order.
    await newMessageRef.set({
      ...message.toJson(),
      'timestamp': ServerValue.timestamp,
    });
  }

  Stream<List<ChatMessage>> streamMessages(String roomId) {
    final messagesRef = _database.ref('rooms/$roomId/messages');

    // Push keys are chronological, so ordering by key needs no index and
    // lets the server send only the latest messages.
    return messagesRef.orderByKey().limitToLast(historyLimit).onValue.map((
      event,
    ) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];

      final List<ChatMessage> messages = [];
      data.forEach((key, value) {
        if (value is Map<dynamic, dynamic>) {
          messages.add(ChatMessage.fromMap(key.toString(), value));
        }
      });

      // Map iteration order isn't guaranteed; the key breaks timestamp ties.
      messages.sort((a, b) {
        final byTime = a.timestamp.compareTo(b.timestamp);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
      return messages;
    });
  }
}
