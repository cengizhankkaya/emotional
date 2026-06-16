import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/core/services/content_filter_service.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
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
          onError: (error) {
            // Ignore permission denied errors that happen during logout
            if (error.toString().contains('permission-denied') ||
                error.toString().contains('Client is offline')) {
              return;
            }
            emit(ChatError(error.toString()));
          },
        );
  }

  Future<void> _onSendMessage(
    SendMessage event,
    Emitter<ChatState> emit,
  ) async {
    try {
      final filter = ContentFilterService.instance;
      final text = event.text;

      // If the message is entirely profanity, block it
      if (filter.shouldBlockMessage(text)) {
        emit(
          ChatError(LocaleKeys.moderation_filter_blocked.tr()),
        );
        return;
      }

      // Mask partial profanity
      final filteredText = filter.filterText(text);

      await _chatRepository.sendMessage(
        event.roomId,
        filteredText,
        event.userId,
        event.userName,
      );
    } catch (e) {
      emit(
        ChatError(LocaleKeys.chat_error_sendFailed.tr(args: [e.toString()])),
      );
    }
  }

  void _onMessagesUpdated(MessagesUpdated event, Emitter<ChatState> emit) {
    emit(ChatLoaded(event.messages));
  }
}
