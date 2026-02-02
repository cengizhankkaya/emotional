import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';

import 'package:emotional/features/room/presentation/manager/room_decoration_cubit.dart';

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
    return SizedBox(
      width: context.dynamicValue(100),
      height: context.dynamicValue(100),
      // Transparent placeholder
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Avatar Layer
          Positioned(
            bottom: context.dynamicValue(
              25,
            ), // Approximate seat height correction
            child: SizedBox(
              width: context.dynamicValue(50),
              height: context.dynamicValue(50),
              child: Center(child: child),
            ),
          ),
        ],
      ),
    );
  }
}
