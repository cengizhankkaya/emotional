import 'package:flutter/material.dart';

/// Keeps [bottom] pinned to the bottom edge when everything fits, and
/// scrolls instead of overflowing when it doesn't (short browser windows,
/// landscape phones).
class PinnedBottomScrollView extends StatelessWidget {
  const PinnedBottomScrollView({
    super.key,
    required this.top,
    required this.bottom,
  });

  final Widget top;
  final Widget bottom;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [top, bottom],
            ),
          ),
        );
      },
    );
  }
}
