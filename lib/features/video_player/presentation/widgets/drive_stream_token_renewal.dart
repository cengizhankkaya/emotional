import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/core/services/drive_stream/drive_stream.dart';
import 'package:emotional/features/auth/services/social_auth_credentials.dart';
import 'package:emotional/features/video_player/bloc/video_player_bloc.dart';
import 'package:emotional/features/video_player/bloc/video_player_state.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Web only: keeps a Drive stream playing past its ~1 hour token.
///
/// Browsers give no refresh token, so renewing means a Google popup, which
/// needs a click. While a Drive video plays, a banner offers renewal shortly
/// before the token expires, and again if `drive_stream_sw.js` runs out.
/// The renewed token goes straight to the worker, so the player at most
/// stalls until the user renews; it doesn't fail.
class DriveStreamTokenRenewal extends StatefulWidget {
  const DriveStreamTokenRenewal({super.key, required this.child});

  final Widget child;

  @override
  State<DriveStreamTokenRenewal> createState() =>
      _DriveStreamTokenRenewalState();
}

enum _Prompt { none, expiringSoon, expired }

class _DriveStreamTokenRenewalState extends State<DriveStreamTokenRenewal> {
  /// How long before expiry the banner shows up.
  static const Duration _warnBefore = Duration(minutes: 5);

  StreamSubscription<void>? _tokenRequests;
  Timer? _warnTimer;
  bool _isStreaming = false;
  _Prompt _prompt = _Prompt.none;
  bool _isRenewing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    _tokenRequests = driveStreamTokenRequests.listen((_) => _onTokenNeeded());
    _onPlayerState(context.read<VideoPlayerBloc>().state);
  }

  @override
  void dispose() {
    _tokenRequests?.cancel();
    _warnTimer?.cancel();
    super.dispose();
  }

  void _onPlayerState(VideoPlayerState state) {
    final isStreaming = state is VideoPlayerActive && state.streamUrl != null;
    if (isStreaming == _isStreaming) return;
    _isStreaming = isStreaming;
    if (isStreaming) {
      _scheduleWarning();
    } else {
      _warnTimer?.cancel();
      _show(_Prompt.none);
    }
  }

  void _scheduleWarning() {
    _warnTimer?.cancel();
    final expiry = SocialAuthCredentials.webDriveTokenExpiry;
    if (expiry == null) return;
    final delay = expiry.subtract(_warnBefore).difference(DateTime.now());
    _warnTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      if (_prompt == _Prompt.none) _show(_Prompt.expiringSoon);
    });
  }

  Future<void> _onTokenNeeded() async {
    if (!_isStreaming) return;
    // The worker may just have restarted and forgotten a still valid token.
    final token = await SocialAuthCredentials.webDriveAccessToken(
      FirebaseAuth.instance,
      silentOnly: true,
    );
    if (!mounted) return;
    if (token != null) {
      publishDriveStreamToken(token, SocialAuthCredentials.webDriveTokenExpiry);
    } else {
      _show(_Prompt.expired);
    }
  }

  /// Runs from the banner button so the Google popup counts as a click.
  Future<void> _renew() async {
    setState(() {
      _isRenewing = true;
      _error = null;
    });
    try {
      final token = await SocialAuthCredentials.webDriveAccessToken(
        FirebaseAuth.instance,
        forceRefresh: true,
      );
      if (!mounted) return;
      if (token != null) {
        _show(_Prompt.none);
        _scheduleWarning();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final closedByUser =
          e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request';
      setState(() {
        _error = closedByUser
            ? null
            : e.code == 'popup-blocked'
            ? LocaleKeys.drive_popupBlocked.tr()
            : e.message ?? e.code;
      });
    } finally {
      if (mounted) setState(() => _isRenewing = false);
    }
  }

  void _show(_Prompt prompt) {
    if (!mounted || _prompt == prompt) return;
    setState(() {
      _prompt = prompt;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return widget.child;
    return BlocListener<VideoPlayerBloc, VideoPlayerState>(
      listener: (_, state) => _onPlayerState(state),
      child: Stack(
        children: [
          widget.child,
          if (_prompt != _Prompt.none)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _buildBanner(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    final expired = _prompt == _Prompt.expired;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Material(
        color: ColorsCustom.darkABlue,
        elevation: 8,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: expired ? Colors.orange : ColorsCustom.white10,
            ),
          ),
          child: Row(
            children: [
              Icon(
                expired ? Icons.cloud_off : Icons.schedule,
                color: expired ? Colors.orange : ColorsCustom.skyBlue,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expired
                          ? LocaleKeys.video_driveRenewExpired.tr()
                          : LocaleKeys.video_driveRenewSoon.tr(),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _isRenewing
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : TextButton(
                      onPressed: _renew,
                      child: Text(
                        LocaleKeys.video_driveRenewAction.tr(),
                        style: const TextStyle(
                          color: ColorsCustom.skyBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
              // No tooltip: this sits above the Navigator, outside any
              // Overlay that a Tooltip needs.
              IconButton(
                onPressed: () => _show(_Prompt.none),
                icon: const Icon(Icons.close, size: 18),
                color: Colors.white54,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
