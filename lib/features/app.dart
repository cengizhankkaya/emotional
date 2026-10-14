import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/features/auth/presentation/auth_status_wrapper.dart';
import 'package:emotional/features/video_player/presentation/widgets/drive_stream_token_renewal.dart';
import 'package:emotional/product/init/application_theme.dart';
import 'package:emotional/product/init/version_check_wrapper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class MyApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      // Shown as the browser tab title on web.
      title: kIsWeb ? 'Emoti' : 'Emotional Video Player',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ApplicationTheme.build(context).themeData,
      builder: (context, child) {
        return VersionCheckWrapper(
          navigatorKey: navigatorKey,
          child: DriveStreamTokenRenewal(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const AuthStatusWrapper(),
    );
  }
}
