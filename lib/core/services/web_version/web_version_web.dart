import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:emotional/product/utility/validator/app_build.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// The build the server hands out now, from the `version.json` that
/// `flutter build web` writes; null if it can't be read (offline).
Future<AppBuild?> fetchDeployedBuild() async {
  try {
    // Relative to <base href>; the query and no-store skip every cache.
    final response = await web.window
        .fetch(
          'version.json?t=${DateTime.now().millisecondsSinceEpoch}'.toJS,
          web.RequestInit(cache: 'no-store'),
        )
        .toDart;
    if (!response.ok) return null;
    final json = jsonDecode((await response.text().toDart).toDart);
    if (json is! Map) return null;
    return AppBuild.tryParse('${json['version']}', '${json['build_number']}');
  } catch (e) {
    debugPrint('[WebVersion] Could not read version.json: $e');
    return null;
  }
}

/// Fires when the tab comes back into view, e.g. after a night in the
/// background.
Stream<void> get onAppVisible => _visible.stream;

final StreamController<void> _visible = StreamController<void>.broadcast(
  onListen: _listen,
);

bool _listening = false;

void _listen() {
  if (_listening) return;
  _listening = true;
  web.document.addEventListener(
    'visibilitychange',
    (web.Event _) {
      if (web.document.visibilityState == 'visible') _visible.add(null);
    }.toJS,
  );
}

void reloadApp() => web.window.location.reload();
