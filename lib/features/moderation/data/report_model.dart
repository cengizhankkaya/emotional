/// Model representing a user report for objectionable content or abusive behavior.
class ReportModel {
  final String id;
  final String reporterUserId;
  final String reportedUserId;
  final String reportedUserName;
  final String? messageId;
  final String? messageText;
  final String roomId;
  final String reason; // 'inappropriate', 'harassment', 'spam', 'other'
  final String? description;
  final int timestamp;
  final String status; // 'pending', 'reviewed', 'resolved'

  const ReportModel({
    required this.id,
    required this.reporterUserId,
    required this.reportedUserId,
    required this.reportedUserName,
    this.messageId,
    this.messageText,
    required this.roomId,
    required this.reason,
    this.description,
    required this.timestamp,
    this.status = 'pending',
  });

  Map<String, dynamic> toJson() {
    return {
      'reporterUserId': reporterUserId,
      'reportedUserId': reportedUserId,
      'reportedUserName': reportedUserName,
      'messageId': messageId,
      'messageText': messageText,
      'roomId': roomId,
      'reason': reason,
      'description': description,
      'timestamp': timestamp,
      'status': status,
    };
  }

  factory ReportModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return ReportModel(
      id: id,
      reporterUserId: map['reporterUserId'] as String? ?? '',
      reportedUserId: map['reportedUserId'] as String? ?? '',
      reportedUserName: map['reportedUserName'] as String? ?? '',
      messageId: map['messageId'] as String?,
      messageText: map['messageText'] as String?,
      roomId: map['roomId'] as String? ?? '',
      reason: map['reason'] as String? ?? 'other',
      description: map['description'] as String?,
      timestamp: map['timestamp'] as int? ?? 0,
      status: map['status'] as String? ?? 'pending',
    );
  }
}
