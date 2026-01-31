import 'package:flutter/material.dart';

// Desteklenen dilleri burada enum olarak tanımlayın
enum AppLocale {
  en(Locale('en', 'US')),
  tr(Locale('tr', 'TR'));

  const AppLocale(this.locale);
  final Locale locale;
}

@immutable
final class CoreLocalize {
  // Çeviri dosyalarının (json) duracağı klasör yolu
  final String initialPath = 'assets/translations';

  // Uygulama açılışındaki varsayılan dil
  final Locale startLocale = AppLocale.tr.locale;

  // Desteklenen tüm dillerin listesi
  final List<Locale> supportedItems = AppLocale.values
      .map((e) => e.locale)
      .toList();
}
