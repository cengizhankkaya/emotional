// Camera and microphone permission in the browser. Mobile builds get stubs
// and keep using permission_handler.
export 'browser_media_permission_stub.dart'
    if (dart.library.js_interop) 'browser_media_permission_web.dart';
