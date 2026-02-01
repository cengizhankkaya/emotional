import 'package:flutter/material.dart';

/// Centralized radius constants for the application.
/// Use these constants to ensure consistent border radius across the app.
class ProjectRadius extends BorderRadius {
  ProjectRadius.small() : super.circular(8.0);
  ProjectRadius.medium() : super.circular(16.0);
  ProjectRadius.large() : super.circular(24.0);
  ProjectRadius.xlarge() : super.circular(32.0);

  ProjectRadius.circular() : super.circular(100.0); // Fully rounded

  // Static constant for simple usage in Radius type
  static const Radius smallRadius = Radius.circular(8.0);
  static const Radius mediumRadius = Radius.circular(16.0);
  static const Radius largeRadius = Radius.circular(24.0);
}
