import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Some browsers (iPhone Safari) have no element fullscreen; the app's own
/// fullscreen layout still works there.
Future<void> enterBrowserFullscreen() async {
  if (isBrowserFullscreen) return;
  try {
    await web.document.documentElement?.requestFullscreen().toDart;
  } catch (e) {
    debugPrint('[BrowserFullscreen] Not available: $e');
  }
}

Future<void> exitBrowserFullscreen() async {
  if (!isBrowserFullscreen) return;
  try {
    await web.document.exitFullscreen().toDart;
  } catch (e) {
    debugPrint('[BrowserFullscreen] Could not exit: $e');
  }
}

bool get isBrowserFullscreen => web.document.fullscreenElement != null;

/// Fires with the new state, also when the user leaves with Esc (which
/// never reaches Flutter).
Stream<bool> get onBrowserFullscreenChange => _changes.stream;

final StreamController<bool> _changes = StreamController<bool>.broadcast(
  onListen: _listen,
);

bool _listening = false;

void _listen() {
  if (_listening) return;
  _listening = true;
  web.document.addEventListener(
    'fullscreenchange',
    (web.Event _) {
      _changes.add(isBrowserFullscreen);
    }.toJS,
  );
}
