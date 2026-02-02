import 'package:emotional/features/room/presentation/manager/room_decoration_cubit.dart';
import 'package:emotional/product/generated/assets.gen.dart';
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

  final AssetGenImage? image;

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
    this.image,
  });

  static FurnitureThemeData getTheme(ArmchairStyle style) {
    switch (style) {
      case ArmchairStyle.vintage:
        return _vintageTheme;
      case ArmchairStyle.clay:
        return _clayTheme;
      case ArmchairStyle.love:
        return _loveTheme;
      case ArmchairStyle.modern:
        return _modernTheme;
      case ArmchairStyle.fwhite:
        return _fWhiteTheme;
      case ArmchairStyle.esce:
        return _esceTheme;
      case ArmchairStyle.lacivert:
        return _lacivertTheme;
      case ArmchairStyle.mor:
        return _morTheme;
      case ArmchairStyle.yesIl:
        return _yesilTheme;
    }
  }

  static final _fWhiteTheme = FurnitureThemeData(
    baseColor: const Color(0xFFFAFAFA), // Off-white
    backrestColor: const Color(0xFFE0E0E0), // Grey 300
    armrestColor: const Color(0xFFBDBDBD), // Grey 400
    armrestGradient: [const Color(0xFFFAFAFA), const Color(0xFFE0E0E0)],
    cushionColor: const Color(0xFFFFFFFF), // White
    shadowColor: Colors.black12,
    backrestRadius: const BorderRadius.all(Radius.circular(20)),
    armrestRadius: const BorderRadius.all(Radius.circular(15)),
    armrestWidth: 15.0,
    armrestHeight: 50.0,
    backrestHeight: 40.0,
    hasLegs: true,
    isTufted: false,
    image: Assets.images.armchair.fwhite,
  );

  static final _loveTheme = FurnitureThemeData(
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
    armrestWidth: 20.0,
    armrestHeight: 45.0,
    backrestHeight: 50.0,
    hasLegs: true,
    isTufted: true,
    cushionShape: BoxShape.circle,
    image: Assets.images.armchair.pembe,
  );

  static final _modernTheme = FurnitureThemeData(
    baseColor: const Color(0xFF26A69A), // Main Color (Teal)
    backrestColor: const Color(0xFF00897B), // Darker Teal
    armrestColor: const Color(0xFF00796B),
    armrestGradient: [const Color(0xFF26A69A), const Color(0xFF00695C)],
    cushionColor: const Color(0xFFE0F2F1), // Lightest cushion part
    shadowColor: Colors.black26,
    backrestRadius: const BorderRadius.only(
      topLeft: Radius.circular(20),
      topRight: Radius.circular(20),
    ),
    armrestRadius: const BorderRadius.only(
      topLeft: Radius.circular(10),
      topRight: Radius.circular(10),
      bottomLeft: Radius.circular(8),
      bottomRight: Radius.circular(8),
    ),
    armrestWidth: 15.0,
    armrestHeight: 50.0,
    backrestHeight: 40.0,
    hasLegs: false,
    cushionShape: BoxShape.rectangle,
    image: Assets.images.armchair.unnamed3,
  );

  static final _cozyTheme = FurnitureThemeData(
    baseColor: const Color(0xFFFFB74D), // Orange 300
    backrestColor: const Color(0xFFF57C00), // Orange 700
    armrestColor: const Color(0xFFEF6C00),
    armrestGradient: [const Color(0xFFFFB74D), const Color(0xFFE65100)],
    cushionColor: const Color(0xFFFFF3E0), // Orange 50
    shadowColor: Colors.black12,
    backrestRadius: const BorderRadius.only(
      topLeft: Radius.circular(25),
      topRight: Radius.circular(25),
    ),
    armrestRadius: const BorderRadius.all(Radius.circular(15)),
    armrestWidth: 20.0,
    armrestHeight: 40.0,
    backrestHeight: 45.0,
    hasLegs: false,
    cushionShape: BoxShape.circle,
    image: Assets.images.armchair.unnamed3,
  );

  static final _vintageTheme = FurnitureThemeData(
    baseColor: const Color(0xFF5D4037), // Brown 700
    backrestColor: const Color(0xFF4E342E), // Brown 800
    armrestColor: const Color(0xFF3E2723), // Brown 900
    armrestGradient: [const Color(0xFF6D4C41), const Color(0xFF3E2723)],
    cushionColor: const Color(0xFF8D6E63), // Brown 400
    shadowColor: Colors.black45,
    backrestRadius: const BorderRadius.only(
      topLeft: Radius.circular(5),
      topRight: Radius.circular(5),
    ),
    armrestRadius: const BorderRadius.only(
      topLeft: Radius.circular(4),
      topRight: Radius.circular(4),
    ),
    armrestWidth: 12.0,
    armrestHeight: 55.0,
    backrestHeight: 50.0,
    hasLegs: true,
    cushionShape: BoxShape.rectangle,
    image: Assets.images.armchair.unnamed6,
  );

  static final _clayTheme = FurnitureThemeData(
    baseColor: const Color(0xFFE57373), // Red 300 (Clay like)
    backrestColor: const Color(0xFFD32F2F), // Red 700
    armrestColor: const Color(0xFFC62828),
    armrestGradient: [const Color(0xFFEF9A9A), const Color(0xFFC62828)],
    cushionColor: const Color(0xFFFFEBEE), // Red 50
    shadowColor: Colors.black12,
    backrestRadius: const BorderRadius.all(Radius.circular(30)),
    armrestRadius: const BorderRadius.all(Radius.circular(20)),
    armrestWidth: 18.0,
    armrestHeight: 45.0,
    backrestHeight: 40.0,
    hasLegs: false,
    isTufted: true,
    cushionShape: BoxShape.circle,
    image: Assets.images.armchair.uzay,
  );

  static final _esceTheme = FurnitureThemeData(
    baseColor: const Color(0xFF1A1D21),
    backrestColor: const Color(0xFF1A1D21),
    armrestColor: const Color(0xFF1A1D21),
    armrestGradient: [const Color(0xFF1A1D21), const Color(0xFF1A1D21)],
    cushionColor: const Color(0xFF1A1D21),
    shadowColor: Colors.black12,
    backrestRadius: BorderRadius.circular(20),
    armrestRadius: BorderRadius.circular(15),
    image: Assets.images.armchair.esce,
  );

  static final _lacivertTheme = FurnitureThemeData(
    baseColor: const Color(0xFF0D47A1),
    backrestColor: const Color(0xFF0D47A1),
    armrestColor: const Color(0xFF0D47A1),
    armrestGradient: [const Color(0xFF0D47A1), const Color(0xFF0D47A1)],
    cushionColor: const Color(0xFF1565C0),
    shadowColor: Colors.black12,
    backrestRadius: BorderRadius.circular(20),
    armrestRadius: BorderRadius.circular(15),
    image: Assets.images.armchair.lacivert,
  );

  static final _morTheme = FurnitureThemeData(
    baseColor: const Color(0xFF4A148C),
    backrestColor: const Color(0xFF4A148C),
    armrestColor: const Color(0xFF4A148C),
    armrestGradient: [const Color(0xFF4A148C), const Color(0xFF4A148C)],
    cushionColor: const Color(0xFF6A1B9A),
    shadowColor: Colors.black12,
    backrestRadius: BorderRadius.circular(20),
    armrestRadius: BorderRadius.circular(15),
    image: Assets.images.armchair.mor,
  );

  static final _yesilTheme = FurnitureThemeData(
    baseColor: const Color(0xFF1B5E20),
    backrestColor: const Color(0xFF1B5E20),
    armrestColor: const Color(0xFF1B5E20),
    armrestGradient: [const Color(0xFF1B5E20), const Color(0xFF1B5E20)],
    cushionColor: const Color(0xFF2E7D32),
    shadowColor: Colors.black12,
    backrestRadius: BorderRadius.circular(20),
    armrestRadius: BorderRadius.circular(15),
    image: Assets.images.armchair.yesIl,
  );
}
