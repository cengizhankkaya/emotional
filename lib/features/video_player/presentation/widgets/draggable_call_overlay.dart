import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/call/presentation/call_widget.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DraggableCallOverlay extends StatelessWidget {
  final double offsetX;
  final double offsetY;
  final bool isDragging;
  final VoidCallback onPanStart;
  final Function(DragUpdateDetails) onPanUpdate;
  final Function(DragEndDetails) onPanEnd;
  final VoidCallback onPanCancel;

  const DraggableCallOverlay({
    super.key,
    required this.offsetX,
    required this.offsetY,
    required this.isDragging,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onPanCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: isDragging ? Duration.zero : const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      top: offsetY,
      left: offsetX,
      child: GestureDetector(
        onPanStart: (_) => onPanStart(),
        onPanUpdate: onPanUpdate,
        onPanEnd: onPanEnd,
        onPanCancel: onPanCancel,
        child: BlocBuilder<CallBloc, CallState>(
          builder: (context, state) {
            if (state is! CallConnected) return const SizedBox.shrink();
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.dynamicValue(320),
                maxHeight: context.dynamicValue(400),
              ),
              child: const CallWidget(),
            );
          },
        ),
      ),
    );
  }
}
