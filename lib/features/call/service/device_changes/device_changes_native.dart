import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Calls [onChange] whenever the set of media devices changes; returns a
/// function that stops listening.
void Function() listenForDeviceChanges(void Function() onChange) {
  navigator.mediaDevices.ondevicechange = (_) => onChange();
  return () => navigator.mediaDevices.ondevicechange = null;
}
