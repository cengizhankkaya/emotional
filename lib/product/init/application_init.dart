import 'dart:async';
import 'package:connectivity_watcher/connectivity_watcher.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:media_kit/media_kit.dart';
import 'package:emotional/features/room/presentation/manager/download_manager.dart';
import 'package:emotional/core/services/download/download_service.dart';

import '../../core/init/core_localize.dart';
import '../../firebase_options.dart';

@immutable
final class ApplicationInit {
  // Localization configuration
  final CoreLocalize localize = CoreLocalize();

  Future<void> start() async {
    // 1. Bind Flutter Engine
    WidgetsFlutterBinding.ensureInitialized();

    // 1.5 Initialize Connectivity Watcher
    ZoConnectivityWatcher().setUp();

    // 2. Initialize Localization
    await EasyLocalization.ensureInitialized();

    // 3. Initialize MediaKit
    MediaKit.ensureInitialized();

    // 4. Initialize Download Service (Professional Background)
    // Note: DownloadManager is kept for backward compatibility for now,
    // but DownloadService handles the core initialization.
    await DownloadService().initialize();
    await DownloadManager().initialize();

    // 5. Initialize Firebase
    await _initializeFirebase();

    // 6. Initialize Remote Config
    await _initializeRemoteConfig();

    // 7. Set Orientation (Optional, keeping it simple or flexible for now, but generally good practice to define)
    await _setRotation();
  }

  Future<void> _initializeFirebase() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (e) {
      if (e.toString().contains('duplicate-app')) {
        // Ignore
      } else {
        debugPrint('Firebase initialization check: $e');
      }
    }
  }

  Future<void> _setRotation() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  Future<void> _initializeRemoteConfig() async {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );
    await remoteConfig.fetchAndActivate();
  }
}
