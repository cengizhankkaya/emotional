import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class DraggableCameraOverlay extends StatefulWidget {
  final Offset initialOffset;
  final bool isVideoEnabled;
  final RTCVideoRenderer? localRenderer;
  final Map<String, RTCVideoRenderer> remoteRenderers;
  final Map<String, String> activeUsers;
  final Map<String, bool> userVideoStates;
  final String currentUserId;
  final BoxConstraints constraints;
  final Function(Offset) onPositionChanged;
  final String? activeSpeakerId;

  const DraggableCameraOverlay({
    super.key,
    required this.initialOffset,
    required this.isVideoEnabled,
    this.localRenderer,
    required this.remoteRenderers,
    required this.activeUsers,
    required this.userVideoStates,
    required this.currentUserId,
    required this.constraints,
    required this.onPositionChanged,
    this.activeSpeakerId,
  });

  @override
  State<DraggableCameraOverlay> createState() => _DraggableCameraOverlayState();
}

class _DraggableCameraOverlayState extends State<DraggableCameraOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;
  late Offset _offset;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _offset = widget.initialOffset;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _controller.addListener(() {
      setState(() {
        _offset = _animation.value;
      });
      widget.onPositionChanged(_offset);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DraggableCameraOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldActiveCount =
        oldWidget.activeUsers.length +
        (oldWidget.isVideoEnabled && oldWidget.localRenderer != null ? 1 : 0);
    final newActiveCount =
        widget.activeUsers.length +
        (widget.isVideoEnabled && widget.localRenderer != null ? 1 : 0);

    if (oldActiveCount != newActiveCount ||
        oldWidget.activeSpeakerId != widget.activeSpeakerId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _validatePosition();
      });
    }
  }

  void _validatePosition() {
    final activeCount =
        widget.activeUsers.length +
        (widget.isVideoEnabled && widget.localRenderer != null ? 1 : 0);
    final count = activeCount > 0 ? activeCount : 0;

    // Calculate expected size
    final width = _isExpanded ? (count * 128.0) + 16 : 96.0;
    final height = _isExpanded ? 106.0 : 96.0;

    _snapToCorner(Size(width, height));
  }

  void _snapToCorner(Size size) {
    final endOffset = _calculateSnapPosition(size);
    _animation = Tween<Offset>(
      begin: _offset,
      end: endOffset,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _controller.forward(from: 0);
  }

  Offset _calculateSnapPosition(Size size) {
    // Snap to nearest corner
    final double top = 20;
    final double bottom = widget.constraints.maxHeight - size.height - 20;
    final double left = 20;
    // Ensure we don't return a negative right offset if the widget is wider than the screen
    final double maxRight = widget.constraints.maxWidth - size.width - 20;
    final double right = maxRight > left ? maxRight : left;

    final double distTopLeft = (_offset - Offset(left, top)).distance;
    final double distTopRight = (_offset - Offset(right, top)).distance;
    final double distBottomLeft = (_offset - Offset(left, bottom)).distance;
    final double distBottomRight = (_offset - Offset(right, bottom)).distance;

    final min = [
      distTopLeft,
      distTopRight,
      distBottomLeft,
      distBottomRight,
    ].reduce((curr, next) => curr < next ? curr : next);

    if (min == distTopLeft) return Offset(left, top);
    if (min == distTopRight) return Offset(right, top);
    if (min == distBottomLeft) return Offset(left, bottom);
    return Offset(right, bottom);
  }

  Widget _buildCameraItem(
    String name,
    RTCVideoRenderer? renderer,
    bool isLocal,
    bool hasVideo,
    bool isActiveSpeaker, {
    Key? key,
  }) {
    return GestureDetector(
      onTap: () {
        if (renderer != null && hasVideo) {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9, // Or calculate based on stream size
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: RTCVideoView(
                          renderer,
                          objectFit: RTCVideoViewObjectFit
                              .RTCVideoViewObjectFitContain,
                          mirror: isLocal,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isLocal ? LocaleKeys.room_me.tr() : name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
      child: Container(
        key: key,
        width: _isExpanded ? 120 : 80,
        height: _isExpanded ? 90 : 80, // Square in compact mode
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasVideo && renderer != null)
                RTCVideoView(
                  renderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  mirror: isLocal,
                )
              else
                Container(
                  color: Colors.grey[900],
                  child: const Icon(Icons.person, color: Colors.white54),
                ),

              // Name Tag & Mute Status
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          isLocal ? LocaleKeys.room_me.tr() : name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!hasVideo)
                        const Icon(
                          Icons.videocam_off,
                          color: Colors.redAccent,
                          size: 10,
                        )
                      else ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            if (renderer != null) {
                              showDialog(
                                barrierColor: Colors.black87,
                                context: context,
                                builder: (context) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  insetPadding: const EdgeInsets.all(12),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      AspectRatio(
                                        aspectRatio:
                                            16 /
                                            9, // Or calculate based on stream size
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: Colors.white24,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: RTCVideoView(
                                              renderer,
                                              objectFit: RTCVideoViewObjectFit
                                                  .RTCVideoViewObjectFitContain,
                                              mirror: isLocal,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 10,
                                        right: 10,
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                          ),
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.black54,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 20,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            isLocal
                                                ? LocaleKeys.room_me.tr()
                                                : name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(
                              Icons.open_in_full,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Collect active cameras
    final List<Widget> activeCameras = [];

    // Local
    if (widget.isVideoEnabled && widget.localRenderer != null) {
      activeCameras.add(
        _buildCameraItem(
          LocaleKeys.room_me.tr(),
          widget.localRenderer,
          true,
          true,
          widget.activeSpeakerId == widget.currentUserId,
          key: ValueKey("local_${widget.currentUserId}"),
        ),
      );
    }

    // Remote
    for (final entry in widget.activeUsers.entries) {
      if (entry.key == widget.currentUserId) continue;
      final hasVideo = widget.userVideoStates[entry.key] ?? false;
      activeCameras.add(
        _buildCameraItem(
          entry.value,
          widget.remoteRenderers[entry.key],
          false,
          hasVideo,
          widget.activeSpeakerId == entry.key,
          key: ValueKey("remote_${entry.key}"),
        ),
      );
    }

    if (activeCameras.isEmpty) return const SizedBox.shrink();

    // In Compact Mode, show only first (or active speaker if we had that info)
    final displayCameras = _isExpanded
        ? activeCameras
        : (activeCameras.isNotEmpty ? [activeCameras.first] : []);

    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: GestureDetector(
        onPanStart: (details) {
          _controller.stop();
        },
        onPanUpdate: (details) {
          setState(() {
            _offset += details.delta;
          });
          widget.onPositionChanged(_offset);
        },
        onPanEnd: (details) {
          // Measure size of widget to know boundaries
          // Approximate size based on item count
          final width = _isExpanded
              ? (displayCameras.length * 128.0) + 16
              : 96.0;
          final height = _isExpanded ? 106.0 : 96.0;

          _snapToCorner(Size(width, height));
        },
        onTap: () {
          // Toggle Expand/Collapse
          setState(() {
            _isExpanded = !_isExpanded;
          });

          // Re-snap after resize
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _validatePosition();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(4), // Reduced padding slightly
          constraints: BoxConstraints(
            maxWidth: widget.constraints.maxWidth - 40,
            maxHeight: widget.constraints.maxHeight,
          ),
          /* Removed decoration to hide background structure
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          */
          decoration: BoxDecoration(
            color: Colors.transparent, // Make it transparent
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              // Removed BackdropFilter as well
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: displayCameras
                    .map(
                      (w) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: w,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
