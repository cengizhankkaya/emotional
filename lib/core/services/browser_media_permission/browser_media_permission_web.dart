import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'browser_media_permission_state.dart';

export 'browser_media_permission_state.dart';

/// Whether a call can start, without prompting. Calls only need the
/// microphone; the camera is asked for when the user turns it on.
///
/// Firefox can't query the microphone and Safari forgets the choice between
/// visits; both report [BrowserMediaPermission.prompt].
Future<BrowserMediaPermission> queryBrowserMediaPermission() async {
  final microphone = await _query('microphone');
  if (microphone == 'denied') return BrowserMediaPermission.denied;
  if (microphone == 'granted') return BrowserMediaPermission.granted;
  return BrowserMediaPermission.prompt;
}

Future<String?> _query(String name) async {
  try {
    final status = await web.window.navigator.permissions
        .query(_PermissionDescriptor(name: name))
        .toDart;
    return status.state;
  } catch (_) {
    return null;
  }
}

/// Asks for camera and microphone in one browser prompt, then releases the
/// devices again; the call opens them itself. Only the microphone is
/// required: a missing or blocked camera still lets the call start.
Future<BrowserMediaPermission> requestBrowserMediaPermission() async {
  final both = await _open(audio: true, video: true);
  if (both == _OpenResult.ok) return BrowserMediaPermission.granted;

  // No webcam, or the camera was refused: the microphone decides.
  final microphone = await _open(audio: true, video: false);
  return microphone.permission;
}

enum _OpenResult {
  ok(BrowserMediaPermission.granted),
  blocked(BrowserMediaPermission.denied),
  missingDevice(BrowserMediaPermission.noDevice);

  const _OpenResult(this.permission);
  final BrowserMediaPermission permission;
}

Future<_OpenResult> _open({required bool audio, required bool video}) async {
  try {
    final stream = await web.window.navigator.mediaDevices
        .getUserMedia(
          web.MediaStreamConstraints(audio: audio.toJS, video: video.toJS),
        )
        .toDart;
    for (final track in stream.getTracks().toDart) {
      track.stop();
    }
    return _OpenResult.ok;
  } catch (error) {
    final name = _errorName(error);
    debugPrint('BrowserMediaPermission: getUserMedia failed: $name');
    return name == 'NotFoundError' || name == 'OverconstrainedError'
        ? _OpenResult.missingDevice
        // NotAllowedError, or the device is busy / unusable.
        : _OpenResult.blocked;
  }
}

/// The DOMException name, e.g. `NotAllowedError`.
String _errorName(Object error) {
  final jsError = error as JSAny?;
  if (jsError.isA<web.DOMException>()) {
    return (jsError as web.DOMException).name;
  }
  return '$error';
}

bool get isSafariBrowser {
  final agent = web.window.navigator.userAgent;
  return agent.contains('Safari') &&
      !agent.contains('Chrome') &&
      !agent.contains('Chromium') &&
      !agent.contains('Edg');
}

void reloadPage() => web.window.location.reload();

extension type _PermissionDescriptor._(JSObject _) implements JSObject {
  external factory _PermissionDescriptor({required String name});
}
