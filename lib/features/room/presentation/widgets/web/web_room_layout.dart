import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/features/call/domain/client_platform.dart';
import 'package:emotional/features/call/presentation/participant_video.dart';
import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/call/presentation/screen_share/screen_share_quality_chip.dart';
import 'package:emotional/features/chat/bloc/chat_bloc.dart';
import 'package:emotional/features/chat/presentation/chat_widget.dart';
import 'package:emotional/features/room/domain/entities/room_entity.dart';
import 'package:emotional/features/room/presentation/widgets/participant_video_row.dart';
import 'package:emotional/features/room/presentation/widgets/room_seating_widget.dart';
import 'package:emotional/features/room/presentation/widgets/room_top_bar.dart';
import 'package:emotional/features/room/presentation/widgets/screen_share_video_view.dart';
import 'package:emotional/features/room/presentation/widgets/video_control_sheet.dart';
import 'package:emotional/features/room/presentation/widgets/video_control_sheet/call_controls_bar.dart';
import 'package:emotional/features/room/presentation/widgets/web/web_camera_strip.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:emotional/product/utility/responsiveness/web_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:googleapis/drive/v3.dart' as drive;

/// Room screen for wide browser windows: a stage on the left (seating or the
/// live screen share) with a floating call dock, and a side panel on the
/// right with chat, video picking and the participant list.
class WebRoomLayout extends StatefulWidget {
  const WebRoomLayout({
    super.key,
    required this.roomId,
    required this.participants,
    required this.userNames,
    required this.usersState,
    required this.hostId,
    required this.currentUserId,
    required this.isHost,
    required this.sharingUserId,
    required this.driveFileName,
    required this.driveFileId,
    required this.scaffoldKey,
    required this.onLeave,
    required this.onPickVideo,
    required this.onSelectVideo,
    required this.onPlayVideo,
    required this.onEnterFullscreen,
  });

  final String roomId;
  final List<String> participants;
  final Map<String, String> userNames;
  final Map<String, UserMediaState> usersState;
  final String hostId;
  final String currentUserId;
  final bool isHost;

  /// Who is sharing their screen, if anyone.
  final String? sharingUserId;
  final String? driveFileName;
  final String? driveFileId;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final VoidCallback onLeave;
  final VoidCallback onPickVideo;
  final void Function(drive.File) onSelectVideo;
  final VoidCallback onPlayVideo;
  final VoidCallback onEnterFullscreen;

  @override
  State<WebRoomLayout> createState() => _WebRoomLayoutState();
}

class _WebRoomLayoutState extends State<WebRoomLayout>
    with SingleTickerProviderStateMixin {
  static const int _chatTab = 0;

  late final TabController _tabs = TabController(length: 3, vsync: this)
    ..addListener(_onTabChanged);

  String? _lastSeenMessageId;
  bool _hasUnreadChat = false;

  /// While a screen is on stage the dock gets out of the way when the
  /// pointer rests, like a video player's controls.
  static const _dockIdleDelay = Duration(seconds: 3);

  /// Longer right after a share starts, so the share status in the dock
  /// can be read before both fold away.
  static const _dockShareStartDelay = Duration(seconds: 5);
  Timer? _dockTimer;
  bool _dockVisible = true;
  bool _dockHovered = false;

  bool get _autoHideDock => widget.sharingUserId != null;

  /// Camera strip beside a screen share.
  bool _showCameras = true;

  void _wakeDock({Duration delay = _dockIdleDelay}) {
    if (!_dockVisible) setState(() => _dockVisible = true);
    _dockTimer?.cancel();
    if (!_autoHideDock || _dockHovered) return;
    _dockTimer = Timer(delay, () {
      if (mounted && _autoHideDock && !_dockHovered) {
        setState(() => _dockVisible = false);
      }
    });
  }

  void _setDockHovered(bool hovered) {
    _dockHovered = hovered;
    _wakeDock();
  }

  @override
  void didUpdateWidget(WebRoomLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.sharingUserId == null) != (oldWidget.sharingUserId == null)) {
      _wakeDock(delay: _dockShareStartDelay);
    }
  }

  void _onTabChanged() {
    if (_tabs.index == _chatTab && _hasUnreadChat) {
      setState(() => _hasUnreadChat = false);
    }
  }

  void _onChatState(BuildContext context, ChatState state) {
    if (state is! ChatLoaded) return;
    final last = state.messages.lastOrNull;
    // The history is capped, so compare the newest message, not the count.
    if (last == null || last.id == _lastSeenMessageId) return;
    final isFirstLoad = _lastSeenMessageId == null;
    _lastSeenMessageId = last.id;
    final fromOthers = last.senderId != widget.currentUserId;
    if (!isFirstLoad && fromOthers && _tabs.index != _chatTab) {
      setState(() => _hasUnreadChat = true);
    }
  }

  @override
  void dispose() {
    _dockTimer?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatBloc, ChatState>(
      listener: _onChatState,
      child: SafeArea(
        child: Column(
          children: [
            RoomTopBar(
              roomId: widget.roomId,
              scaffoldKey: widget.scaffoldKey,
              onLeave: widget.onLeave,
              onChatPressed: () => _tabs.animateTo(_chatTab),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildStage()),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: WebLayout.fluidWidth(
                        context,
                        fraction: 0.26,
                        min: 320,
                        max: 420,
                      ),
                      child: _buildSidePanel(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Stage ────────────────────────────────────────────────────────────────

  Widget _buildStage() {
    final sharingUserId = widget.sharingUserId;
    return _Surface(
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerHover: (_) => _wakeDock(),
        onPointerDown: (_) => _wakeDock(),
        child: Stack(
          children: [
            Positioned.fill(
              child: sharingUserId != null
                  ? _ShareStage(
                      sharingUserId: sharingUserId,
                      currentUserId: widget.currentUserId,
                      participants: widget.participants,
                      userNames: widget.userNames,
                      showCameras: _showCameras,
                      onToggleCameras: () =>
                          setState(() => _showCameras = !_showCameras),
                      sharerName:
                          widget.userNames[sharingUserId] ??
                          LocaleKeys.room_someone.tr(),
                      onEnterFullscreen: widget.onEnterFullscreen,
                    )
                  : _SeatingStage(widget: widget),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: Center(
                child: MouseRegion(
                  onEnter: (_) => _setDockHovered(true),
                  onExit: (_) => _setDockHovered(false),
                  child: IgnorePointer(
                    ignoring: !_dockVisible,
                    child: AnimatedSlide(
                      offset: _dockVisible ? Offset.zero : const Offset(0, 0.4),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      child: AnimatedOpacity(
                        opacity: _dockVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: const _ControlDock(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Side panel ───────────────────────────────────────────────────────────

  Widget _buildSidePanel() {
    return _Surface(
      child: Column(
        children: [
          TabBar(
            controller: _tabs,
            indicatorColor: ColorsCustom.skyBlue,
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            dividerColor: ColorsCustom.white10,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            tabs: [
              Tab(
                child: _TabLabel(
                  icon: Icons.chat_bubble_outline,
                  text: LocaleKeys.web_tabChat.tr(),
                  showDot: _hasUnreadChat,
                ),
              ),
              Tab(
                child: _TabLabel(
                  icon: Icons.movie_outlined,
                  text: LocaleKeys.web_tabVideo.tr(),
                ),
              ),
              Tab(
                child: _TabLabel(
                  icon: Icons.people_outline,
                  text:
                      '${LocaleKeys.web_tabPeople.tr()} '
                      '${widget.participants.length}',
                ),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              // Swiping between tabs is a touch idiom; on desktop it fights
              // with text selection in the chat.
              physics: const NeverScrollableScrollPhysics(),
              children: [
                ChatWidget(roomId: widget.roomId, showHeader: false),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: VideoControlSheet(
                    embedded: true,
                    isHost: widget.isHost,
                    roomId: widget.roomId,
                    fileName: widget.driveFileName,
                    fileId: widget.driveFileId,
                    onPickVideo: widget.onPickVideo,
                    onSelectVideo: widget.onSelectVideo,
                    onPlay: widget.onPlayVideo,
                  ),
                ),
                _PeopleList(widget: widget),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded dark card used for the stage and the side panel.
class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ColorsCustom.darkABlue,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ColorsCustom.white10),
      ),
      child: child,
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.icon,
    required this.text,
    this.showDot = false,
  });

  final IconData icon;
  final String text;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
        if (showDot) ...[
          const SizedBox(width: 6),
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: ColorsCustom.cream,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}

class _SeatingStage extends StatelessWidget {
  const _SeatingStage({required this.widget});

  final WebRoomLayout widget;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ParticipantVideoRow(
          participants: widget.participants,
          userNames: widget.userNames,
          currentUserId: widget.currentUserId,
          roomId: widget.roomId,
          hostId: widget.hostId,
          usersState: widget.usersState,
        ),
        Expanded(
          child: Padding(
            // Keep the seats clear of the floating control dock.
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 96),
            child: RoomSeatingWidget(
              participants: widget.participants,
              userNames: widget.userNames,
              isHost: widget.isHost,
              currentUserId: widget.currentUserId,
              roomId: widget.roomId,
              hostId: widget.hostId,
              usersState: widget.usersState,
            ),
          ),
        ),
      ],
    );
  }
}

class _ShareStage extends StatelessWidget {
  const _ShareStage({
    required this.sharingUserId,
    required this.currentUserId,
    required this.participants,
    required this.userNames,
    required this.showCameras,
    required this.onToggleCameras,
    required this.sharerName,
    required this.onEnterFullscreen,
  });

  /// Below this stage width the cameras go in a row above the share.
  static const double _sideStripMinWidth = 720;

  final String sharingUserId;
  final String currentUserId;
  final List<String> participants;
  final Map<String, String> userNames;
  final bool showCameras;
  final VoidCallback onToggleCameras;
  final String sharerName;
  final VoidCallback onEnterFullscreen;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CallBloc, CallState>(
      builder: (context, state) {
        final renderer = state is! CallConnected
            ? null
            : sharingUserId == currentUserId
            ? state.localRenderer
            : state.remoteRenderers[sharingUserId];
        // Alone in the room there is nobody else's camera to show.
        final hasOthers = participants.length > 1;

        final share = Stack(
          children: [
            if (renderer != null)
              Positioned.fill(child: ScreenShareVideoView(renderer)),
            Positioned(
              top: 12,
              left: 12,
              child: Row(
                children: [
                  _Badge(
                    icon: Icons.screen_share,
                    text: LocaleKeys.call_sharing.tr(args: [sharerName]),
                  ),
                  // Only the sharer can see what is actually sent.
                  if (sharingUserId == currentUserId) ...[
                    const SizedBox(width: 8),
                    const ScreenShareQualityChip(),
                  ],
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  if (hasOthers)
                    _StageButton(
                      tooltip: showCameras
                          ? LocaleKeys.web_hideCameras.tr()
                          : LocaleKeys.web_showCameras.tr(),
                      icon: showCameras
                          ? Icons.videocam_off_outlined
                          : Icons.video_camera_front_outlined,
                      onPressed: onToggleCameras,
                    ),
                  const SizedBox(width: 6),
                  _StageButton(
                    tooltip: null,
                    icon: Icons.fullscreen,
                    onPressed: onEnterFullscreen,
                  ),
                ],
              ),
            ),
          ],
        );

        return Container(
          color: Colors.black,
          padding: const EdgeInsets.only(bottom: 88),
          child: state is! CallConnected || !showCameras || !hasOthers
              ? share
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final side = constraints.maxWidth >= _sideStripMinWidth;
                    final strip = WebCameraStrip(
                      callState: state,
                      participants: participants,
                      userNames: userNames,
                      currentUserId: currentUserId,
                      sharingUserId: sharingUserId,
                      axis: side ? Axis.vertical : Axis.horizontal,
                    );
                    if (side) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: share),
                          SizedBox(
                            width: (constraints.maxWidth * 0.2).clamp(160, 240),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 12, 12, 0),
                              child: strip,
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        SizedBox(
                          height: 144,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                            child: strip,
                          ),
                        ),
                        Expanded(child: share),
                      ],
                    );
                  },
                ),
        );
      },
    );
  }
}

class _StageButton extends StatelessWidget {
  const _StageButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String? tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      style: IconButton.styleFrom(backgroundColor: Colors.black54),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: ColorsCustom.skyBlue),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Floating pill with the call controls (mic, camera, share, settings).
class _ControlDock extends StatelessWidget {
  const _ControlDock();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 460),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: ColorsCustom.darkBlue.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: ColorsCustom.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const CallControlsBar(),
    );
  }
}

class _PeopleList extends StatelessWidget {
  const _PeopleList({required this.widget});

  final WebRoomLayout widget;

  @override
  Widget build(BuildContext context) {
    final people = [...widget.participants]
      ..sort((a, b) {
        // Host first, then you, then the rest by name.
        int rank(String id) => id == widget.hostId
            ? 0
            : id == widget.currentUserId
            ? 1
            : 2;
        final byRank = rank(a).compareTo(rank(b));
        if (byRank != 0) return byRank;
        return (widget.userNames[a] ?? a).compareTo(widget.userNames[b] ?? b);
      });

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: people.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, indent: 72, color: ColorsCustom.white10),
      itemBuilder: (context, index) {
        final id = people[index];
        final name = widget.userNames[id] ?? id;
        final media = widget.usersState[id];
        final isHost = id == widget.hostId;
        final isYou = id == widget.currentUserId;
        final platform =
            ClientPlatform.fromName(media?.platform) ??
            (isYou ? ClientPlatform.current : null);
        final subtitle = [
          if (media?.isScreenSharing == true)
            LocaleKeys.web_sharingScreen.tr()
          else if (isHost)
            LocaleKeys.web_host.tr(),
          if (platform != null)
            LocaleKeys.call_platform_connectedFrom.tr(
              args: [PlatformBadge.labelFor(platform)],
            ),
        ].join(' · ');

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: ColorsCustom.skyBlue.withValues(alpha: 0.2),
            foregroundColor: ColorsCustom.skyBlue,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              if (isYou)
                Text(
                  '  (${LocaleKeys.room_me.tr()})',
                  style: const TextStyle(color: Colors.white54),
                ),
              if (isHost) ...[
                const SizedBox(width: 6),
                const Icon(Icons.star, size: 14, color: ColorsCustom.cream),
              ],
            ],
          ),
          subtitle: subtitle.isEmpty
              ? null
              : Row(
                  children: [
                    if (platform != null) ...[
                      PlatformBadge(
                        platform: platform,
                        color: Colors.white54,
                        showTooltip: false,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                media?.isAudioEnabled == true ? Icons.mic : Icons.mic_off,
                size: 18,
                color: media?.isAudioEnabled == true
                    ? Colors.white70
                    : Colors.redAccent,
              ),
              const SizedBox(width: 10),
              Icon(
                media?.isVideoEnabled == true
                    ? Icons.videocam
                    : Icons.videocam_off,
                size: 18,
                color: media?.isVideoEnabled == true
                    ? Colors.white70
                    : Colors.white30,
              ),
            ],
          ),
        );
      },
    );
  }
}
