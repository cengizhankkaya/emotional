part of 'chat_bloc.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object> get props => [];
}

class LoadMessages extends ChatEvent {
  final String roomId;

  const LoadMessages(this.roomId);

  @override
  List<Object> get props => [roomId];
}

class SendMessage extends ChatEvent {
  final String roomId;
  final String text;
  final String userId;
  final String userName;

  const SendMessage({
    required this.roomId,
    required this.text,
    required this.userId,
    required this.userName,
  });

  @override
  List<Object> get props => [roomId, text, userId, userName];
}

class MessagesUpdated extends ChatEvent {
  final List<ChatMessage> messages;

  const MessagesUpdated(this.messages);

  @override
  List<Object> get props => [messages];
}
