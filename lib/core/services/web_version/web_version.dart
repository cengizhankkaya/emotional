// What the web server currently deploys, and reloading onto it. Mobile
// builds get stubs; they update through the stores.
export 'web_version_stub.dart'
    if (dart.library.js_interop) 'web_version_web.dart';
