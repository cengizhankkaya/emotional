import 'package:emotional/features/room/presentation/invite/room_invite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? read(String link, {String? ownHost}) =>
      RoomInvite.roomIdFrom(Uri.parse(link), ownHost: ownHost);

  group('reading an invite link', () {
    test('app links, both schemes (Android: emotional, iOS: emoti)', () {
      expect(read('emotional://join/123456'), '123456');
      expect(read('emoti://join/123456'), '123456');
      expect(read('emotional://room/123456'), '123456');
      expect(read('emotional://join?id=123456'), '123456');
      expect(read('emotional:///join/123456'), '123456');
    });

    test('web links: the landing page and the web app', () {
      expect(read('https://emotional-app-b42af.web.app/join/123456'), '123456');
      expect(read('https://emoti-izle.web.app/join/123456'), '123456');
      expect(read('http://emoti-izle.web.app/join/123456/'), '123456');
      expect(
        read('https://emoti-izle.web.app/join/123456?utm_source=whatsapp'),
        '123456',
      );
    });

    test('the page the web app runs on (preview channel)', () {
      const preview = 'emoti-izle--pr12-abc.web.app';
      expect(read('https://$preview/join/123456'), isNull);
      expect(read('https://$preview/join/123456', ownHost: preview), '123456');
    });

    test('anything else is not an invite', () {
      expect(read('https://evil.example/join/123456'), isNull);
      expect(read('https://emoti-izle.web.app/'), isNull);
      expect(read('https://emoti-izle.web.app/join/'), isNull);
      expect(read('https://emoti-izle.web.app/123456'), isNull);
      expect(read('emotional://home'), isNull);
      expect(read('emotional://join/12%2034'), isNull);
      expect(read('emotional://join/abc.def'), isNull);
      expect(read('mailto:someone@example.com'), isNull);
    });
  });

  test('the shared link reads back as the same room', () {
    for (final id in ['123456', '000001', 'Room_7']) {
      expect(read(RoomInvite.link(id).toString()), id);
      expect(read(RoomInvite.webAppLink(id).toString()), id);
    }
  });

  testWidgets(
    'browsers without a share sheet copy the link instead of mailto:',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => RoomInvite.share(
                  context,
                  '482913',
                  systemShareAvailable: false,
                ),
                child: const Text('invite'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('invite'));
      await tester.pumpAndSettle();

      expect(copied, 'https://emotional-app-b42af.web.app/join/482913');
      expect(find.text('room.inviteLinkCopied'), findsOneWidget);
    },
    // Phones always have a share sheet.
    skip: !kIsWeb,
  );
}
