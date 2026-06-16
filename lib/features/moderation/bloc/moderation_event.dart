part of 'moderation_bloc.dart';

abstract class ModerationEvent extends Equatable {
  const ModerationEvent();

  @override
  List<Object?> get props => [];
}

class LoadBlockedUsers extends ModerationEvent {
  final String userId;

  const LoadBlockedUsers(this.userId);

  @override
  List<Object> get props => [userId];
}

class BlockedUsersUpdated extends ModerationEvent {
  final List<String> blockedUserIds;

  const BlockedUsersUpdated(this.blockedUserIds);

  @override
  List<Object> get props => [blockedUserIds];
}

class BlockUserRequested extends ModerationEvent {
  final String userId;
  final String blockedUserId;
  final String blockedUserName;
  final String roomId;

  const BlockUserRequested({
    required this.userId,
    required this.blockedUserId,
    required this.blockedUserName,
    required this.roomId,
  });

  @override
  List<Object> get props => [userId, blockedUserId, blockedUserName, roomId];
}

class UnblockUserRequested extends ModerationEvent {
  final String userId;
  final String blockedUserId;

  const UnblockUserRequested({
    required this.userId,
    required this.blockedUserId,
  });

  @override
  List<Object> get props => [userId, blockedUserId];
}

class SubmitReportRequested extends ModerationEvent {
  final ReportModel report;

  const SubmitReportRequested(this.report);

  @override
  List<Object> get props => [report];
}
