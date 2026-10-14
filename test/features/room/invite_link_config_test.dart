@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:emotional/features/room/presentation/invite/room_invite.dart';
import 'package:flutter_test/flutter_test.dart';

/// The invite link only works if the text people send, the landing page
/// and the apps' link settings agree with what RoomInvite reads.
void main() {
  test('the invite text in every language links back to the room', () {
    for (final language in ['tr', 'en']) {
      final translations =
          jsonDecode(
                File('assets/translations/$language.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final template =
          (translations['room'] as Map<String, dynamic>)['inviteMessage']
              as String;
      final message = template.replaceAll('{}', '482913');
      final links = RegExp(r'\S+://\S+').allMatches(message).toList();
      expect(links, isNotEmpty, reason: '$language invite has no link');
      for (final link in links) {
        final uri = Uri.parse(link.group(0)!);
        expect(uri.host, RoomInvite.landingHost, reason: language);
        expect(RoomInvite.roomIdFrom(uri), '482913', reason: '$language: $uri');
      }
    }
  });

  test('the landing page sends app users to a scheme the apps open', () {
    final landing = File('public/index.html').readAsStringSync();
    final scheme = RegExp(r'"(\w+)://"').firstMatch(landing)?.group(1);
    expect(scheme, isNotNull);
    expect(RoomInvite.appSchemes, contains(scheme));

    final android = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(android, contains('android:scheme="$scheme"'));
    expect(android, contains('android:host="${RoomInvite.landingHost}"'));

    // Without it the iPhone app never opened from an invite.
    final ios = File('ios/Runner/Info.plist').readAsStringSync();
    expect(ios, contains('<string>$scheme</string>'));
  });

  test("the landing page's browser button goes to the web app", () {
    final landing = File('public/index.html').readAsStringSync();
    expect(landing, contains('https://${RoomInvite.webAppHost}/'));
  });

  test('the web app is the hosting site the links name', () {
    final firebaserc =
        jsonDecode(File('.firebaserc').readAsStringSync())
            as Map<String, dynamic>;
    final hosting =
        ((firebaserc['targets'] as Map).values.first as Map)['hosting'] as Map;
    final webSite = (hosting['web'] as List).single as String;
    final landingSite = (hosting['landing'] as List).single as String;
    expect(RoomInvite.webAppHost, '$webSite.web.app');
    expect(RoomInvite.landingHost, '$landingSite.web.app');
  });
}
