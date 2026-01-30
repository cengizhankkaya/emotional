import 'package:flutter/material.dart';

class ArmchairWidget extends StatelessWidget {
  final String? participant;
  final bool isLeft;
  final Widget child;

  const ArmchairWidget({
    super.key,
    required this.participant,
    required this.isLeft,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100, // Slightly wider for arms
      height: 100, // Taller for depth
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 1. Backrest (Rear layer)
          Positioned(
            top: 0,
            left: 10,
            right: 10,
            height: 40,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF00897B), // Darker Teal
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),

          // 2. Base/Seat cushion (Middle layer)
          Positioned(
            bottom: 0,
            left: 5,
            right: 5,
            height: 80,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF26A69A), // Main Color
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // 3. Armrests (Front/Side layer)
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              width: 15,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF00796B), // Darker element
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [const Color(0xFF26A69A), const Color(0xFF00695C)],
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
            bottom: 0,
            child: Container(
              width: 15, // Arm width
              height: 50, // Arm height
              decoration: BoxDecoration(
                color: const Color(0xFF00796B),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [const Color(0xFF26A69A), const Color(0xFF00695C)],
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
            bottom: 5, // Slightly raised
            left: 20,
            right: 20,
            top: 25,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1), // Lightest cushion part
                borderRadius: BorderRadius.circular(12),
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
