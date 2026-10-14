import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:emotional/core/services/download/download_service.dart';
import 'package:emotional/core/services/drive_stream/drive_stream.dart';
import 'package:emotional/features/auth/services/social_auth_credentials.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DriveService {
  DriveService();

  /// Renewal during playback is offered a few minutes before expiry; this
  /// keeps that prompt from showing right after the video starts.
  static const Duration _webStreamMinTokenValidity = Duration(minutes: 10);

  Future<GoogleSignInAccount?> signIn() async {
    try {
      return await GoogleSignIn.instance.authenticate(
        scopeHint: [drive.DriveApi.driveReadonlyScope],
      );
    } catch (error) {
      debugPrint('DriveService: Error signing in: $error');
      return null;
    }
  }

  Future<drive.DriveApi?> _getDriveApi({bool silentOnly = false}) async {
    if (kIsWeb) {
      final token = await SocialAuthCredentials.webDriveAccessToken(
        FirebaseAuth.instance,
        silentOnly: silentOnly,
      );
      if (token == null) return null;
      return drive.DriveApi(
        GoogleSignInClientAuthorization(
          accessToken: token,
        ).authClient(scopes: [drive.DriveApi.driveReadonlyScope]),
      );
    }

    var account = await GoogleSignIn.instance
        .attemptLightweightAuthentication();

    if (!silentOnly && account == null) {
      try {
        account = await GoogleSignIn.instance.authenticate(
          scopeHint: [drive.DriveApi.driveReadonlyScope],
        );
      } catch (e) {
        debugPrint('DriveService: Error signing in interactively: $e');
      }
    }

    if (account == null) return null;

    GoogleSignInClientAuthorization? authz = await GoogleSignIn
        .instance
        .authorizationClient
        .authorizationForScopes([drive.DriveApi.driveReadonlyScope]);
    if (authz == null && !silentOnly) {
      try {
        authz = await GoogleSignIn.instance.authorizationClient.authorizeScopes(
          [drive.DriveApi.driveReadonlyScope],
        );
      } catch (e) {
        debugPrint('DriveService: Error authorizing scopes: $e');
      }
    }

    if (authz == null) return null;

    final httpClient = authz.authClient(
      scopes: [drive.DriveApi.driveReadonlyScope],
    );
    return drive.DriveApi(httpClient);
  }

  Future<drive.FileList?> listVideoFiles({
    String? pageToken,
    int pageSize = 10,
    bool silentOnly = false,
    String? search,
  }) async {
    final driveApi = await _getDriveApi(silentOnly: silentOnly);
    if (driveApi == null) return null;

    final query = search?.trim() ?? '';
    // Drive query strings quote with ' and escape with \.
    final nameFilter = query.isEmpty
        ? ''
        : " and name contains '${query.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";

    try {
      final response = await driveApi.files.list(
        q: "mimeType contains 'video/' and trashed = false$nameFilter",
        $fields:
            'nextPageToken, files(id, name, mimeType, size, thumbnailLink, '
            'modifiedTime, videoMediaMetadata(durationMillis))',
        orderBy: 'modifiedTime desc',
        pageSize: pageSize,
        pageToken: pageToken,
      );
      return response;
    } catch (e) {
      debugPrint('DriveService: Error listing files: $e');
      if (kIsWeb && _isRejectedToken(e)) {
        // Revoked, or granted without the Drive scope: the cached token
        // looks valid until it expires, so drop it to offer reconnecting.
        SocialAuthCredentials.clearWebDriveToken();
      }
      return null;
    }
  }

  static bool _isRejectedToken(Object error) {
    if (error is! drive.DetailedApiRequestError) return false;
    if (error.status == 401) return true;
    return error.status == 403 &&
        error.errors.any(
          (e) =>
              e.reason == 'insufficientPermissions' || e.reason == 'authError',
        );
  }

  /// Web only: a same-origin URL that `drive_stream_sw.js` forwards to Drive
  /// with the token in the Authorization header, so the browser can stream
  /// (and seek in) the video without downloading it first.
  Future<String> webStreamUrl(String fileId) async {
    // The URL token only starts the stream; renewed tokens reach
    // drive_stream_sw.js directly while the video plays.
    final token = await SocialAuthCredentials.webDriveAccessToken(
      FirebaseAuth.instance,
      minValidity: _webStreamMinTokenValidity,
    );
    if (token == null) {
      throw Exception('Google Drive access requires signing in with Google.');
    }
    await ensureDriveStreamReady();
    return buildWebStreamUrl(
      documentBaseUri,
      fileId,
      token,
      SocialAuthCredentials.webDriveTokenExpiry,
    );
  }

  /// `<base>drive-stream/<fileId>?t=<token>&e=<expiry ms>`, the address
  /// drive_stream_sw.js intercepts.
  @visibleForTesting
  static String buildWebStreamUrl(
    Uri base,
    String fileId,
    String token,
    DateTime? expiry,
  ) => base
      .resolve('drive-stream/${Uri.encodeComponent(fileId)}')
      .replace(
        queryParameters: {
          't': token,
          if (expiry != null) 'e': '${expiry.millisecondsSinceEpoch}',
        },
      )
      .toString();

  Future<String?> downloadVideoInBackground(
    String fileId,
    String fileName, {
    bool showNotification = true,
    bool silentOnly = false,
  }) async {
    try {
      // Ensure we have a valid account (silent or interactive)
      final driveApi = await _getDriveApi(silentOnly: silentOnly);
      if (driveApi == null) {
        throw Exception('User not signed in or Drive access denied.');
      }

      final authz = await GoogleSignIn.instance.authorizationClient
          .authorizationForScopes([drive.DriveApi.driveReadonlyScope]);
      if (authz == null) {
        throw Exception('User is not authorized for Drive scopes.');
      }

      final accessToken = authz.accessToken;
      if (accessToken.isEmpty) {
        throw Exception('Access token could not be retrieved.');
      }

      // Clean token
      final cleanToken = accessToken.replaceFirst('Bearer ', '').trim();

      // 1. Verify the file and token with a small metadata call first
      try {
        await driveApi.files.get(fileId, $fields: 'id,name');
      } catch (e) {
        throw Exception('File access/token check failed: $e');
      }

      // Sanitize filename
      final safeFileName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

      // URL to download content (DownloadService saves to applicationDocuments)
      final url = 'https://www.googleapis.com/drive/v3/files/$fileId?alt=media';

      debugPrint('DriveService: Enqueuing download for $safeFileName');

      final taskId = await DownloadService().download(
        url: url,
        headers: {"Authorization": "Bearer $cleanToken"},
        // savedDir is handled by DownloadService (BaseDirectory.applicationDocuments)
        filename: safeFileName,
        showNotification: showNotification,
        openFileFromNotification: true,
      );

      if (taskId == null) {
        throw Exception('Failed to enqueue download task');
      }

      debugPrint(
        'DriveService: Enqueued task for $safeFileName with ID: $taskId',
      );

      return taskId;
    } catch (e) {
      debugPrint('DriveService: Error enqueuing background download: $e');
      rethrow;
    }
  }
}
