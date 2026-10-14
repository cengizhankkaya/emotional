part of 'chat_bloc.dart';

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object> get props => [];
}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatLoaded extends ChatState {
  final List<ChatMessage> messages;

  /// Set once when sending failed; the list stays on screen.
  final String? sendError;

  /// Makes repeated identical errors distinct states.
  final int sendErrorId;

  const ChatLoaded(this.messages, {this.sendError, this.sendErrorId = 0});

  @override
  List<Object> get props => [messages, sendError ?? '', sendErrorId];
}

class ChatError extends ChatState {
  final String message;

  const ChatError(this.message);

  @override
  List<Object> get props => [message];
}
