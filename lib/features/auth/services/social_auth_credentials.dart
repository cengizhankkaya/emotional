import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

/// Google ve Apple OAuth credential üretimi (giriş + hesap silme öncesi reauth).
abstract final class SocialAuthCredentials {
  static const Duration appleSignInTimeout = Duration(seconds: 60);

  static const String appleSignInTimeoutCode = 'apple-sign-in-timeout';

  static AppleAuthProvider _appleProvider() {
    return AppleAuthProvider()..addScope('email');
  }

  static Future<AuthCredential> googleSignInCredential() async {
    final googleUser = await GoogleSignIn.instance.authenticate(
      scopeHint: [drive.DriveApi.driveReadonlyScope],
    );
    final googleAuth = googleUser.authentication;
    final authz = await GoogleSignIn.instance.authorizationClient
        .authorizationForScopes([drive.DriveApi.driveReadonlyScope]);

    return GoogleAuthProvider.credential(
      accessToken: authz?.accessToken,
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
        await user.reauthenticateWithCredential(await googleSignInCredential());
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
