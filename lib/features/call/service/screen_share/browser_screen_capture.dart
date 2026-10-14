// Browser-specific screen share helpers. Mobile builds get no-op stubs; the
// native capture path is unchanged there.
export 'browser_screen_capture_stub.dart'
    if (dart.library.js_interop) 'browser_screen_capture_web.dart';
