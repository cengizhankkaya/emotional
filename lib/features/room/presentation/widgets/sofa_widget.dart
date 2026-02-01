import 'dart:math';
import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';

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
      width: isLoveTheme
          ? context.dynamicValue(220)
          : context.dynamicValue(360), // Smaller width for Loveseat
      height: context.dynamicValue(140), // Height for backrest
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 0. Legs
          if (theme.hasLegs) ...[
            for (double pos
                in isLoveTheme ? [20, 60, 140, 180] : [20, 100, 260, 340])
              Positioned(
                bottom: 0,
                left: context.dynamicValue(pos),
                child: Container(
                  width: context.dynamicValue(10),
                  height: context.dynamicValue(15),
                  color: const Color(0xFF4E342E), // Wood
                ),
              ),
          ],

          // 1. Backrest
          Positioned(
            top: 0,
            left: context.dynamicValue(20),
            right: context.dynamicValue(20),
            height: context.dynamicValue(
              theme.backrestHeight + 20,
            ), // Sofa needs bit more height
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
            bottom: theme.hasLegs ? context.dynamicValue(10) : 0,
            left: context.dynamicValue(10),
            right: context.dynamicValue(10),
            height: context.dynamicValue(90),
            child: Container(
              decoration: BoxDecoration(
                color: theme.baseColor,
                borderRadius: ProjectRadius.large(),
              ),
            ),
          ),

          // 3. Side Arms (Left)
          Positioned(
            left: 0,
            bottom: theme.hasLegs ? context.dynamicValue(10) : 0,
            child: Container(
              width: context.dynamicValue(
                theme.armrestWidth + 10,
              ), // Wider for sofa
              height: context.dynamicValue(theme.armrestHeight + 10),
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
                    color: Colors.black.withValues(alpha: 0.2),
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
            bottom: theme.hasLegs ? context.dynamicValue(10) : 0,
            child: Container(
              width: context.dynamicValue(theme.armrestWidth + 10),
              height: context.dynamicValue(theme.armrestHeight + 10),
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
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(-2, 2),
                  ),
                ],
              ),
            ),
          ),

          // 4. Seat Cushions & Content
          Positioned(
            left: context.dynamicValue(theme.armrestWidth + 15),
            right: context.dynamicValue(theme.armrestWidth + 15),
            bottom: theme.hasLegs
                ? context.dynamicValue(15)
                : context.dynamicValue(10),
            top: context.dynamicValue(40),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center, // Center for Love theme
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(maxParticipants, (index) {
                final participant = index < sofaParticipants.length
                    ? sofaParticipants[index]
                    : null;

                return Container(
                  width: context.dynamicValue(60),
                  height: context.dynamicValue(75),
                  margin: ProjectPadding.symmetric(
                    horizontal: 2,
                  ), // Gap between cushions
                  decoration: BoxDecoration(
                    color: theme.cushionColor,
                    shape: theme.cushionShape,
                    borderRadius: theme.cushionShape == BoxShape.rectangle
                        ? ProjectRadius.medium()
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
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
