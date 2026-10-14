import 'dart:async';

import 'package:emotional/features/chat/bloc/chat_bloc.dart';
import 'package:emotional/features/chat/data/message_model.dart';
import 'package:emotional/features/chat/repository/chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeChatRepository implements ChatRepository {
  final controller = StreamController<List<ChatMessage>>.broadcast();
  int subscriptions = 0;
  bool failSends = false;

  @override
  Stream<List<ChatMessage>> streamMessages(String roomId) {
    subscriptions++;
    return controller.stream;
  }

  @override
  Future<void> sendMessage(
    String roomId,
    String text,
    String userId,
    String userName,
  ) async {
    if (failSends) throw Exception('offline');
  }
}

ChatMessage _message(String id) => ChatMessage(
  id: id,
  roomId: 'room',
  senderId: 'u1',
  senderName: 'User',
  text: 'hello $id',
  timestamp: 1,
);

void main() {
  late _FakeChatRepository repository;
  late ChatBloc bloc;

  setUp(() {
    repository = _FakeChatRepository();
    bloc = ChatBloc(chatRepository: repository);
  });

  tearDown(() => bloc.close());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('loading the same room again keeps the list and subscription', () async {
    bloc.add(const LoadMessages('room'));
    await settle();
    repository.controller.add([_message('a')]);
    await settle();
    expect(bloc.state, isA<ChatLoaded>());

    final states = <ChatState>[];
    final sub = bloc.stream.listen(states.add);
    bloc.add(const LoadMessages('room'));
    await settle();
    await sub.cancel();

    expect(repository.subscriptions, 1);
    expect(states, isEmpty);
    expect((bloc.state as ChatLoaded).messages.single.id, 'a');
  });

  test('a different room subscribes again', () async {
    bloc.add(const LoadMessages('room'));
    await settle();
    bloc.add(const LoadMessages('other'));
    await settle();
    expect(repository.subscriptions, 2);
  });

  test('a failed send keeps the messages on screen', () async {
    bloc.add(const LoadMessages('room'));
    await settle();
    repository.controller.add([_message('a')]);
    await settle();

    repository.failSends = true;
    for (var i = 0; i < 2; i++) {
      bloc.add(
        const SendMessage(
          roomId: 'room',
          text: 'hi',
          userId: 'u1',
          userName: 'User',
        ),
      );
      await settle();
      final state = bloc.state as ChatLoaded;
      expect(state.messages.single.id, 'a');
      expect(state.sendError, isNotNull);
      expect(state.sendErrorId, i + 1);
    }
  });
}
