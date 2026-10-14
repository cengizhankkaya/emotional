import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/core/services/web_version/web_version.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utility/validator/app_build.dart';
import '../utility/validator/version_validator.dart';
import '../widget/dialog/force_update_dialog.dart';

typedef UpdateCheck =
    Future<({UpdateDecision decision, AppBuild? deployed})> Function({
      bool refreshConfig,
    });

/// Enforces Remote Config's minimum version and, on web, notices new
/// deploys while a tab stays open.
///
/// Sits in MaterialApp.builder, above the Navigator, so dialogs go through
/// [navigatorKey].
class VersionCheckWrapper extends StatefulWidget {
  const VersionCheckWrapper({
    super.key,
    required this.navigatorKey,
    required this.child,
    @visibleForTesting this.check = VersionValidator.check,
    @visibleForTesting this.recheck,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final UpdateCheck check;

  /// Checks again on each event; defaults to the tab becoming visible (web).
  final Stream<void>? recheck;

  @override
  State<VersionCheckWrapper> createState() => _VersionCheckWrapperState();
}

class _VersionCheckWrapperState extends State<VersionCheckWrapper> {
  /// Web tabs often stay open for hours (calls, films).
  static const Duration _webCheckInterval = Duration(minutes: 10);

  Timer? _timer;
  StreamSubscription<void>? _visible;
  bool _isChecking = false;
  bool _requiredShown = false;

  /// A newer web deploy the user hasn't dismissed.
  AppBuild? _available;
  AppBuild? _dismissed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    if (kIsWeb) {
      _timer = Timer.periodic(
        _webCheckInterval,
        (_) => _check(refreshConfig: true),
      );
    }
    _visible = (widget.recheck ?? (kIsWeb ? onAppVisible : null))?.listen(
      (_) => _check(refreshConfig: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _visible?.cancel();
    super.dispose();
  }

  Future<void> _check({bool refreshConfig = false}) async {
    if (_isChecking || _requiredShown) return;
    _isChecking = true;
    try {
      final result = await widget.check(refreshConfig: refreshConfig);
      if (!mounted) return;
      switch (result.decision) {
        case UpdateDecision.required:
          await _showRequired();
        case UpdateDecision.available:
          final deployed = result.deployed;
          if (deployed != _dismissed && deployed != _available) {
            setState(() => _available = deployed);
          }
        case UpdateDecision.none:
          if (_available != null) setState(() => _available = null);
      }
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _showRequired() async {
    // The Navigator may not be built yet on the very first frame.
    final navigatorContext = widget.navigatorKey.currentContext;
    if (navigatorContext == null) return;
    _requiredShown = true;
    if (_available != null) setState(() => _available = null);
    await ForceUpdateDialog.show(navigatorContext);
  }

  @override
  Widget build(BuildContext context) {
    if (_available == null) return widget.child;
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
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
    );
  }

  /// No tooltips here: this sits outside the Navigator's Overlay.
  Widget _buildBanner() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Material(
        color: ColorsCustom.darkABlue,
        elevation: 8,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              const Icon(Icons.system_update_alt, color: ColorsCustom.skyBlue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  LocaleKeys.update_available.tr(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              TextButton(
                onPressed: reloadApp,
                child: Text(
                  LocaleKeys.update_reload.tr(),
                  style: const TextStyle(
                    color: ColorsCustom.skyBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() {
                  _dismissed = _available;
                  _available = null;
                }),
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
