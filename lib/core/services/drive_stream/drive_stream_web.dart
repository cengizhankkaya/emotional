import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

@JS('emotiDriveStreamReady')
external JSPromise<JSAny?> get _driveStreamReady;

/// Fail instead of leaving the player spinning if the worker never takes
/// control of the page.
const Duration _readyTimeout = Duration(seconds: 10);

/// Waits until `drive_stream_sw.js` (registered in web/index.html) controls
/// the page, so `drive-stream/` URLs are intercepted.
Future<void> ensureDriveStreamReady() async {
  await _driveStreamReady.toDart.timeout(_readyTimeout);
}

/// Hands a renewed Drive token (or null on sign-out) to the worker, so a
/// video that is already playing keeps loading after the old one expires.
void publishDriveStreamToken(String? token, DateTime? expiry) {
  final controller = _serviceWorkers?.controller;
  if (controller == null) return;
  controller.postMessage(
    {
      'type': 'drive-token',
      'token': token,
      'expiresAt': expiry?.millisecondsSinceEpoch,
    }.jsify(),
  );
}

/// Fires when the worker has no valid token for a running stream.
Stream<void> get driveStreamTokenRequests => _tokenRequests.stream;

final StreamController<void> _tokenRequests = StreamController<void>.broadcast(
  onListen: _listenToWorker,
);

bool _listening = false;

void _listenToWorker() {
  final serviceWorkers = _serviceWorkers;
  if (_listening || serviceWorkers == null) return;
  _listening = true;
  serviceWorkers.addEventListener(
    'message',
    (web.MessageEvent event) {
      final data = event.data.dartify();
      if (data is Map && data['type'] == 'drive-token-needed') {
        _tokenRequests.add(null);
      }
    }.toJS,
  );
}

/// Where relative app URLs resolve: the page's `<base href>` (also the
/// worker's scope), not the current address, which is e.g. /join/123 after
/// opening an invite.
Uri get documentBaseUri => Uri.parse(web.document.baseURI);

/// Whether this browser has any chance of playing [mimeType]. Browsers
/// answer "maybe" for most containers and "" only for ones they don't know,
/// though Chrome still plays many MOV/MKV files it calls unknown.
bool browserMayPlay(String mimeType) =>
    (_probe ??= web.HTMLVideoElement()).canPlayType(mimeType).isNotEmpty;

web.HTMLVideoElement? _probe;

/// Missing on insecure origins and in some private modes.
web.ServiceWorkerContainer? get _serviceWorkers {
  final navigator = web.window.navigator;
  return navigator.has('serviceWorker') ? navigator.serviceWorker : null;
}
