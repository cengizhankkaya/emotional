import 'package:emotional/core/services/drive_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final expiry = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  test('builds the address the Drive streaming worker intercepts', () {
    expect(
      DriveService.buildWebStreamUrl(
        Uri.parse('https://emoti-izle.web.app/'),
        'abc123',
        'token',
        expiry,
      ),
      'https://emoti-izle.web.app/drive-stream/abc123?t=token&e=1700000000000',
    );
  });

  test('stays under the base, whatever page the app is on', () {
    // The worker's scope is the <base href>; resolving against the page
    // address instead gave /join/drive-stream/... after opening an invite.
    final url = Uri.parse(
      DriveService.buildWebStreamUrl(
        Uri.parse('https://emoti-izle.web.app/'),
        'abc',
        't',
        null,
      ),
    );
    expect(url.path, '/drive-stream/abc');

    final underPath = Uri.parse(
      DriveService.buildWebStreamUrl(
        Uri.parse('https://example.com/emoti/'),
        'abc',
        't',
        null,
      ),
    );
    expect(underPath.path, '/emoti/drive-stream/abc');
  });

  test('file ids and tokens are encoded', () {
    final url = Uri.parse(
      DriveService.buildWebStreamUrl(
        Uri.parse('https://emoti-izle.web.app/'),
        'a/b?c',
        'to&ken=',
        null,
      ),
    );
    expect(url.pathSegments.last, 'a/b?c');
    expect(url.pathSegments, hasLength(2), reason: 'one segment for the id');
    expect(url.queryParameters['t'], 'to&ken=');
    expect(url.queryParameters.containsKey('e'), isFalse);
  });
}
