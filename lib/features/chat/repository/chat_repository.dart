import 'package:emotional/features/chat/data/message_model.dart';
import 'package:firebase_database/firebase_database.dart';

class ChatRepository {
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

    await newMessageRef.set(message.toJson());
  }

  Stream<List<ChatMessage>> streamMessages(String roomId) {
    final messagesRef = _database.ref('rooms/$roomId/messages');

    // Order by timestamp implies we rely on push ID generating chronological order or we should use orderByChild
    // Firebase push keys are chronologically ordered.
    return messagesRef.orderByChild('timestamp').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];

      final List<ChatMessage> messages = [];
      data.forEach((key, value) {
        if (value is Map<dynamic, dynamic>) {
          messages.add(ChatMessage.fromMap(key.toString(), value));
        }
      });

      // Sort again locally just in case map iteration is unordered
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    });
  }
}
