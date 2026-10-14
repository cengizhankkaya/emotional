// Plugging in or removing a camera, microphone or headset. Browsers need
// the DOM event: dart_webrtc never fires `ondevicechange`.
export 'device_changes_native.dart'
    if (dart.library.js_interop) 'device_changes_web.dart';
