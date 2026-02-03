import 'package:shared_preferences/shared_preferences.dart';

final class CacheManager {
  static const String _lastRoomIdKey = 'last_room_id';

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
}
