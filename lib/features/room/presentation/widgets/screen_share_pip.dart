import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class ScreenSharePiP extends StatefulWidget {
  const ScreenSharePiP({super.key});

  @override
  State<ScreenSharePiP> createState() => _ScreenSharePiPState();
}

class _ScreenSharePiPState extends State<ScreenSharePiP> {
  Offset _position = const Offset(20, 50); // Default position
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      // Set initial position to bottom-right (safe area)
      final size = MediaQuery.of(context).size;
      _position = Offset(size.width - 140, size.height - 200);
      _isInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CallBloc, CallState>(
      builder: (context, state) {
        if (state is! CallConnected || !state.isScreenSharing) {
          return const SizedBox.shrink();
        }

        final renderer = state.localRenderer;

        // Ensure we have a valid renderer and it has a stream (screen share)
        // Note: localRenderer usually holds the camera, but during screen share
        // CallBloc updates it to the display stream.
        if (renderer.srcObject == null) {
          return const SizedBox.shrink();
        }

        return Positioned(
          left: _position.dx,
          top: _position.dy,
          child: Draggable(
            feedback: _buildContainer(renderer, isDragging: true),
            childWhenDragging: const SizedBox.shrink(),
            onDraggableCanceled: (velocity, offset) {
              setState(() {
                _position = offset;
              });
            },
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _position += details.delta;
                });
              },
              child: _buildContainer(renderer),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContainer(RTCVideoRenderer renderer, {bool isDragging = false}) {
    return Material(
      color: Colors.transparent,
      elevation: isDragging ? 10 : 5,
      child: Container(
        width: 120,
        height: 180,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Video Preview
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: RTCVideoView(
                renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                mirror: false, // Screen share should NOT be mirrored
              ),
            ),

            // "You are sharing" Label
            Positioned(
              bottom: 8,
              left: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "YAYINDASINIZ",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // Stop Sharing Button (Top Right)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () {
                  context.read<CallBloc>().add(ToggleScreenShare());
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.stop, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
