import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:emotional/core/services/download/download_service.dart';

class DriveService {
  final GoogleSignIn _googleSignIn;

  DriveService({required GoogleSignIn googleSignIn})
    : _googleSignIn = googleSignIn;

  Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _googleSignIn.signIn();
    } catch (error) {
      print('DriveService: Error signing in: $error');
      return null;
    }
  }

  Future<drive.DriveApi?> _getDriveApi({bool silentOnly = false}) async {
    // Mevcut bir oturum yoksa önce sessizce, sonra (istenirse) etkileşimli giriş dene.
    var account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();

    if (!silentOnly && account == null) {
      try {
        account = await _googleSignIn.signIn();
      } catch (e) {
        debugPrint('DriveService: Error signing in interactively: $e');
      }
    }

    if (account == null) return null;

    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) return null;

    return drive.DriveApi(httpClient);
  }

  Future<drive.FileList?> listVideoFiles({
    String? pageToken,
    int pageSize = 10,
    bool silentOnly = false,
  }) async {
    final driveApi = await _getDriveApi(silentOnly: silentOnly);
    if (driveApi == null) return null;

    try {
      final response = await driveApi.files.list(
        q: "mimeType contains 'video/' and trashed = false",
        $fields:
            'nextPageToken, files(id, name, mimeType, size, thumbnailLink)',
        pageSize: pageSize,
        pageToken: pageToken,
      );
      return response;
    } catch (e) {
      debugPrint('DriveService: Error listing files: $e');
      return null;
    }
  }

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

      final account = _googleSignIn.currentUser;
      if (account == null) {
        throw Exception('User not signed in.');
      }

      final authHeaders = await account.authHeaders;
      final accessToken = authHeaders['Authorization'];

      if (accessToken == null) {
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
      print('DriveService: Error enqueuing background download: $e');
      rethrow;
    }
  }
}
