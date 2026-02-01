import 'dart:io';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

class DriveService {
  final GoogleSignIn _googleSignIn;

  DriveService({GoogleSignIn? googleSignIn})
    : _googleSignIn =
          googleSignIn ??
          GoogleSignIn(scopes: [drive.DriveApi.driveReadonlyScope]);

  /// Get authenticated Drive API client
  Future<drive.DriveApi?> _getDriveApi() async {
    // Determine if we need to sign in silently
    if (_googleSignIn.currentUser == null) {
      try {
        await _googleSignIn.signInSilently();
      } catch (e) {
        print('DriveService: Silent sign-in failed: $e');
      }
    }

    // Now check if we have a user
    if (_googleSignIn.currentUser == null) return null;

    final client = await _googleSignIn.authenticatedClient();
    if (client == null) return null;
    return drive.DriveApi(client);
  }

  /// List video files from Drive
  Future<List<drive.File>> listVideoFiles() async {
    try {
      final api = await _getDriveApi();
      if (api == null) throw Exception('User not signed in');

      final fileList = await api.files.list(
        q: "mimeType contains 'video/' and trashed = false",
        $fields: 'files(id, name, mimeType, thumbnailLink, size)',
      );
      return fileList.files ?? [];
    } catch (e) {
      print('DriveService: Error listing files: $e');
      rethrow;
    }
  }

  /// Download a file from Drive with progress
  Future<File> downloadFile(
    String fileId,
    String fileName, {
    Function(int received, int total)? onProgress,
  }) async {
    // ... (existing implementation)
    try {
      final api = await _getDriveApi();
      if (api == null) throw Exception('User not signed in');

      final media =
          await api.files.get(
                fileId,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/$fileName');

      final sink = file.openWrite();
      final totalBytes = media.length ?? 0;
      int receivedBytes = 0;

      await media.stream
          .listen(
            (List<int> chunk) {
              receivedBytes += chunk.length;
              onProgress?.call(receivedBytes, totalBytes);
              sink.add(chunk);
            },
            onDone: () async {
              await sink.close();
            },
            onError: (e) {
              sink.close();
              throw e;
            },
          )
          .asFuture();

      return file;
    } catch (e) {
      print('DriveService: Error downloading file: $e');
      rethrow;
    }
  }

  /// Download video in background using flutter_downloader
  Future<String?> downloadVideoInBackground(
    String fileId,
    String fileName, {
    bool showNotification = true,
  }) async {
    try {
      // Get access token
      final authHeaders = await _googleSignIn.currentUser?.authHeaders;
      final accessToken = authHeaders?['Authorization'];

      if (accessToken == null) {
        throw Exception('User not signed in or no access token');
      }

      final appDir = await getApplicationDocumentsDirectory();
      final savedDir = appDir.path;

      // 1. Sanitize filename (replace invalid chars with underscore)
      final safeFileName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

      // URL to download content
      // NOTE: Google Drive API requires 'alt=media' param to download file content
      // &acknowledgeAbuse=true bypasses the virus scan warning for large files
      final url =
          'https://www.googleapis.com/drive/v3/files/$fileId?alt=media&acknowledgeAbuse=true';

      final taskId = await FlutterDownloader.enqueue(
        url: url,
        headers: {"Authorization": accessToken},
        savedDir: savedDir,
        fileName: safeFileName,
        showNotification:
            showNotification, // show download progress in status bar (for Android)
        openFileFromNotification:
            false, // click on notification to open downloaded file (for Android)
        saveInPublicStorage: false,
      );

      return taskId;
    } catch (e) {
      print('DriveService: Error enqueuing background download: $e');
      rethrow;
    }
  }
}
