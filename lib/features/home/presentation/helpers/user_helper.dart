import 'package:firebase_auth/firebase_auth.dart';

/// Helper class for user-related operations
class UserHelper {
  /// Gets the display name for a user
  /// Returns the user's display name, or 'Misafir' for anonymous users,
  /// or email, or 'Kullanıcı' as fallback
  static String getUserDisplayName(User user) {
    return user.displayName ??
        (user.isAnonymous ? 'Misafir' : user.email) ??
        'Kullanıcı';
  }
}
