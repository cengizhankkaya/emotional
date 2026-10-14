/// Drive streaming is only used on web; mobile downloads files instead.
Future<void> ensureDriveStreamReady() =>
    throw UnsupportedError('Drive streaming is only available on web');

void publishDriveStreamToken(String? token, DateTime? expiry) {}

Stream<void> get driveStreamTokenRequests => const Stream.empty();

bool browserMayPlay(String mimeType) => true;

/// Where relative app URLs resolve; see the web version.
Uri get documentBaseUri => Uri.base;
