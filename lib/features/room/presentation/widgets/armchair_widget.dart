import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';

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
      width: context.dynamicValue(100), // Slightly wider for arms
      height: context.dynamicValue(100), // Taller for depth
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 0. Legs (Bottom layer) - Only if enabled
          if (theme.hasLegs) ...[
            Positioned(
              bottom: 0,
              left: context.dynamicValue(15),
              child: Container(
                width: context.dynamicValue(8),
                height: context.dynamicValue(15),
                color: const Color(0xFF4E342E), // Wood
              ),
            ),
            Positioned(
              bottom: 0,
              right: context.dynamicValue(15),
              child: Container(
                width: context.dynamicValue(8),
                height: context.dynamicValue(15),
                color: const Color(0xFF4E342E),
              ),
            ),
          ],

          // 1. Backrest (Rear layer)
          Positioned(
            top: 0,
            left: context.dynamicValue(10),
            right: context.dynamicValue(10),
            height: context.dynamicValue(theme.backrestHeight),
            child: Container(
              decoration: BoxDecoration(
                color: theme.backrestColor,
                borderRadius: theme
                    .backrestRadius, // Assuming this comes from theme data which might need its own responsive logic or let it be if it's generic BorderRadius
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
            bottom: theme.hasLegs
                ? context.dynamicValue(10)
                : 0, // Lift if legs exist
            left: context.dynamicValue(5),
            right: context.dynamicValue(5),
            height: context.dynamicValue(80),
            child: Container(
              decoration: BoxDecoration(
                color: theme.baseColor,
                borderRadius: ProjectRadius.medium(),
              ),
            ),
          ),

          // 3. Armrests (Front/Side layer)
          Positioned(
            left: 0,
            bottom: theme.hasLegs ? context.dynamicValue(10) : 0,
            child: Container(
              width: context.dynamicValue(theme.armrestWidth),
              height: context.dynamicValue(theme.armrestHeight),
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
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 2,
                    offset: const Offset(1, 0),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: theme.hasLegs ? context.dynamicValue(10) : 0,
            child: Container(
              width: context.dynamicValue(theme.armrestWidth),
              height: context.dynamicValue(theme.armrestHeight),
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
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 2,
                    offset: const Offset(-1, 0),
                  ),
                ],
              ),
            ),
          ),

          // 4. Seat Cushion (Top layer) & Content
          Positioned(
            bottom: theme.hasLegs
                ? context.dynamicValue(15)
                : context.dynamicValue(5),
            left: context.dynamicValue(20),
            right: context.dynamicValue(20),
            top: context.dynamicValue(25),
            child: Container(
              decoration: BoxDecoration(
                color: theme.cushionColor,
                shape: theme.cushionShape,
                borderRadius: theme.cushionShape == BoxShape.rectangle
                    ? ProjectRadius.medium()
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
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
