import 'dart:async';

import 'package:emotional/features/moderation/data/report_model.dart';
import 'package:emotional/features/moderation/repository/moderation_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'moderation_event.dart';
part 'moderation_state.dart';

class ModerationBloc extends Bloc<ModerationEvent, ModerationState> {
  final ModerationRepository _repository;
  StreamSubscription<List<String>>? _blockedSubscription;

  ModerationBloc({required ModerationRepository repository})
      : _repository = repository,
        super(const ModerationInitial()) {
    on<LoadBlockedUsers>(_onLoadBlockedUsers);
    on<BlockedUsersUpdated>(_onBlockedUsersUpdated);
    on<BlockUserRequested>(_onBlockUserRequested);
    on<UnblockUserRequested>(_onUnblockUserRequested);
    on<SubmitReportRequested>(_onSubmitReportRequested);
  }

  @override
  Future<void> close() {
    _blockedSubscription?.cancel();
    return super.close();
  }

  Future<void> _onLoadBlockedUsers(
    LoadBlockedUsers event,
    Emitter<ModerationState> emit,
  ) async {
    _blockedSubscription?.cancel();
    _blockedSubscription = _repository
        .streamBlockedUsers(event.userId)
        .listen(
          (blockedIds) => add(BlockedUsersUpdated(blockedIds)),
          onError: (error) {
            debugPrint('ModerationBloc: Error loading blocked users: $error');
          },
        );
  }

  void _onBlockedUsersUpdated(
    BlockedUsersUpdated event,
    Emitter<ModerationState> emit,
  ) {
    emit(BlockedUsersLoaded(event.blockedUserIds));
  }

  Future<void> _onBlockUserRequested(
    BlockUserRequested event,
    Emitter<ModerationState> emit,
  ) async {
    try {
      await _repository.blockUser(
        userId: event.userId,
        blockedUserId: event.blockedUserId,
        blockedUserName: event.blockedUserName,
        roomId: event.roomId,
      );
      // The stream subscription will automatically update the state
    } catch (e) {
      debugPrint('ModerationBloc: Error blocking user: $e');
      emit(ModerationError(e.toString()));
    }
  }

  Future<void> _onUnblockUserRequested(
    UnblockUserRequested event,
    Emitter<ModerationState> emit,
  ) async {
    try {
      await _repository.unblockUser(
        userId: event.userId,
        blockedUserId: event.blockedUserId,
      );
    } catch (e) {
      debugPrint('ModerationBloc: Error unblocking user: $e');
      emit(ModerationError(e.toString()));
    }
  }

  Future<void> _onSubmitReportRequested(
    SubmitReportRequested event,
    Emitter<ModerationState> emit,
  ) async {
    try {
      await _repository.submitReport(event.report);
      emit(const ReportSubmitted());
      // Restore blocked users state
      final currentState = state;
      if (currentState is BlockedUsersLoaded) {
        emit(BlockedUsersLoaded(currentState.blockedUserIds));
      }
    } catch (e) {
      debugPrint('ModerationBloc: Error submitting report: $e');
      emit(ModerationError(e.toString()));
    }
  }
}
