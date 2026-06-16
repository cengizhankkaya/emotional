part of 'moderation_bloc.dart';

abstract class ModerationState extends Equatable {
  const ModerationState();

  @override
  List<Object?> get props => [];
}

class ModerationInitial extends ModerationState {
  const ModerationInitial();
}

class BlockedUsersLoaded extends ModerationState {
  final List<String> blockedUserIds;

  const BlockedUsersLoaded(this.blockedUserIds);

  @override
  List<Object> get props => [blockedUserIds];
}

class ReportSubmitted extends ModerationState {
  const ReportSubmitted();
}

class ModerationError extends ModerationState {
  final String message;

  const ModerationError(this.message);

  @override
  List<Object> get props => [message];
}
