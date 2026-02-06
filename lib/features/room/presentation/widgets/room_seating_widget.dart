import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/room/presentation/manager/room_decoration_cubit.dart';
import 'package:emotional/features/room/presentation/widgets/avatar_participant_widget.dart';
import 'package:emotional/features/room/presentation/widgets/furniture_theme_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RoomSeatingWidget extends StatelessWidget {
  final List<String> participants;
  final Map<String, String> userNames;
  final bool isHost;
  final String currentUserId;
  final String roomId;
  final String hostId;

  const RoomSeatingWidget({
    super.key,
    required this.participants,
    required this.userNames,
    required this.isHost,
    required this.currentUserId,
    required this.roomId,
    required this.hostId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CallBloc, CallState>(
      builder: (context, callState) {
        return Center(
          child: AspectRatio(
            aspectRatio: 1024 / 747,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final style = context
                    .watch<RoomDecorationCubit>()
                    .state
                    .armchairStyle;
                final theme = FurnitureThemeData.getTheme(style);
                final isEsce = style == ArmchairStyle.esce;

                final seatPositions = isEsce
                    ? [
                        {'top': 0.10, 'left': 0.20, 'right': null},
                        {'top': 0.10, 'left': null, 'right': 0.20},
                      ]
                    : [
                        {'top': 0.27, 'left': 0.30, 'right': null},
                        {'top': 0.33, 'left': null, 'right': 0.18},
                        {'top': 0.41, 'left': 0.20, 'right': null},
                        {'top': 0.52, 'left': null, 'right': 0.06},
                        {'top': 0.52, 'left': 0.05, 'right': null},
                        {'top': 0.49, 'left': 0.52, 'right': null},
                      ];

                // Ensure local user is always visible if they are in the participants list
                final displayParticipants = List<String>.from(participants);
                if (displayParticipants.contains(currentUserId)) {
                  final myIndex = displayParticipants.indexOf(currentUserId);
                  if (myIndex >= seatPositions.length) {
                    // Swap local user to a visible seat (index 0)
                    final otherId = displayParticipants[0];
                    displayParticipants[0] = currentUserId;
                    displayParticipants[myIndex] = otherId;
                  }
                }

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: theme.image != null
                          ? theme.image!.image(fit: BoxFit.cover)
                          : Container(color: theme.baseColor),
                    ),
                    ...List.generate(seatPositions.length, (index) {
                      final pos = seatPositions[index];
                      final String? participantId =
                          index < displayParticipants.length
                          ? displayParticipants[index]
                          : null;
                      final name = participantId != null
                          ? userNames[participantId] ?? participantId
                          : null;

                      return Positioned(
                        top: constraints.maxHeight * (pos['top'] as double),
                        left: pos['left'] != null
                            ? constraints.maxWidth * (pos['left'] as double)
                            : null,
                        right: pos['right'] != null
                            ? constraints.maxWidth * (pos['right'] as double)
                            : null,
                        child: AvatarParticipantWidget(
                          name: name,
                          participantId: participantId,
                          callState: callState,
                          currentUserId: currentUserId,
                          isParticipantHost: participantId == hostId,
                          canTransferHost:
                              isHost &&
                              participantId != null &&
                              participantId != currentUserId,
                          roomId: roomId,
                          hideAvatar: false,
                          showVideo: false, // Video moved to top bar
                          showControls: false, // Controls moved to top bar
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
