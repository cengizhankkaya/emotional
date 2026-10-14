import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/core/services/drive_service.dart';
import 'package:emotional/core/services/drive_stream/drive_stream.dart';
import 'package:emotional/features/auth/services/social_auth_credentials.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:googleapis/drive/v3.dart' as drive;

/// Returns a Drive access token; [silentOnly] must not open a popup.
typedef DriveTokenLookup = Future<String?> Function({bool silentOnly});

enum _Status { checking, needsConnect, googleOnly, loading, ready, failed }

/// Browser version of the video picker: a large dialog that lists the
/// user's Drive videos with search, newest first.
///
/// Phones keep the tabbed picker; downloads and the gallery don't exist in a
/// browser. Drive access is only requested from the connect button, because
/// browsers block the Google popup unless it follows a click.
class WebDrivePickerDialog extends StatefulWidget {
  const WebDrivePickerDialog({
    super.key,
    this.currentFileId,
    @visibleForTesting this.tokenLookup,
  });

  /// Marked as playing in the grid.
  final String? currentFileId;

  /// Defaults to the token from the Google sign-in.
  final DriveTokenLookup? tokenLookup;

  static Future<drive.File?> show(
    BuildContext context, {
    String? currentFileId,
  }) {
    return showDialog<drive.File>(
      context: context,
      builder: (_) => WebDrivePickerDialog(currentFileId: currentFileId),
    );
  }

  @override
  State<WebDrivePickerDialog> createState() => _WebDrivePickerDialogState();
}

class _WebDrivePickerDialogState extends State<WebDrivePickerDialog> {
  static const int _pageSize = 30;
  static const double _gridPadding = 24;
  static const double _gridSpacing = 16;
  static const double _minTileWidth = 220;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  _Status _status = _Status.checking;
  List<drive.File> _files = [];
  String? _nextPageToken;
  bool _isLoadingMore = false;
  bool _isConnecting = false;
  String? _connectError;
  String _search = '';

  /// Responses for an older search or page are dropped.
  int _requestId = 0;

  bool get _isConnected =>
      _status == _Status.loading ||
      _status == _Status.ready ||
      _status == _Status.failed;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _start();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<String?> _token({bool silentOnly = false}) {
    final lookup = widget.tokenLookup;
    if (lookup != null) return lookup(silentOnly: silentOnly);
    return SocialAuthCredentials.webDriveAccessToken(
      FirebaseAuth.instance,
      silentOnly: silentOnly,
    );
  }

  Future<void> _start() async {
    final token = await _token(silentOnly: true);
    if (!mounted) return;
    if (token == null) {
      setState(() => _status = _Status.needsConnect);
    } else {
      await _load();
    }
  }

  /// Runs from the connect button so the Google popup counts as a click.
  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
      _connectError = null;
    });
    try {
      final token = await _token();
      if (!mounted) return;
      if (token == null) {
        setState(() => _status = _Status.googleOnly);
        return;
      }
      await _load();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final closedByUser =
          e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request';
      setState(() {
        _connectError = closedByUser
            ? null
            : e.code == 'popup-blocked'
            ? LocaleKeys.drive_popupBlocked.tr()
            : e.message ?? e.code;
      });
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _load({bool more = false}) async {
    final requestId = ++_requestId;
    setState(() {
      if (more) {
        _isLoadingMore = true;
      } else {
        _status = _Status.loading;
        _files = [];
        _nextPageToken = null;
        _isLoadingMore = false;
      }
    });

    final result = await context.read<DriveService>().listVideoFiles(
      pageSize: _pageSize,
      pageToken: more ? _nextPageToken : null,
      search: _search,
      // Never open a popup from here; the connect button does that.
      silentOnly: true,
    );
    if (!mounted || requestId != _requestId) return;

    if (result == null) {
      // The token may have run out while the dialog was open.
      final token = await _token(silentOnly: true);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _isLoadingMore = false;
        if (token == null) {
          _status = _Status.needsConnect;
        } else if (!more) {
          _status = _Status.failed;
        }
      });
      return;
    }

    setState(() {
      _files = [..._files, ...?result.files];
      _nextPageToken = result.nextPageToken;
      _isLoadingMore = false;
      _status = _Status.ready;
    });
  }

  void _onScroll() {
    final position = _scrollController.position;
    final nearEnd = position.pixels >= position.maxScrollExtent - 300;
    if (nearEnd &&
        _status == _Status.ready &&
        !_isLoadingMore &&
        _nextPageToken != null) {
      _load(more: true);
    }
  }

  void _onSearchChanged(String value) {
    setState(() {}); // Shows or hides the clear button.
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      final query = value.trim();
      if (query == _search) return;
      _search = query;
      _load();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 700;
    final radius = BorderRadius.circular(compact ? 0 : 20);

    return Dialog(
      backgroundColor: ColorsCustom.darkABlue,
      insetPadding: compact ? EdgeInsets.zero : const EdgeInsets.all(24),
      // Opts out of the narrow default dialog width.
      constraints: const BoxConstraints(),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: ColorsCustom.white10),
      ),
      child: SizedBox(
        width: compact ? size.width : math.min(1040, size.width - 48),
        height: compact
            ? size.height
            : (size.height - 48).clamp(420, 760).toDouble(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            if (_isConnected) _buildSearchBar(),
            const Divider(height: 1, color: ColorsCustom.white10),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ColorsCustom.skyBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.add_to_drive_outlined,
              color: ColorsCustom.skyBlue,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleKeys.drive_webTitle.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  LocaleKeys.drive_webSubtitle.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          if (_isConnected)
            IconButton(
              tooltip: LocaleKeys.drive_refresh.tr(),
              onPressed: _status == _Status.loading ? null : _load,
              icon: const Icon(Icons.refresh, color: Colors.white70),
            ),
          IconButton(
            tooltip: LocaleKeys.button_close.tr(),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        cursorColor: ColorsCustom.skyBlue,
        decoration: InputDecoration(
          isDense: true,
          hintText: LocaleKeys.drive_searchHint.tr(),
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white54),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.close, size: 18),
                  color: Colors.white54,
                ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ColorsCustom.skyBlue),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _Status.checking:
      case _Status.loading:
        return _buildGrid(
          itemCount: 8,
          itemBuilder: (_, _) => const _TileSkeleton(),
        );
      case _Status.needsConnect:
        return _Message(
          icon: Icons.add_to_drive_outlined,
          title: LocaleKeys.drive_connectTitle.tr(),
          description: LocaleKeys.drive_connectDesc.tr(),
          error: _connectError,
          action: FilledButton.icon(
            onPressed: _isConnecting ? null : _connect,
            style: FilledButton.styleFrom(
              backgroundColor: ColorsCustom.skyBlue,
              foregroundColor: ColorsCustom.darkBlue,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
            icon: _isConnecting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ColorsCustom.darkBlue,
                    ),
                  )
                : const Icon(Icons.link),
            label: Text(LocaleKeys.drive_connectButton.tr()),
          ),
        );
      case _Status.googleOnly:
        return _Message(
          icon: Icons.info_outline,
          title: LocaleKeys.drive_connectTitle.tr(),
          description: LocaleKeys.drive_googleOnly.tr(),
        );
      case _Status.failed:
        return _Message(
          icon: Icons.cloud_off_outlined,
          title: LocaleKeys.error_title.tr(),
          description: LocaleKeys.drive_loadFailed.tr(),
          action: OutlinedButton.icon(
            onPressed: _load,
            style: OutlinedButton.styleFrom(
              foregroundColor: ColorsCustom.skyBlue,
              side: const BorderSide(color: ColorsCustom.skyBlue),
            ),
            icon: const Icon(Icons.refresh),
            label: Text(LocaleKeys.button_retry.tr()),
          ),
        );
      case _Status.ready:
        if (_files.isEmpty) {
          return _Message(
            icon: Icons.video_library_outlined,
            title: _search.isEmpty
                ? LocaleKeys.drive_noVideosFound.tr()
                : LocaleKeys.drive_noSearchResults.tr(args: [_search]),
          );
        }
        return _buildGrid(
          itemCount: _files.length,
          controller: _scrollController,
          footer: _isLoadingMore
              ? const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: ColorsCustom.skyBlue,
                    ),
                  ),
                )
              : null,
          itemBuilder: (context, index) {
            final file = _files[index];
            return _DriveTile(
              file: file,
              isPlaying: file.id == widget.currentFileId,
              onTap: () => Navigator.of(context).pop(file),
            );
          },
        );
    }
  }

  /// Columns follow the dialog width; each tile is a 16:9 thumbnail plus a
  /// fixed caption area.
  Widget _buildGrid({
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    ScrollController? controller,
    Widget? footer,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - _gridPadding * 2;
        final columns = math.max(
          1,
          ((available + _gridSpacing) / (_minTileWidth + _gridSpacing)).floor(),
        );
        final tileWidth = (available - _gridSpacing * (columns - 1)) / columns;

        return CustomScrollView(
          controller: controller,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(_gridPadding),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: _gridSpacing,
                  crossAxisSpacing: _gridSpacing,
                  mainAxisExtent: tileWidth * 9 / 16 + _DriveTile.captionHeight,
                ),
                delegate: SliverChildBuilderDelegate(
                  itemBuilder,
                  childCount: itemCount,
                ),
              ),
            ),
            if (footer != null) SliverToBoxAdapter(child: footer),
          ],
        );
      },
    );
  }
}

class _DriveTile extends StatefulWidget {
  const _DriveTile({
    required this.file,
    required this.isPlaying,
    required this.onTap,
  });

  static const double captionHeight = 74;

  final drive.File file;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  State<_DriveTile> createState() => _DriveTileState();
}

class _DriveTileState extends State<_DriveTile> {
  bool _hovered = false;

  /// MKV, HEVC in MOV and the like often don't play in a browser.
  bool get _mayPlay {
    final mimeType = widget.file.mimeType;
    return mimeType == null || browserMayPlay(mimeType);
  }

  /// Drive hands out 220px thumbnails; ask for a sharper one.
  String? get _thumbnailUrl =>
      widget.file.thumbnailLink?.replaceFirst(RegExp(r'=s\d+$'), '=s480');

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    final highlighted = _hovered || widget.isPlaying;
    final meta = [
      if (file.size != null) _formatSize(file.size!),
      if (file.modifiedTime != null)
        DateFormat.yMMMd(
          context.locale.toLanguageTag(),
        ).format(file.modifiedTime!.toLocal()),
    ].where((part) => part.isNotEmpty).join(' · ');
    final duration = _formatDuration(file.videoMediaMetadata?.durationMillis);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _hovered ? 0.08 : 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlighted ? ColorsCustom.skyBlue : ColorsCustom.white10,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildThumbnail(),
                    if (duration != null)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: _Badge(text: duration),
                      ),
                    if (!_mayPlay)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: _Badge(
                          text: LocaleKeys.drive_mayNotPlay.tr(),
                          icon: Icons.warning_amber_rounded,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    if (widget.isPlaying)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: _Badge(
                          text: LocaleKeys.drive_nowPlaying.tr(),
                          icon: Icons.play_arrow_rounded,
                          color: ColorsCustom.skyBlue,
                          foreground: ColorsCustom.darkBlue,
                        ),
                      ),
                    AnimatedOpacity(
                      opacity: _hovered ? 1 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        color: Colors.black38,
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: ColorsCustom.skyBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: ColorsCustom.darkBlue,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      const Spacer(),
                      if (meta.isNotEmpty)
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
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

  Widget _buildThumbnail() {
    final url = _thumbnailUrl;
    if (url == null) return const _ThumbnailPlaceholder();
    return Image.network(
      url,
      fit: BoxFit.cover,
      // Drive thumbnails don't send CORS headers; let the browser draw them.
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      errorBuilder: (_, _, _) => const _ThumbnailPlaceholder(),
      frameBuilder: (_, child, frame, wasSynchronouslyLoaded) =>
          wasSynchronouslyLoaded || frame != null
          ? child
          : const _ThumbnailPlaceholder(),
    );
  }

  static String _formatSize(String sizeStr) {
    final size = int.tryParse(sizeStr);
    if (size == null) return '';
    const kb = 1024;
    if (size < kb) return '$size B';
    if (size < kb * kb) return '${(size / kb).toStringAsFixed(1)} KB';
    if (size < kb * kb * kb) {
      return '${(size / (kb * kb)).toStringAsFixed(1)} MB';
    }
    return '${(size / (kb * kb * kb)).toStringAsFixed(1)} GB';
  }

  static String? _formatDuration(String? millis) {
    final value = int.tryParse(millis ?? '');
    if (value == null || value <= 0) return null;
    final duration = Duration(milliseconds: value);
    String two(int n) => n.toString().padLeft(2, '0');
    final minutes = two(duration.inMinutes.remainder(60));
    final seconds = two(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? '${duration.inHours}:$minutes:$seconds'
        : '$minutes:$seconds';
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF2C3036),
      child: Center(
        child: Icon(Icons.movie_outlined, color: Colors.white24, size: 36),
      ),
    );
  }
}

class _TileSkeleton extends StatelessWidget {
  const _TileSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double widthFactor) => FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorsCustom.white10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(color: Colors.white.withValues(alpha: 0.06)),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [bar(0.8), const SizedBox(height: 10), bar(0.45)],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    this.icon,
    this.color = Colors.black87,
    this.foreground = Colors.white,
  });

  final String text;
  final IconData? icon;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 2),
          ],
          Text(
            text,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Centred icon, text and optional action for the empty and error states.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    this.description,
    this.error,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? description;
  final String? error;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: ColorsCustom.skyBlue.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: ColorsCustom.skyBlue, size: 34),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 8),
                Text(
                  description!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
              if (action != null) ...[const SizedBox(height: 24), action!],
              if (error != null) ...[
                const SizedBox(height: 16),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
