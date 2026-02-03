import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class FloatingCameraOverlay extends StatelessWidget {
  final Offset offset;
  final bool isVideoEnabled;
  final RTCVideoRenderer? localRenderer;
  final Map<String, RTCVideoRenderer> remoteRenderers;
  final Map<String, String> activeUsers;
  final Map<String, bool> userVideoStates;
  final String currentUserId;
  final BoxConstraints constraints;
  final Function(Offset) onPositionChanged;

  const FloatingCameraOverlay({
    super.key,
    required this.offset,
    required this.isVideoEnabled,
    this.localRenderer,
    required this.remoteRenderers,
    required this.activeUsers,
    required this.userVideoStates,
    required this.currentUserId,
    required this.constraints,
    required this.onPositionChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Collect active cameras
    final List<Widget> activeCameras = [];
    const double camWidth = 100;
    const double camHeight = 75;
    const double spacing = 8.0;

    // Local Camera
    if (isVideoEnabled && localRenderer != null) {
      activeCameras.add(
        _buildCameraContainer(
          'Ben',
          true,
          localRenderer,
          true,
          camWidth,
          camHeight,
        ),
      );
    }

    // Remote Cameras
    for (final entry in activeUsers.entries) {
      final userId = entry.key;
      if (userId == currentUserId) continue;
      if (userVideoStates[userId] ?? false) {
        activeCameras.add(
          _buildCameraContainer(
            entry.value,
            true,
            remoteRenderers[userId],
            false,
            camWidth,
            camHeight,
          ),
        );
      }
    }

    if (activeCameras.isEmpty) return const SizedBox.shrink();

    final totalWidth =
        (activeCameras.length * camWidth) +
        ((activeCameras.length - 1) * spacing);

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          final newX = (offset.dx + details.delta.dx).clamp(
            0.0,
            constraints.maxWidth - totalWidth,
          );
          final newY = (offset.dy + details.delta.dy).clamp(
            0.0,
            constraints.maxHeight - camHeight,
          );
          onPositionChanged(Offset(newX, newY));
        },
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: activeCameras
                .map(
                  (cam) => Padding(
                    padding: EdgeInsets.only(
                      right:
                          activeCameras.indexOf(cam) == activeCameras.length - 1
                          ? 0
                          : spacing,
                    ),
                    child: cam,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraContainer(
    String name,
    bool hasVideo,
    RTCVideoRenderer? renderer,
    bool isLocal,
    double width,
    double height,
  ) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          children: [
            if (hasVideo && renderer != null)
              RTCVideoView(
                renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                mirror: isLocal,
              )
            else
              Container(
                color: Colors.white.withOpacity(0.05),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.05),
                        Colors.transparent,
                        Colors.black.withOpacity(0.1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 2,
              left: 6,
              right: 6,
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
