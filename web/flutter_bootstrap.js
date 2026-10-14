{{flutter_js}}
{{flutter_build_config}}

// Load without Flutter's (deprecated) service worker: it would take over the
// root scope and unregister drive_stream_sw.js, which Drive streaming needs.
_flutter.loader.load();
