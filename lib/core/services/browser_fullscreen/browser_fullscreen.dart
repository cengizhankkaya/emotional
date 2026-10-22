// The browser's own fullscreen (hides its tabs and toolbars). Mobile builds
// get stubs; the app already fills their screen.
export 'browser_fullscreen_stub.dart'
    if (dart.library.js_interop) 'browser_fullscreen_web.dart';
