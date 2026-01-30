import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:emotional/features/chat/data/message_model.dart';
import 'package:emotional/features/chat/repository/chat_repository.dart';
import 'package:equatable/equatable.dart';

part 'chat_event.dart';
part 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository _chatRepository;
  StreamSubscription? _messagesSubscription;

  ChatBloc({required ChatRepository chatRepository})
    : _chatRepository = chatRepository,
      super(ChatInitial()) {
    on<LoadMessages>(_onLoadMessages);
    on<SendMessage>(_onSendMessage);
    on<MessagesUpdated>(_onMessagesUpdated);
  }

  @override
  Future<void> close() {
    _messagesSubscription?.cancel();
    return super.close();
  }

  Future<void> _onLoadMessages(
    LoadMessages event,
    Emitter<ChatState> emit,
  ) async {
    emit(ChatLoading());
    _messagesSubscription?.cancel();
    _messagesSubscription = _chatRepository
        .streamMessages(event.roomId)
        .listen(
          (messages) => add(MessagesUpdated(messages)),
          onError: (error) => emit(ChatError(error.toString())),
        );
  }

  Future<void> _onSendMessage(
    SendMessage event,
    Emitter<ChatState> emit,
  ) async {
    try {
      await _chatRepository.sendMessage(
        event.roomId,
        event.text,
        event.userId,
        event.userName,
      );
    } catch (e) {
      emit(ChatError('Failed to send message: $e'));
    }
  }

  void _onMessagesUpdated(MessagesUpdated event, Emitter<ChatState> emit) {
    emit(ChatLoaded(event.messages));
  }
}
