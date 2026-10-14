import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/call/domain/client_platform.dart';
import 'package:emotional/features/call/presentation/participant_video.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Everyone's camera next to a screen share, as a column beside the stage
/// or a row above it.
///
/// The sharer's tile carries a "sharing" badge and shows their camera if
/// it's on (sent next to the screen), else their initial.
class WebCameraStrip extends StatelessWidget {
  const WebCameraStrip({
    super.key,
    required this.callState,
    required this.participants,
    required this.userNames,
    required this.currentUserId,
    required this.sharingUserId,
    this.axis = Axis.vertical,
  });

  final CallConnected callState;
  final List<String> participants;
  final Map<String, String> userNames;
  final String currentUserId;
  final String sharingUserId;
  final Axis axis;

  /// Cameras first, then the rest; you last, like other call apps.
  List<String> _ordered() {
    int rank(String id) {
      if (id == currentUserId) return 2;
      return _hasVideo(id) ? 0 : 1;
    }

    return [...participants]..sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      return (userNames[a] ?? a).compareTo(userNames[b] ?? b);
    });
  }

  /// The sharer's camera, sent next to their screen when it's on.
  RTCVideoRenderer? _shareCamera(String id) => id == sharingUserId
      ? callState.shareCameraOf(id, localUserId: currentUserId)
      : null;

  bool _hasVideo(String id) {
    if (id == sharingUserId) return _shareCamera(id) != null;
    if (id == currentUserId) return callState.isVideoEnabled;
    return callState.userVideoStates[id] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final ids = _ordered();
    final vertical = axis == Axis.vertical;

    return ListView.separated(
      scrollDirection: axis,
      padding: EdgeInsets.zero,
      itemCount: ids.length,
      separatorBuilder: (_, _) =>
          vertical ? const SizedBox(height: 10) : const SizedBox(width: 10),
      itemBuilder: (context, index) {
        final id = ids[index];
        final isLocal = id == currentUserId;
        final tile = _CameraTile(
          name: isLocal
              ? LocaleKeys.room_me.tr()
              : userNames[id] ?? LocaleKeys.room_someone.tr(),
          renderer:
              _shareCamera(id) ??
              (isLocal
                  ? callState.localRenderer
                  : callState.remoteRenderers[id]),
          hasVideo: _hasVideo(id),
          isMuted: isLocal
              ? callState.isMuted
              : !(callState.userAudioStates[id] ?? true),
          isLocal: isLocal,
          isSharer: id == sharingUserId,
          platform: callState.platformOf(id, localUserId: currentUserId),
        );
        // A row's tiles take their width from the strip's height and the
        // camera's shape; a column's take their height from its width.
        return tile;
      },
    );
  }
}

class _CameraTile extends StatelessWidget {
  const _CameraTile({
    required this.name,
    required this.renderer,
    required this.hasVideo,
    required this.isMuted,
    required this.isLocal,
    required this.isSharer,
    required this.platform,
  });

  final ClientPlatform? platform;
  final String name;
  final RTCVideoRenderer? renderer;
  final bool hasVideo;
  final bool isMuted;
  final bool isLocal;
  final bool isSharer;

  @override
  Widget build(BuildContext context) {
    final renderer = this.renderer;
    final showVideo = hasVideo && renderer != null;
    if (!showVideo) return _buildTile(null, 4 / 3);
    // The tile takes the camera's shape: wide for laptops, tall for phones
    // held upright, and follows a phone being turned.
    return ValueListenableBuilder<RTCVideoValue>(
      valueListenable: renderer,
      builder: (context, value, _) =>
          _buildTile(renderer, videoTileAspectRatio(value)),
    );
  }

  Widget _buildTile(RTCVideoRenderer? renderer, double aspectRatio) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          color: ColorsCustom.darkABlue,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ColorsCustom.white10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (renderer != null)
              ParticipantVideo(
                renderer: renderer,
                mirror: isLocal,
                background: ColorsCustom.darkABlue,
              )
            else
              Center(child: _Initial(name: name)),
            if (isSharer)
              Positioned(
                top: 6,
                left: 6,
                child: Tooltip(
                  // With the camera on, the tile already shows it.
                  message: renderer != null
                      ? LocaleKeys.web_sharingScreen.tr()
                      : LocaleKeys.web_cameraOffWhileSharing.tr(),
                  child: _Pill(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.screen_share,
                          size: 12,
                          color: ColorsCustom.skyBlue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          LocaleKeys.web_sharingScreen.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Row(
                children: [
                  Flexible(
                    child: _Pill(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (platform case final platform?) ...[
                            PlatformBadge(platform: platform),
                            const SizedBox(width: 4),
                          ],
                          if (isMuted) ...[
                            const Icon(
                              Icons.mic_off,
                              size: 12,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ColorsCustom.skyBlue.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Text(
        name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
        style: const TextStyle(
          color: ColorsCustom.skyBlue,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }
}
