import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Responsive rules for the browser build.
///
/// * Below [breakpoint] browsers get the mobile design, kept to a readable
///   column ([WebContentWidth]) instead of stretching edge to edge.
/// * From [breakpoint] up, the desktop layouts take over and scale their
///   columns with the window.
///
/// Native builds always keep the mobile design.
abstract final class WebLayout {
  static const double breakpoint = 900;

  /// Widest a single mobile-style column gets in a browser.
  static const double columnMaxWidth = 560;

  /// Applies to every dialog unless it sets its own constraints.
  static const BoxConstraints dialogConstraints = BoxConstraints(
    minWidth: 280,
    maxWidth: 560,
  );

  /// Applies to every modal bottom sheet unless it sets its own constraints.
  static const BoxConstraints bottomSheetConstraints = BoxConstraints(
    maxWidth: 640,
  );

  static bool isWide(BuildContext context) =>
      kIsWeb && MediaQuery.sizeOf(context).width >= breakpoint;

  /// [fraction] of the window width, kept between [min] and [max]; for side
  /// columns that should grow with the window.
  static double fluidWidth(
    BuildContext context, {
    required double fraction,
    required double min,
    required double max,
  }) => (MediaQuery.sizeOf(context).width * fraction).clamp(min, max);
}

/// Keeps mobile-style content to a centred, readable column in browsers.
/// Does nothing on native builds.
class WebContentWidth extends StatelessWidget {
  const WebContentWidth({
    super.key,
    required this.child,
    this.maxWidth = WebLayout.columnMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
