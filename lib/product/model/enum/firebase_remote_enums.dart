import 'package:firebase_remote_config/firebase_remote_config.dart';

enum FirebaseRemoteEnums {
  version; // Firebase Console'daki anahtar ismi

  String get valueString => FirebaseRemoteConfig.instance.getString(name);
}
