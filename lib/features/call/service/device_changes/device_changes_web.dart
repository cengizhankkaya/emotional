import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Calls [onChange] whenever the set of media devices changes; returns a
/// function that stops listening.
void Function() listenForDeviceChanges(void Function() onChange) {
  final listener = (web.Event _) {
    onChange();
  }.toJS;
  final devices = web.window.navigator.mediaDevices;
  devices.addEventListener('devicechange', listener);
  return () => devices.removeEventListener('devicechange', listener);
}
