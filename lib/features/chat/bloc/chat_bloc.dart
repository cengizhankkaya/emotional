import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
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

  /// Room the subscription is for; repeat loads for it are ignored so the
  /// list doesn't flash back to a spinner on every room update.
  String? _roomId;
  int _sendErrorCount = 0;

  ChatBloc({required ChatRepository chatRepository})
    : _chatRepository = chatRepository,
      super(ChatInitial()) {
    on<LoadMessages>(_onLoadMessages);
    on<SendMessage>(_onSendMessage);
    on<MessagesUpdated>(_onMessagesUpdated);
    on<_MessagesFailed>(_onMessagesFailed);
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
    final alreadyListening =
        event.roomId == _roomId &&
        _messagesSubscription != null &&
        state is! ChatError;
    if (alreadyListening) return;

    _roomId = event.roomId;
    emit(ChatLoading());
    await _messagesSubscription?.cancel();
    _messagesSubscription = _chatRepository
        .streamMessages(event.roomId)
        .listen(
          (messages) => add(MessagesUpdated(messages)),
          onError: (Object error) {
            final message = error.toString();
            // Permission denied happens during logout; don't show it, but
            // drop the dead listener so the next join subscribes again.
            final silent =
                message.contains('permission-denied') ||
                message.contains('Client is offline');
            add(_MessagesFailed(message, silent: silent));
          },
        );
  }

  void _onMessagesFailed(_MessagesFailed event, Emitter<ChatState> emit) {
    // Next LoadMessages for the same room should subscribe again.
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _roomId = null;
    if (!event.silent) emit(ChatError(event.message));
  }

  /// Reports a failed send without hiding the conversation.
  void _emitSendError(String message, Emitter<ChatState> emit) {
    final current = state;
    if (current is ChatLoaded) {
      emit(
        ChatLoaded(
          current.messages,
          sendError: message,
          sendErrorId: ++_sendErrorCount,
        ),
      );
    } else {
      emit(ChatError(message));
    }
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
        _emitSendError(LocaleKeys.moderation_filter_blocked.tr(), emit);
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
      _emitSendError(
        LocaleKeys.chat_error_sendFailed.tr(args: [e.toString()]),
        emit,
      );
    }
  }

  void _onMessagesUpdated(MessagesUpdated event, Emitter<ChatState> emit) {
    emit(ChatLoaded(event.messages));
  }
}
