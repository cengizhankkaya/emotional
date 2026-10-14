import 'dart:convert';

import 'package:emotional/features/call/domain/screen_share/screen_share_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class CacheManager {
  static const String _lastRoomIdKey = 'last_room_id';
  static const String _hasDeniedBatteryOptimizationKey =
      'has_denied_battery_optimization';

  Future<void> saveLastRoomId(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastRoomIdKey, roomId);
  }

  Future<String?> getLastRoomId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastRoomIdKey);
  }

  Future<void> clearLastRoomId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastRoomIdKey);
  }

  Future<void> setHasDeniedBatteryOptimization(bool denied) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasDeniedBatteryOptimizationKey, denied);
  }

  Future<bool> hasDeniedBatteryOptimization() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasDeniedBatteryOptimizationKey) ?? false;
  }

  // ─── EULA ──────────────────────────────────────────────────────────

  static const String _eulaAcceptedKey = 'eula_accepted';

  Future<void> setEulaAccepted(bool accepted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_eulaAcceptedKey, accepted);
  }

  Future<bool> hasAcceptedEula() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_eulaAcceptedKey) ?? false;
  }

  // ─── Screen share ──────────────────────────────────────────────────

  static const String _screenShareOptionsKey = 'screen_share_options';

  Future<void> saveScreenShareOptions(ScreenShareOptions options) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_screenShareOptionsKey, jsonEncode(options.toJson()));
  }

  Future<ScreenShareOptions> getScreenShareOptions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_screenShareOptionsKey);
    if (raw == null) return const ScreenShareOptions();
    try {
      return ScreenShareOptions.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const ScreenShareOptions();
    }
  }
}
