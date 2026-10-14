import 'package:firebase_remote_config/firebase_remote_config.dart';

enum FirebaseRemoteEnums {
  version, // Firebase Console'daki anahtar ismi

  /// JSON list of RTCIceServer objects (STUN + TURN), e.g.
  /// `[{"urls": ["turn:turn.example.com:3478"], "username": "u", "credential": "p"}]`.
  webrtcIceServers,

  /// App Store page for the force-update button on iOS, e.g.
  /// `https://apps.apple.com/app/id1234567890`.
  iosStoreUrl;

  String get valueString => FirebaseRemoteConfig.instance.getString(name);
}
