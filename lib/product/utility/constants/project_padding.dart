import 'package:flutter/material.dart';

/// Centralized padding constants for the application.
/// Use these constants to ensure consistent spacing across the app.
class ProjectPadding extends EdgeInsets {
  const ProjectPadding.allSmall() : super.all(8.0);
  const ProjectPadding.allMedium() : super.all(16.0);
  const ProjectPadding.allLarge() : super.all(24.0);
  const ProjectPadding.allXLarge() : super.all(32.0);

  const ProjectPadding.symmetricHorizontalSmall()
    : super.symmetric(horizontal: 8.0);
  const ProjectPadding.symmetricHorizontalMedium()
    : super.symmetric(horizontal: 16.0);
  const ProjectPadding.symmetricHorizontalLarge()
    : super.symmetric(horizontal: 24.0);

  const ProjectPadding.symmetricVerticalSmall()
    : super.symmetric(vertical: 8.0);
  const ProjectPadding.symmetricVerticalMedium()
    : super.symmetric(vertical: 16.0);
  const ProjectPadding.symmetricVerticalLarge()
    : super.symmetric(vertical: 24.0);

  const ProjectPadding.symmetric({super.vertical, super.horizontal})
    : super.symmetric();

  // Custom Utility Methods for Dynamic Padding
  // Although EdgeInsets doesn't support factory with context easily for const usage,
  // we can use static methods if we strictly need context-aware padding.
  // For now, let's keep it constant-focused.
}
