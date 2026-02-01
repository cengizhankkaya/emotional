import 'package:flutter/material.dart';

/// Extension to provide responsive values and utilities based on the screen size.
extension ResponsiveExtension on BuildContext {
  // Screen Dimensions
  double get width => MediaQuery.sizeOf(this).width;
  double get height => MediaQuery.sizeOf(this).height;

  // Breakpoints
  // These values can be adjusted based on the project's specific design needs.
  // Standard breakpoints: Phone < 600, Tablet < 1200, Desktop >= 1200
  bool get isSmallScreen => width < 600;
  bool get isMediumScreen => width >= 600 && width < 1200;
  bool get isLargeScreen => width >= 1200;

  /// Returns a dynamic value based on the screen width.
  /// Useful for handling "zoomed" or very small screens.
  ///
  /// [val] is the standard value designed for a normal screen.
  /// [factor] determines how much the value should shrink on small screens (default 0.8).
  double dynamicValue(double val, {double factor = 0.8}) {
    if (width < 380) {
      // Very small screen or zoomed in
      return val * factor;
    }
    return val;
  }

  /// Returns a dynamic width value relative to the screen width.
  /// [val] is the percentage of the screen width (0.0 to 1.0).
  double dynamicWidth(double val) => width * val;

  /// Returns a dynamic height value relative to the screen height.
  /// [val] is the percentage of the screen height (0.0 to 1.0).
  double dynamicHeight(double val) => height * val;
}
