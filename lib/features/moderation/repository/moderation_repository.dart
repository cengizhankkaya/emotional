import 'package:emotional/features/moderation/data/report_model.dart';
import 'package:firebase_database/firebase_database.dart';

/// Repository that handles moderation actions (reports, blocking) via Firebase.
class ModerationRepository {
  final FirebaseDatabase _database;

  ModerationRepository({FirebaseDatabase? database})
      : _database = database ?? FirebaseDatabase.instance;

  // ─── Reports ───────────────────────────────────────────────────────

  /// Submits a report to Firebase. The report is stored under `reports/{id}`.
  Future<void> submitReport(ReportModel report) async {
    final reportsRef = _database.ref('reports');
    final newRef = reportsRef.push();
    final updatedReport = ReportModel(
      id: newRef.key!,
      reporterUserId: report.reporterUserId,
      reportedUserId: report.reportedUserId,
      reportedUserName: report.reportedUserName,
      messageId: report.messageId,
      messageText: report.messageText,
      roomId: report.roomId,
      reason: report.reason,
      description: report.description,
      timestamp: report.timestamp,
      status: report.status,
    );
    await newRef.set(updatedReport.toJson());
  }

  // ─── Blocking ──────────────────────────────────────────────────────

  /// Blocks a user. Writes to `users/{userId}/blockedUsers/{blockedUserId}`.
  /// Also submits an automatic report so the developer is notified.
  Future<void> blockUser({
    required String userId,
    required String blockedUserId,
    required String blockedUserName,
    required String roomId,
  }) async {
    // 1. Add to the user's blocked list
    final blockedRef =
        _database.ref('users/$userId/blockedUsers/$blockedUserId');
    await blockedRef.set({
      'name': blockedUserName,
      'blockedAt': ServerValue.timestamp,
    });

    // 2. Auto-report to notify developer
    await submitReport(ReportModel(
      id: '',
      reporterUserId: userId,
      reportedUserId: blockedUserId,
      reportedUserName: blockedUserName,
      roomId: roomId,
      reason: 'blocked',
      description: 'User was blocked by another user',
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  /// Unblocks a user.
  Future<void> unblockUser({
    required String userId,
    required String blockedUserId,
  }) async {
    final blockedRef =
        _database.ref('users/$userId/blockedUsers/$blockedUserId');
    await blockedRef.remove();
  }

  /// Returns a stream of blocked user IDs for the given [userId].
  Stream<List<String>> streamBlockedUsers(String userId) {
    final blockedRef = _database.ref('users/$userId/blockedUsers');
    return blockedRef.onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return <String>[];
      return data.keys.map((e) => e.toString()).toList();
    });
  }

  /// Returns the current list of blocked user IDs (one-shot).
  Future<List<String>> getBlockedUsers(String userId) async {
    final snapshot = await _database.ref('users/$userId/blockedUsers').get();
    if (!snapshot.exists || snapshot.value == null) return [];
    final data = snapshot.value as Map<dynamic, dynamic>;
    return data.keys.map((e) => e.toString()).toList();
  }
}
