import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/features/app.dart';
import 'package:emotional/product/init/product_scope.dart';

import 'package:flutter/material.dart';

import 'product/init/application_init.dart';

void main() async {
  final initialManager = ApplicationInit();
  await initialManager.start();

  runApp(
    EasyLocalization(
      supportedLocales: initialManager.localize.supportedItems,
      path: initialManager.localize.initialPath,
      startLocale: initialManager.localize.startLocale,
      useOnlyLangCode: true,
      child: const ProductScope(child: MyApp()),
    ),
  );
}
