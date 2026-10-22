import 'dart:async';

import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/chat/bloc/chat_bloc.dart';
import 'package:emotional/features/chat/data/message_model.dart';
import 'package:emotional/features/chat/presentation/chat_widget.dart';
import 'package:emotional/features/chat/repository/chat_repository.dart';
import 'package:emotional/features/moderation/bloc/moderation_bloc.dart';
import 'package:emotional/features/moderation/repository/moderation_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'me';

  @override
  String? get displayName => 'Me';
}

class _FakeAuth extends Fake implements FirebaseAuth {
  @override
  Stream<User?> authStateChanges() => Stream.value(_FakeUser());
}

class _FakeModerationRepository extends Fake implements ModerationRepository {}

class _FakeChatRepository implements ChatRepository {
  final sent = <String>[];
  bool failSends = false;

  @override
  Stream<List<ChatMessage>> streamMessages(String roomId) =>
      Stream.value(const []);

  @override
  Future<void> sendMessage(
    String roomId,
    String text,
    String userId,
    String userName,
  ) async {
    if (failSends) throw Exception('offline');
    sent.add(text);
  }
}

Future<(Finder, _FakeChatRepository)> _pumpChat(WidgetTester tester) async {
  final repository = _FakeChatRepository();
  final auth = AuthBloc(firebaseAuth: _FakeAuth());
  final chat = ChatBloc(chatRepository: repository);
  final moderation = ModerationBloc(repository: _FakeModerationRepository());
  addTearDown(auth.close);
  addTearDown(chat.close);
  addTearDown(moderation.close);

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: auth),
        BlocProvider.value(value: chat),
        BlocProvider.value(value: moderation),
      ],
      child: const MaterialApp(
        home: Scaffold(body: ChatWidget(roomId: 'room', showHeader: false)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(auth.state, isA<AuthAuthenticated>());
  return (find.byType(TextField), repository);
}

void main() {
  testWidgets('a message that could not be sent goes back in the input', (
    tester,
  ) async {
    final (input, repository) = await _pumpChat(tester);
    repository.failSends = true;

    await tester.tap(input);
    await tester.enterText(input, 'hello');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(input);
    expect(field.controller!.text, 'hello');
    expect(field.controller!.selection.baseOffset, 5, reason: 'cursor at end');
  });

  testWidgets('the input keeps the focus after Enter sends a message', (
    tester,
  ) async {
    final (input, repository) = await _pumpChat(tester);
    await tester.tap(input);
    for (final text in ['first', 'second']) {
      await tester.enterText(input, text);
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(input).focusNode!.hasFocus,
        isTrue,
        reason: 'no click needed before "$text"\'s next message',
      );
      expect(tester.widget<TextField>(input).controller!.text, isEmpty);
    }
    expect(repository.sent, ['first', 'second']);
  });
}
