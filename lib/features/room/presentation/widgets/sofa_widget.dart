import 'dart:math';
import 'package:emotional/features/room/presentation/manager/room_decoration_cubit.dart';
import 'package:emotional/features/room/presentation/widgets/furniture_theme_data.dart';
import 'package:flutter/material.dart';

class SofaWidget extends StatelessWidget {
  final List<String> participants;
  final Function(String?) buildAvatarSlot;
  final ArmchairStyle style;

  const SofaWidget({
    super.key,
    required this.participants,
    required this.buildAvatarSlot,
    this.style = ArmchairStyle.modern,
  });

  @override
  Widget build(BuildContext context) {
    // Take max 4 participants for the sofa, or 2 for Love theme
    final isLoveTheme = style == ArmchairStyle.love;
    final maxParticipants = isLoveTheme ? 2 : 4;

    final sofaParticipants = participants
        .take(min(participants.length, maxParticipants))
        .toList();

    final theme = FurnitureThemeData.getTheme(style);

    return SizedBox(
      width: isLoveTheme ? 220 : 360, // Smaller width for Loveseat
      height: 140, // Height for backrest
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 0. Legs
          if (theme.hasLegs) ...[
            for (double pos
                in isLoveTheme ? [20, 60, 140, 180] : [20, 100, 260, 340])
              Positioned(
                bottom: 0,
                left: pos,
                child: Container(
                  width: 10,
                  height: 15,
                  color: const Color(0xFF4E342E), // Wood
                ),
              ),
          ],

          // 1. Backrest
          Positioned(
            top: 0,
            left: 20,
            right: 20,
            height: theme.backrestHeight + 20, // Sofa needs bit more height
            child: Container(
              decoration: BoxDecoration(
                color: theme.backrestColor,
                borderRadius: theme.backrestRadius,
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),

          // 2. Base/Seat foundation
          Positioned(
            bottom: theme.hasLegs ? 10 : 0,
            left: 10,
            right: 10,
            height: 90,
            child: Container(
              decoration: BoxDecoration(
                color: theme.baseColor,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          // 3. Side Arms (Left)
          Positioned(
            left: 0,
            bottom: theme.hasLegs ? 10 : 0,
            child: Container(
              width: theme.armrestWidth + 10, // Wider for sofa
              height: theme.armrestHeight + 10,
              decoration: BoxDecoration(
                color: theme.armrestColor,
                borderRadius: theme.armrestRadius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: theme.armrestGradient,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
            ),
          ),

          // 3. Side Arms (Right)
          Positioned(
            right: 0,
            bottom: theme.hasLegs ? 10 : 0,
            child: Container(
              width: theme.armrestWidth + 10,
              height: theme.armrestHeight + 10,
              decoration: BoxDecoration(
                color: theme.armrestColor,
                borderRadius: theme.armrestRadius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: theme.armrestGradient,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(-2, 2),
                  ),
                ],
              ),
            ),
          ),

          // 4. Seat Cushions & Content
          Positioned(
            left: theme.armrestWidth + 15,
            right: theme.armrestWidth + 15,
            bottom: theme.hasLegs ? 15 : 10,
            top: 40,
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center, // Center for Love theme
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(maxParticipants, (index) {
                final participant = index < sofaParticipants.length
                    ? sofaParticipants[index]
                    : null;

                return Container(
                  width: 60,
                  height: 75,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 2,
                  ), // Gap between cushions
                  decoration: BoxDecoration(
                    color: theme.cushionColor,
                    shape: theme.cushionShape,
                    borderRadius: theme.cushionShape == BoxShape.rectangle
                        ? BorderRadius.circular(12)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(child: buildAvatarSlot(participant)),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
