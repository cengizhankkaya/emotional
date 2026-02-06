import 'dart:math';
import 'package:flutter/material.dart';

class AudioVisualizer extends StatefulWidget {
  final bool isSpeaking;
  final Color color;
  final int barCount;

  const AudioVisualizer({
    super.key,
    required this.isSpeaking,
    this.color = Colors.greenAccent,
    this.barCount = 4,
  });

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isSpeaking && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    } else if (widget.isSpeaking && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSpeaking) return const SizedBox();

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(widget.barCount, (index) {
        return _AnimatedBar(
          controller: _controller,
          color: widget.color,
          maxHeight: 14.0,
          delay: index * 100, // Stagger animations
        );
      }),
    );
  }
}

class _AnimatedBar extends StatelessWidget {
  final AnimationController controller;
  final Color color;
  final double maxHeight;
  final int delay;

  const _AnimatedBar({
    required this.controller,
    required this.color,
    required this.maxHeight,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // Simple sine wave simulation based on time and delay
        // t varies from 0.0 to 1.0 based on controller value
        double value = controller.value + (delay / 5.0);
        value = value % 1.0;
        final height = 4.0 + (maxHeight * sin(value * pi).abs());

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          width: 3,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      },
    );
  }
}
