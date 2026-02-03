import 'package:package_info_plus/package_info_plus.dart';
import '../../model/enum/firebase_remote_enums.dart';

final class VersionValidator {
  VersionValidator._init();

  static Future<bool> check() async {
    // Mevcut uygulamanın versiyonu (pubspec.yaml'dan)
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    // Remote Config'den gelen minimum versiyon
    final remoteVersion = FirebaseRemoteEnums.version.valueString;

    if (remoteVersion.isEmpty) return false;

    // Versiyonları sayıya çevirip karşılaştırır (Örn: 1.0.1 -> 101)
    // Not: Bu basit karşılaştırma 1.0.10 ile 1.1.0 durumunda hatalı olabilir.
    // Daha sağlam bir karşılaştırma için parçalara bölüp karşılaştırmak daha iyidir.

    return _isNewVersionAvailable(currentVersion, remoteVersion);
  }

  static bool _isNewVersionAvailable(String current, String remote) {
    final currentParts = current.split('.').map(int.parse).toList();
    final remoteParts = remote.split('.').map(int.parse).toList();

    for (var i = 0; i < 3; i++) {
      final remoteVal = i < remoteParts.length ? remoteParts[i] : 0;
      final currentVal = i < currentParts.length ? currentParts[i] : 0;

      if (remoteVal > currentVal) return true;
      if (remoteVal < currentVal) return false;
    }
    return false;
  }
}
