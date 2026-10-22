import 'dart:math' as math;

import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// The cameras in a window over the screen share, so the share can use the
/// whole stage. Drag the window anywhere on the stage and pull its corner
/// to resize it; a wide window lays the cameras out in a row, a tall one
/// in a column.
///
/// Fills its parent (a [Stack] over the share) but only the window takes
/// pointer events.
class FloatingCameraWindow extends StatefulWidget {
  const FloatingCameraWindow({
    super.key,
    required this.cameraCount,
    required this.builder,
  });

  /// Sets the window's starting height.
  final int cameraCount;

  /// The cameras, laid out along [axis].
  final Widget Function(BuildContext context, Axis axis) builder;

  @override
  State<FloatingCameraWindow> createState() => _FloatingCameraWindowState();
}

class _FloatingCameraWindowState extends State<FloatingCameraWindow> {
  static const double _margin = 12;

  /// Clear of the share's buttons in the top right corner.
  static const double _initialTop = 60;
  static const double _defaultWidth = 200;
  static const double _handleHeight = 20;
  static const double _padding = 8;
  static const Size _minSize = Size(140, 100);

  /// Kept from the right edge, so the window stays in its corner when the
  /// stage grows (fullscreen, chat hidden).
  double _right = _margin;
  double _top = _initialTop;

  /// Null until the user resizes: then sized for [cameraCount].
  Size? _size;
  Size _stage = Size.zero;

  Size _defaultSize() {
    // 4:3 tiles, the tallest shape a laptop camera tile takes.
    final tile = (_defaultWidth - 2 * _padding) * 3 / 4;
    final count = math.max(1, widget.cameraCount);
    return Size(
      _defaultWidth,
      _handleHeight + _padding + count * tile + (count - 1) * 10 + _padding,
    );
  }

  Size _clampSize(Size size, {double? right, double? top}) {
    final maxWidth = math.max(
      _minSize.width,
      math.min(_stage.width * 0.8, _stage.width - (right ?? 0)),
    );
    final maxHeight = math.max(_minSize.height, _stage.height - (top ?? 0));
    return Size(
      size.width.clamp(_minSize.width, maxWidth),
      size.height.clamp(_minSize.height, maxHeight),
    );
  }

  Size get _currentSize => _clampSize(_size ?? _defaultSize());

  double get _maxRight => math.max(0, _stage.width - _currentSize.width);
  double get _maxTop => math.max(0, _stage.height - _currentSize.height);

  void _move(DragUpdateDetails details) {
    setState(() {
      _right = (_right.clamp(0, _maxRight) - details.delta.dx).clamp(
        0,
        _maxRight,
      );
      _top = (_top.clamp(0, _maxTop) + details.delta.dy).clamp(0, _maxTop);
    });
  }

  /// The handle sits in the bottom left corner: the window is anchored to
  /// the right, so pulling left widens it.
  void _resize(DragUpdateDetails details) {
    final right = _right.clamp(0, _maxRight).toDouble();
    final top = _top.clamp(0, _maxTop).toDouble();
    final current = _currentSize;
    setState(() {
      _right = right;
      _top = top;
      _size = _clampSize(
        Size(
          current.width - details.delta.dx,
          current.height + details.delta.dy,
        ),
        right: right,
        top: top,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _stage = constraints.biggest;
        final size = _currentSize;
        final axis = size.width > size.height * 1.2
            ? Axis.horizontal
            : Axis.vertical;

        return Stack(
          children: [
            Positioned(
              right: _right.clamp(0, _maxRight),
              top: _top.clamp(0, _maxTop),
              width: size.width,
              height: size.height,
              child: GestureDetector(
                // Follow the pointer from the first pixel.
                dragStartBehavior: DragStartBehavior.down,
                onPanUpdate: _move,
                child: MouseRegion(
                  cursor: SystemMouseCursors.move,
                  child: _buildWindow(context, axis),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWindow(BuildContext context, Axis axis) {
    return Container(
      decoration: BoxDecoration(
        color: ColorsCustom.darkBlue.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorsCustom.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(
                height: _handleHeight,
                child: Icon(
                  Icons.drag_handle_rounded,
                  size: 16,
                  color: Colors.white38,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _padding,
                    0,
                    _padding,
                    _padding,
                  ),
                  child: widget.builder(context, axis),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: GestureDetector(
              // Follow the pointer from the first pixel.
              dragStartBehavior: DragStartBehavior.down,
              onPanUpdate: _resize,
              child: const MouseRegion(
                cursor: SystemMouseCursors.resizeDownLeft,
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: EdgeInsets.all(3),
                      child: _CornerGrip(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two short diagonal lines, the usual "pull here to resize" mark.
class _CornerGrip extends StatelessWidget {
  const _CornerGrip();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(size: Size(10, 10), painter: _CornerGripPainter());
  }
}

class _CornerGripPainter extends CustomPainter {
  const _CornerGripPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    // Lines parallel to the top-left/bottom-right diagonal, in the bottom
    // left corner.
    canvas.drawLine(
      Offset(0, size.height * 0.2),
      Offset(size.width * 0.8, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.6),
      Offset(size.width * 0.4, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CornerGripPainter oldDelegate) => false;
}
