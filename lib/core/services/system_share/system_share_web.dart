import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

bool get canUseSystemShare {
  final navigator = web.window.navigator;
  if (!navigator.has('share') || !navigator.has('canShare')) return false;
  try {
    return navigator.canShare(web.ShareData(text: 'Emoti'));
  } catch (_) {
    return false;
  }
}
