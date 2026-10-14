import 'package:flutter/foundation.dart';

/// A build of the app: `1.2.0` plus its build number (`+22`).
@immutable
final class AppBuild implements Comparable<AppBuild> {
  const AppBuild(this.version, [this.buildNumber = 0]);

  /// `1.2.0` (missing parts count as 0); null if it isn't a version.
  static AppBuild? tryParse(String version, [String? buildNumber]) {
    final parts = version.trim().split('.');
    if (parts.isEmpty || parts.length > 3) return null;
    final numbers = <int>[];
    for (final part in parts) {
      final number = int.tryParse(part);
      if (number == null || number < 0) return null;
      numbers.add(number);
    }
    while (numbers.length < 3) {
      numbers.add(0);
    }
    return AppBuild(numbers, int.tryParse(buildNumber ?? '') ?? 0);
  }

  final List<int> version;
  final int buildNumber;

  /// Compares the version only; Remote Config's minimum has no build number.
  bool isOlderVersionThan(AppBuild other) {
    for (var i = 0; i < 3; i++) {
      if (version[i] != other.version[i]) return version[i] < other.version[i];
    }
    return false;
  }

  @override
  int compareTo(AppBuild other) {
    for (var i = 0; i < 3; i++) {
      final diff = version[i] - other.version[i];
      if (diff != 0) return diff;
    }
    return buildNumber - other.buildNumber;
  }

  @override
  bool operator ==(Object other) => other is AppBuild && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(Object.hashAll(version), buildNumber);

  @override
  String toString() => '${version.join('.')}+$buildNumber';
}

enum UpdateDecision {
  /// Running a version below the required minimum.
  required,

  /// Web only: a different build has been deployed since this page loaded.
  available,

  none,
}

/// [running]: this build. [minimum]: Remote Config's required version.
/// [deployed]: web only, the build the server hands out now.
UpdateDecision decideUpdate({
  required AppBuild running,
  AppBuild? minimum,
  AppBuild? deployed,
}) {
  if (minimum != null && running.isOlderVersionThan(minimum)) {
    // On web, updating means reloading; pointless if the server doesn't
    // have the required version yet either.
    final updateExists =
        deployed == null || !deployed.isOlderVersionThan(minimum);
    if (updateExists) return UpdateDecision.required;
  }
  // Any change counts, a rollback included.
  if (deployed != null && deployed != running) return UpdateDecision.available;
  return UpdateDecision.none;
}
