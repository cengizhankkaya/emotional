import 'package:emotional/features/room/presentation/manager/room_decoration_cubit.dart';
import 'package:flutter/material.dart';

class FurnitureThemeData {
  final Color baseColor;
  final Color backrestColor;
  final Color armrestColor;
  final List<Color> armrestGradient;
  final Color cushionColor;
  final Color shadowColor;
  final BorderRadiusGeometry backrestRadius;
  final BorderRadiusGeometry armrestRadius;

  // Structural properties
  final double armrestWidth;
  final double armrestHeight;
  final double backrestHeight;
  final bool hasLegs;
  final bool isTufted;
  final BoxShape cushionShape;

  const FurnitureThemeData({
    required this.baseColor,
    required this.backrestColor,
    required this.armrestColor,
    required this.armrestGradient,
    required this.cushionColor,
    required this.shadowColor,
    required this.backrestRadius,
    required this.armrestRadius,
    this.armrestWidth = 15.0,
    this.armrestHeight = 50.0,
    this.backrestHeight = 40.0,
    this.hasLegs = false,
    this.isTufted = false,
    this.cushionShape = BoxShape.rectangle,
  });

  static FurnitureThemeData getTheme(ArmchairStyle style) {
    switch (style) {
      case ArmchairStyle.cozy:
        return _cozyTheme;
      case ArmchairStyle.vintage:
        return _vintageTheme;
      case ArmchairStyle.clay:
        return _clayTheme;
      case ArmchairStyle.love:
        return _loveTheme;
      case ArmchairStyle.modern:
        return _modernTheme;
    }
  }

  static const _loveTheme = FurnitureThemeData(
    baseColor: Color(0xFFF06292), // Pink 300
    backrestColor: Color(0xFFD81B60), // Pink 600
    armrestColor: Color(0xFFC2185B), // Pink 700
    armrestGradient: [Color(0xFFF48FB1), Color(0xFFC2185B)],
    cushionColor: Color(0xFFFCE4EC), // Pink 50
    shadowColor: Colors.black12,
    backrestRadius: BorderRadius.only(
      topLeft: Radius.circular(40),
      topRight: Radius.circular(40),
    ),
    armrestRadius: BorderRadius.all(Radius.circular(25)),
    // Structural
    armrestWidth: 20.0,
    armrestHeight: 45.0,
    backrestHeight: 50.0,
    hasLegs: true, // Maybe cute little legs
    isTufted: true,
    cushionShape: BoxShape.circle, // Rounded cushions
  );

  static const _modernTheme = FurnitureThemeData(
    baseColor: Color(0xFF26A69A), // Main Color (Teal)
    backrestColor: Color(0xFF00897B), // Darker Teal
    armrestColor: Color(0xFF00796B),
    armrestGradient: [Color(0xFF26A69A), Color(0xFF00695C)],
    cushionColor: Color(0xFFE0F2F1), // Lightest cushion part
    shadowColor: Colors.black26,
    backrestRadius: BorderRadius.only(
      topLeft: Radius.circular(20),
      topRight: Radius.circular(20),
    ),
    armrestRadius: BorderRadius.only(
      topLeft: Radius.circular(10),
      topRight: Radius.circular(10),
      bottomLeft: Radius.circular(8),
      bottomRight: Radius.circular(8),
    ),
    // Standard boxy
    armrestWidth: 15.0,
    armrestHeight: 50.0,
    backrestHeight: 40.0,
    hasLegs: false,
    cushionShape: BoxShape.rectangle,
  );

  static const _cozyTheme = FurnitureThemeData(
    baseColor: Color(0xFFFFB74D), // Orange 300
    backrestColor: Color(0xFFF57C00), // Orange 700
    armrestColor: Color(0xFFEF6C00),
    armrestGradient: [Color(0xFFFFB74D), Color(0xFFE65100)],
    cushionColor: Color(0xFFFFF3E0), // Orange 50
    shadowColor: Colors.black12,
    backrestRadius: BorderRadius.only(
      topLeft: Radius.circular(25),
      topRight: Radius.circular(25),
    ),
    armrestRadius: BorderRadius.all(Radius.circular(15)),
    // Low, wide, puffy
    armrestWidth: 20.0,
    armrestHeight: 40.0,
    backrestHeight: 45.0,
    hasLegs: false,
    cushionShape: BoxShape.circle,
  );

  static const _vintageTheme = FurnitureThemeData(
    baseColor: Color(0xFF5D4037), // Brown 700
    backrestColor: Color(0xFF4E342E), // Brown 800
    armrestColor: Color(0xFF3E2723), // Brown 900
    armrestGradient: [Color(0xFF6D4C41), Color(0xFF3E2723)],
    cushionColor: Color(0xFF8D6E63), // Brown 400
    shadowColor: Colors.black45,
    backrestRadius: BorderRadius.only(
      topLeft: Radius.circular(5),
      topRight: Radius.circular(5),
    ),
    armrestRadius: BorderRadius.only(
      topLeft: Radius.circular(4),
      topRight: Radius.circular(4),
    ),
    // Tapered, legs
    armrestWidth: 12.0,
    armrestHeight: 55.0,
    backrestHeight: 50.0,
    hasLegs: true,
    cushionShape: BoxShape.rectangle,
  );

  static const _clayTheme = FurnitureThemeData(
    baseColor: Color(0xFFE57373), // Red 300 (Clay like)
    backrestColor: Color(0xFFD32F2F), // Red 700
    armrestColor: Color(0xFFC62828),
    armrestGradient: [Color(0xFFEF9A9A), Color(0xFFC62828)],
    cushionColor: Color(0xFFFFEBEE), // Red 50
    shadowColor: Colors.black12,
    backrestRadius: BorderRadius.all(Radius.circular(30)),
    armrestRadius: BorderRadius.all(Radius.circular(20)),
    // Very rounded
    armrestWidth: 18.0,
    armrestHeight: 45.0,
    backrestHeight: 40.0,
    hasLegs: false,
    isTufted: true,
    cushionShape: BoxShape.circle,
  );
}
