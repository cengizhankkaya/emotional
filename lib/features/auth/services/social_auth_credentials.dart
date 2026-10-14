import 'dart:async';

import 'package:emotional/core/services/drive_stream/drive_stream.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';

/// Google ve Apple OAuth credential üretimi (giriş + hesap silme öncesi reauth).
abstract final class SocialAuthCredentials {
  static const Duration appleSignInTimeout = Duration(seconds: 60);

  static const String appleSignInTimeoutCode = 'apple-sign-in-timeout';

  static AppleAuthProvider _appleProvider() {
    return AppleAuthProvider()..addScope('email');
  }

  static GoogleAuthProvider _googleWebProvider() {
    return GoogleAuthProvider()..addScope(drive.DriveApi.driveReadonlyScope);
  }

  // Web: Google OAuth tokens live ~1 hour and the popup flow gives no refresh
  // token, so we keep the latest one in memory and re-prompt when it expires.
  static const Duration _webDriveTokenLifetime = Duration(minutes: 55);
  static String? _webDriveAccessToken;
  static DateTime? _webDriveTokenExpiry;

  // Also kept in browser storage, so a page reload doesn't ask for Drive
  // access again. Tied to the user and dropped when it expires.
  static const String _webDriveTokenPrefsKey = 'web_drive_token';
  static bool _restoredWebDriveToken = false;

  static void _storeWebDriveToken(UserCredential result) {
    final token = result.credential?.accessToken;
    final uid = result.user?.uid;
    if (token == null || token.isEmpty) return;
    _webDriveAccessToken = token;
    final expiry = DateTime.now().add(_webDriveTokenLifetime);
    _webDriveTokenExpiry = expiry;
    publishDriveStreamToken(token, expiry);
    if (uid != null) unawaited(_persistWebDriveToken(uid, token, expiry));
  }

  static Future<void> _persistWebDriveToken(
    String uid,
    String token,
    DateTime expiry,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_webDriveTokenPrefsKey, [
        uid,
        token,
        '${expiry.millisecondsSinceEpoch}',
      ]);
    } catch (e) {
      debugPrint('[GoogleAuth] Could not keep the Drive token: $e');
    }
  }

  static Future<void> _restoreWebDriveToken(String uid) async {
    if (_restoredWebDriveToken) return;
    _restoredWebDriveToken = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_webDriveTokenPrefsKey);
      if (saved == null || saved.length != 3 || saved[0] != uid) return;
      final expiry = DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(saved[2]) ?? 0,
      );
      if (DateTime.now().isAfter(expiry)) return;
      _webDriveAccessToken = saved[1];
      _webDriveTokenExpiry = expiry;
      publishDriveStreamToken(saved[1], expiry);
    } catch (e) {
      debugPrint('[GoogleAuth] Could not restore the Drive token: $e');
    }
  }

  static void clearWebDriveToken() {
    _webDriveAccessToken = null;
    _webDriveTokenExpiry = null;
    publishDriveStreamToken(null, null);
    unawaited(
      SharedPreferences.getInstance()
          .then((prefs) => prefs.remove(_webDriveTokenPrefsKey))
          .catchError((Object _) => false),
    );
  }

  /// Web only: Firebase popup sign-in with the Drive scope. The popup returns
  /// the Google OAuth access token, so no separate Google Sign-In client is
  /// needed in the browser.
  static Future<UserCredential> signInWithGoogleWeb(FirebaseAuth auth) async {
    final result = await auth.signInWithPopup(_googleWebProvider());
    _storeWebDriveToken(result);
    return result;
  }

  /// Web only: when the cached Drive token runs out, or null if there is
  /// none.
  static DateTime? get webDriveTokenExpiry =>
      _webDriveAccessToken == null ? null : _webDriveTokenExpiry;

  /// Web only: returns a Drive access token that stays valid for at least
  /// [minValidity]. When the cached token is missing or runs out sooner, or
  /// [forceRefresh] is set, and [silentOnly] is false, Google users are asked
  /// to re-authenticate in a popup, which must happen in response to a tap.
  static Future<String?> webDriveAccessToken(
    FirebaseAuth auth, {
    bool silentOnly = false,
    bool forceRefresh = false,
    Duration minValidity = Duration.zero,
  }) async {
    final uid = auth.currentUser?.uid;
    if (_webDriveAccessToken == null && uid != null) {
      await _restoreWebDriveToken(uid);
    }
    final expiry = _webDriveTokenExpiry;
    if (!forceRefresh &&
        _webDriveAccessToken != null &&
        expiry != null &&
        DateTime.now().add(minValidity).isBefore(expiry)) {
      return _webDriveAccessToken;
    }
    if (silentOnly) return null;

    final user = auth.currentUser;
    if (user == null || _primaryProviderId(user) != 'google.com') return null;

    _storeWebDriveToken(
      await user.reauthenticateWithPopup(_googleWebProvider()),
    );
    return _webDriveAccessToken;
  }

  static Future<AuthCredential> googleSignInCredential() async {
    final googleUser = await GoogleSignIn.instance.authenticate(
      scopeHint: [drive.DriveApi.driveReadonlyScope],
    );
    final googleAuth = googleUser.authentication;

    // Drive authorization is optional for Firebase Auth — only idToken is required.
    // If the user has not pre-authorized Drive or the authorization call fails
    // (e.g. in a fresh review/sandbox environment), we fall back gracefully so
    // that sign-in still succeeds without Drive access.
    String? driveAccessToken;
    try {
      final authz = await GoogleSignIn.instance.authorizationClient
          .authorizationForScopes([drive.DriveApi.driveReadonlyScope]);
      driveAccessToken = authz?.accessToken;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GoogleAuth] Drive scope authorization skipped: $e');
      }
      // Non-fatal: Firebase sign-in can proceed with idToken alone.
    }

    return GoogleAuthProvider.credential(
      accessToken: driveAccessToken,
      idToken: googleAuth.idToken,
    );
  }

  /// Firebase native Apple UI.
  static Future<UserCredential> signInWithApple(FirebaseAuth auth) async {
    if (kDebugMode) {
      debugPrint('[AppleAuth] Firebase signInWithProvider(Apple)…');
    }
    try {
      final result = await auth
          .signInWithProvider(_appleProvider())
          .timeout(appleSignInTimeout);
      if (kDebugMode) {
        debugPrint('[AppleAuth] Firebase Apple sign-in completed');
      }
      return result;
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('[AppleAuth] Timed out waiting for Apple sheet to complete');
      }
      throw FirebaseAuthException(
        code: appleSignInTimeoutCode,
        message: 'Apple sign-in timed out',
      );
    }
  }

  static bool isAppleSignInCancelled(FirebaseAuthException e) {
    return e.code == 'cancelled-popup-request' ||
        e.code == 'web-context-cancelled' ||
        e.code == 'user-cancelled';
  }

  static bool isAppleSignInTimeout(FirebaseAuthException e) {
    return e.code == appleSignInTimeoutCode;
  }

  /// Mevcut kullanıcının birincil sağlayıcısına göre yeniden kimlik doğrulama.
  static Future<void> reauthenticateCurrentUser(FirebaseAuth auth) async {
    final user = auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in user',
      );
    }

    final providerId = _primaryProviderId(user);
    switch (providerId) {
      case 'google.com':
        if (kIsWeb) {
          _storeWebDriveToken(
            await user.reauthenticateWithPopup(_googleWebProvider()),
          );
        } else {
          await user.reauthenticateWithCredential(
            await googleSignInCredential(),
          );
        }
      case 'apple.com' when kIsWeb:
        await user.reauthenticateWithPopup(_appleProvider());
      case 'apple.com':
        if (kDebugMode) {
          debugPrint('[AppleAuth] Firebase reauthenticateWithProvider(Apple)…');
        }
        try {
          await user
              .reauthenticateWithProvider(_appleProvider())
              .timeout(appleSignInTimeout);
        } on TimeoutException {
          throw FirebaseAuthException(
            code: appleSignInTimeoutCode,
            message: 'Apple reauthentication timed out',
          );
        }
      default:
        throw FirebaseAuthException(
          code: 'unsupported-provider',
          message: 'Unsupported provider: $providerId',
        );
    }
  }

  static String _primaryProviderId(User user) {
    if (user.providerData.isEmpty) {
      return 'unknown';
    }
    return user.providerData.first.providerId;
  }
}
