import 'package:emotional/core/services/web_version/web_version.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../model/enum/firebase_remote_enums.dart';
import 'app_build.dart';

final class VersionValidator {
  VersionValidator._init();

  static Future<AppBuild?>? _running;

  /// This build. On web, what the server handed out when the page loaded:
  /// the page keeps running that code until it reloads.
  static Future<AppBuild?> runningBuild() => _running ??= _loadRunningBuild();

  static Future<AppBuild?> _loadRunningBuild() async {
    if (kIsWeb) return fetchDeployedBuild();
    final info = await PackageInfo.fromPlatform();
    return AppBuild.tryParse(info.version, info.buildNumber);
  }

  /// Remote Config's `version`: the oldest version allowed to run.
  static AppBuild? get minimumBuild =>
      AppBuild.tryParse(FirebaseRemoteEnums.version.valueString);

  /// [refreshConfig]: also fetch Remote Config again, for tabs that stay
  /// open for days (Remote Config's own interval still applies).
  static Future<({UpdateDecision decision, AppBuild? deployed})> check({
    bool refreshConfig = false,
  }) async {
    const none = (decision: UpdateDecision.none, deployed: null);
    try {
      final running = await runningBuild();
      if (running == null) return none;
      if (refreshConfig) await _refreshConfig();
      final deployed = kIsWeb ? await fetchDeployedBuild() : null;
      return (
        decision: decideUpdate(
          running: running,
          minimum: minimumBuild,
          deployed: deployed,
        ),
        deployed: deployed,
      );
    } catch (e) {
      debugPrint('[VersionValidator] Check failed: $e');
      return none;
    }
  }

  /// Offline or slow: decide with the values we already have.
  static Future<void> _refreshConfig() async {
    try {
      await FirebaseRemoteConfig.instance.fetchAndActivate().timeout(
        const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint('[VersionValidator] Remote Config refresh failed: $e');
    }
  }
}
