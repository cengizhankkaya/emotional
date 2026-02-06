import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/room/presentation/widgets/avatar_participant_widget.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ParticipantVideoRow extends StatelessWidget {
  final List<String> participants;
  final Map<String, String> userNames;
  final String currentUserId;
  final String roomId;
  final String hostId;

  const ParticipantVideoRow({
    super.key,
    required this.participants,
    required this.userNames,
    required this.currentUserId,
    required this.roomId,
    required this.hostId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CallBloc, CallState>(
      builder: (context, callState) {
        final sortedParticipants = _getSortedParticipants(participants);

        return Container(
          height: context.dynamicValue(180), // Increased height for safe layout
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sortedParticipants.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final participantId = sortedParticipants[index];
              return _ParticipantItem(
                participantId: participantId,
                userName: userNames[participantId] ?? participantId,
                callState: callState,
                currentUserId: currentUserId,
                roomId: roomId,
                isHost: participantId == hostId,
              );
            },
          ),
        );
      },
    );
  }

  List<String> _getSortedParticipants(List<String> originalList) {
    if (originalList.isEmpty) return [];

    final sortedList = List<String>.from(originalList);
    sortedList.sort((a, b) {
      if (a == currentUserId) return -1;
      if (b == currentUserId) return 1;
      if (a == hostId) return -1;
      if (b == hostId) return 1;

      final nameA = userNames[a] ?? a;
      final nameB = userNames[b] ?? b;
      return nameA.toLowerCase().compareTo(nameB.toLowerCase());
    });
    return sortedList;
  }
}

class _ParticipantItem extends StatelessWidget {
  final String participantId;
  final String userName;
  final CallState callState;
  final String currentUserId;
  final String roomId;
  final bool isHost;

  const _ParticipantItem({
    required this.participantId,
    required this.userName,
    required this.callState,
    required this.currentUserId,
    required this.roomId,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AvatarParticipantWidget(
        name: userName,
        participantId: participantId,
        callState: callState,
        currentUserId: currentUserId,
        roomId: roomId,
        isParticipantHost: isHost,
        showVideo: true,
        showControls: true,
        customWidth: context.dynamicValue(90),
        customHeight: context.dynamicValue(130),
        shape: BoxShape.rectangle,
      ),
    );
  }
}
