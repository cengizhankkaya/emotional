import 'package:flutter/material.dart';

class TableWidget extends StatelessWidget {
  const TableWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF5D4037), // Dark wood color
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          // Deep shadow for ground separation
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
          // Slight reflection/highlight on top
          BoxShadow(
            color: Colors.white.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF8D6E63), // Lighter wood top-left
            Color(0xFF5D4037), // Darker wood bottom-right
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Inner detail (a placemat or glass overlay)
          Container(
            width: 180,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
