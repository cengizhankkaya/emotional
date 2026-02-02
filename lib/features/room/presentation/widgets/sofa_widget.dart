import 'dart:math';
import 'package:emotional/product/utility/constants/project_padding.dart';

import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';

import 'package:emotional/features/room/presentation/manager/room_decoration_cubit.dart';

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

    return SizedBox(
      width: isLoveTheme
          ? context.dynamicValue(220)
          : context.dynamicValue(360),
      height: context.dynamicValue(140),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Seat Cushions & Content (Avatars)
          Positioned(
            left: context.dynamicValue(30), // Approx armrest width + padding
            right: context.dynamicValue(30),
            bottom: context.dynamicValue(25), // Approximate seat height
            top: context.dynamicValue(40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(maxParticipants, (index) {
                final participant = index < sofaParticipants.length
                    ? sofaParticipants[index]
                    : null;

                return Container(
                  width: context.dynamicValue(60),
                  height: context.dynamicValue(75),
                  margin: ProjectPadding.symmetric(horizontal: 2),
                  // Transparent placeholder for positioning
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
