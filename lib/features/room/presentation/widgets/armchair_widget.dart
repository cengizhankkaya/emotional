import 'package:emotional/features/room/presentation/manager/room_decoration_cubit.dart';
import 'package:emotional/features/room/presentation/widgets/furniture_theme_data.dart';
import 'package:flutter/material.dart';

class ArmchairWidget extends StatelessWidget {
  final String? participant;
  final bool isLeft;
  final Widget child;
  final ArmchairStyle style;

  const ArmchairWidget({
    super.key,
    required this.participant,
    required this.isLeft,
    required this.child,
    this.style = ArmchairStyle.modern,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FurnitureThemeData.getTheme(style);

    return SizedBox(
      width: 100, // Slightly wider for arms
      height: 100, // Taller for depth
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 0. Legs (Bottom layer) - Only if enabled
          if (theme.hasLegs) ...[
            Positioned(
              bottom: 0,
              left: 15,
              child: Container(
                width: 8,
                height: 15,
                color: const Color(0xFF4E342E), // Wood
              ),
            ),
            Positioned(
              bottom: 0,
              right: 15,
              child: Container(
                width: 8,
                height: 15,
                color: const Color(0xFF4E342E),
              ),
            ),
          ],

          // 1. Backrest (Rear layer)
          Positioned(
            top: 0,
            left: 10,
            right: 10,
            height: theme.backrestHeight,
            child: Container(
              decoration: BoxDecoration(
                color: theme.backrestColor,
                borderRadius: theme.backrestRadius,
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),

          // 2. Base/Seat cushion (Middle layer)
          Positioned(
            bottom: theme.hasLegs ? 10 : 0, // Lift if legs exist
            left: 5,
            right: 5,
            height: 80,
            child: Container(
              decoration: BoxDecoration(
                color: theme.baseColor,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // 3. Armrests (Front/Side layer)
          Positioned(
            left: 0,
            bottom: theme.hasLegs ? 10 : 0,
            child: Container(
              width: theme.armrestWidth,
              height: theme.armrestHeight,
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
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(1, 0),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: theme.hasLegs ? 10 : 0,
            child: Container(
              width: theme.armrestWidth,
              height: theme.armrestHeight,
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
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(-1, 0),
                  ),
                ],
              ),
            ),
          ),

          // 4. Seat Cushion (Top layer) & Content
          Positioned(
            bottom: theme.hasLegs ? 15 : 5,
            left: 20,
            right: 20,
            top: 25,
            child: Container(
              decoration: BoxDecoration(
                color: theme.cushionColor,
                shape: theme.cushionShape,
                borderRadius: theme.cushionShape == BoxShape.rectangle
                    ? BorderRadius.circular(12)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(child: child),
            ),
          ),
        ],
      ),
    );
  }
}
