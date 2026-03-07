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
import 'package:flutter/foundation.dart';
import 'package:emotional/product/init/config/app_enviroment.dart';
import 'package:emotional/product/init/config/dev_env.dart';
import 'package:emotional/product/init/config/prod_env.dart';

@immutable
final class ApplicationInit {
  // Localization configuration
  final CoreLocalize localize = CoreLocalize();

  Future<void> start() async {
    // 1. Bind Flutter Engine
    WidgetsFlutterBinding.ensureInitialized();

    // 1.2 Initialize Environment Variables
    if (kDebugMode) {
      AppEnviroment.setup(config: DevEnv());
    } else {
      AppEnviroment.setup(config: ProdEnv());
    }

    // 1.5 Initialize Connectivity Watcher
    ZoConnectivityWatcher().setUp();

    // 2. Initialize Localization
    await EasyLocalization.ensureInitialized();

    // 5. Initialize Firebase
    await _initializeFirebase();

    // 6. Initialize Remote Config with timeout
    await _initializeRemoteConfig();

    // 7. Initialize Background Services (Non-blocking for UI)
    unawaited(backgroundStart());
  }

  /// Initializations that don't need to block the initial UI render
  Future<void> backgroundStart() async {
    // MediaKit initialization
    MediaKit.ensureInitialized();

    // Download services
    await DownloadService().initialize();
    await DownloadManager().initialize();

    // Orientation
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
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10), // Reduced from 1 min
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      // Wait at most 5 seconds for the fetch to complete
      await remoteConfig.fetchAndActivate().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('ApplicationInit: Remote Config fetch timed out');
          return false;
        },
      );
    } catch (e) {
      debugPrint('ApplicationInit: Remote Config error: $e');
    }
  }
}
