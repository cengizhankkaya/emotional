import 'dart:math';
import 'package:flutter/material.dart';

class SofaWidget extends StatelessWidget {
  final List<String> participants;
  final Function(String?) buildAvatarSlot;

  const SofaWidget({
    super.key,
    required this.participants,
    required this.buildAvatarSlot,
  });

  @override
  Widget build(BuildContext context) {
    // Take max 4 participants for the sofa
    final sofaParticipants = participants
        .take(min(participants.length, 4))
        .toList();

    return SizedBox(
      width: 360, // Wider to fit everyone + arms
      height: 140, // Height for backrest
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 1. Backrest
          Positioned(
            top: 0,
            left: 20,
            right: 20,
            height: 60,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF00897B), // Darker Teal (More visible)
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),

          // 2. Base/Seat foundation
          Positioned(
            bottom: 0,
            left: 10,
            right: 10,
            height: 90,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF26A69A), // Vivid Teal
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          // 3. Side Arms (Left)
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              width: 25,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF00796B), // Deep Teal
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [const Color(0xFF26A69A), const Color(0xFF00695C)],
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
            bottom: 0,
            child: Container(
              width: 25,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF00796B),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [const Color(0xFF26A69A), const Color(0xFF00695C)],
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
            left: 30, // Space for left arm
            right: 30, // Space for right arm
            bottom: 10,
            top: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(4, (index) {
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
                    color: const Color(0xFFE0F2F1), // Keep light for avatars
                    borderRadius: BorderRadius.circular(12),
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
