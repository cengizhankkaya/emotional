// Whether the platform share sheet exists. Browsers without one (desktop
// Firefox, many desktop Chromes) would make share_plus open a mailto: link.
export 'system_share_native.dart'
    if (dart.library.js_interop) 'system_share_web.dart';
