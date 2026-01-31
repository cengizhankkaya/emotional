import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/features/auth/presentation/auth_status_wrapper.dart';
import 'package:emotional/product/init/application_theme.dart';
import 'package:flutter/material.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emotional Video Player',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ApplicationTheme.build(context).themeData,
      home: const AuthStatusWrapper(),
    );
  }
}
