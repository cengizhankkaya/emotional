import 'browser_media_permission_state.dart';

export 'browser_media_permission_state.dart';

Future<BrowserMediaPermission> queryBrowserMediaPermission() async =>
    BrowserMediaPermission.granted;

Future<BrowserMediaPermission> requestBrowserMediaPermission() async =>
    BrowserMediaPermission.granted;

bool get isSafariBrowser => false;

void reloadPage() {}
