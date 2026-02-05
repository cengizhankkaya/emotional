import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

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

  Future<drive.DriveApi?> _getDriveApi() async {
    // Mevcut bir oturum yoksa önce sessizce, sonra etkileşimli giriş dene.
    var account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();
    account ??= await _googleSignIn.signIn();
    if (account == null) return null;

    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) return null;

    return drive.DriveApi(httpClient);
  }

  Future<List<drive.File>> listVideoFiles() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return [];

    final response = await driveApi.files.list(
      q: "mimeType contains 'video/' and trashed = false",
      $fields: 'files(id, name, mimeType, size, thumbnailLink)',
    );

    return response.files ?? [];
  }

  Future<String?> downloadVideoInBackground(
    String fileId,
    String fileName, {
    bool showNotification = true,
  }) async {
    try {
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
        final driveApi = await _getDriveApi();
        if (driveApi == null) {
          throw Exception('Drive API could not be initialized.');
        }
        await driveApi.files.get(fileId, $fields: 'id,name');
      } catch (e) {
        throw Exception('File access/token check failed: $e');
      }

      final appDir =
          await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      final savedDir = appDir.path;

      // Ensure directory exists
      final directory = Directory(savedDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Sanitize filename
      final safeFileName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

      // 2. URL to download content
      // NOTE: We use Header-Only Auth. It's the most standard and stable for Google Drive.
      // External storage directory is used to avoid the "move to public Downloads" bug that causes Status 4 notifications.
      final url = 'https://www.googleapis.com/drive/v3/files/$fileId?alt=media';

      debugPrint(
        'DriveService: [EXTERNAL-STABLE] Enqueuing download for $safeFileName',
      );

      final taskId = await FlutterDownloader.enqueue(
        url: url,
        headers: {"Authorization": "Bearer $cleanToken"},
        savedDir: savedDir,
        fileName: safeFileName,
        showNotification: showNotification,
        openFileFromNotification: true,
        saveInPublicStorage: false,
        allowCellular: true,
      );

      debugPrint(
        'DriveService: Enqueued task for $safeFileName with ID: $taskId at $savedDir',
      );

      return taskId;
    } catch (e) {
      print('DriveService: Error enqueuing background download: $e');
      rethrow;
    }
  }
}
