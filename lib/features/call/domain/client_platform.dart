import 'package:flutter/foundation.dart';

/// Where a participant joined from; shared through the room so everyone
/// can tell a laptop camera (wide) from a phone camera (tall).
enum ClientPlatform {
  web,
  android,
  ios,
  macos,
  windows,
  linux;

  static ClientPlatform get current {
    if (kIsWeb) return ClientPlatform.web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => ClientPlatform.android,
      TargetPlatform.iOS => ClientPlatform.ios,
      TargetPlatform.macOS => ClientPlatform.macos,
      TargetPlatform.windows => ClientPlatform.windows,
      TargetPlatform.linux => ClientPlatform.linux,
      TargetPlatform.fuchsia => ClientPlatform.android,
    };
  }

  /// Null for older app versions, which don't say.
  static ClientPlatform? fromName(String? name) {
    for (final platform in values) {
      if (platform.name == name) return platform;
    }
    return null;
  }

  bool get isPhone => this == android || this == ios;
}
