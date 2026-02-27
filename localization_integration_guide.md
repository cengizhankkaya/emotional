# Flutter Easy Localization — Entegrasyon Kılavuzu

Bu kılavuz, `easy_localization` paketini kullanarak Flutter projenize çoklu dil desteği eklemenizi adım adım anlatır. İçerik, `hatayi_yasat-main` projesindeki gerçek uygulama baz alınarak hazırlanmıştır.

---

## 📋 İçindekiler

1. [Paket Kurulumu](#1-paket-kurulumu)
2. [Proje Klasör Yapısı](#2-proje-klasör-yapısı)
3. [Çeviri Dosyaları (JSON)](#3-çeviri-dosyaları-json)
4. [Yapılandırma Sınıfı `CoreLocalize`](#4-yapılandırma-sınıfı-corelocalize)
5. [Uygulama Başlatma](#5-uygulama-başlatma)
6. [MaterialApp Entegrasyonu](#6-materialapp-entegrasyonu)
7. [Anahtar Kodu Üretimi (Code Generation)](#7-anahtar-kodu-üretimi-code-generation)
8. [Widget İçinde Kullanım](#8-widget-içinde-kullanım)
9. [Dil Değiştirme](#9-dil-değiştirme)
10. [İleri Seviye Kullanım](#10-i̇leri-seviye-kullanım)
11. [Sık Yapılan Hatalar](#11-sık-yapılan-hatalar)

---

## 1. Paket Kurulumu

`pubspec.yaml` dosyasına aşağıdaki bağımlılıkları ekleyin:

```yaml
dependencies:
  flutter:
    sdk: flutter
  easy_localization: ^3.0.1        # Lokalizasyon paketi
  intl: ^0.20.2                    # Tarih/Saat formatlaması için (önerilir)

dev_dependencies:
  build_runner: ^2.3.3             # Code generation için
```

Ardından Terminal'de:

```bash
flutter pub get
```

---

## 2. Proje Klasör Yapısı

```
your_project/
├── assets/
│   └── translations/
│       ├── tr.json          ← Türkçe çeviri dosyası
│       └── en.json          ← İngilizce çeviri dosyası
│
├── lib/
│   ├── core/
│   │   └── init/
│   │       └── core_localize.dart   ← Dil konfigürasyonu
│   │
│   ├── product/
│   │   └── init/
│   │       ├── application_init.dart  ← App başlatma
│   │       └── language/
│   │           └── locale_keys.g.dart ← Üretilen dosya (elle düzenleme!)
│   │
│   ├── features/
│   │   └── app.dart               ← MaterialApp tanımı
│   └── main.dart                  ← Giriş noktası
│
└── pubspec.yaml
```

### `pubspec.yaml`'a Asset Tanımı Ekleme

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/translations/      # ← Bu satır zorunlu!
```

### `pubspec.yaml`'a Script Kısayolu Ekleme (Önerilir)

```yaml
scripts:
  lang: flutter pub run easy_localization:generate -O lib/product/init/language -f keys -o locale_keys.g.dart --source-dir assets/translations
```

> Bu sayede `rps lang` veya `flutter pub run ...` yerine kısa bir komutla anahtarları yenileyebilirsiniz.

---

## 3. Çeviri Dosyaları (JSON)

JSON dosyaları iç içe geçmiş (nested) bir yapıda tutulur. Gruplandırma şeması önerilir:

**`assets/translations/tr.json`**
```json
{
  "project": {
    "name": "Uygulamam"
  },
  "button": {
    "save": "Kaydet",
    "cancel": "İptal",
    "ok": "Tamam",
    "close": "Kapat"
  },
  "validation": {
    "requiredField": "Bu alan boş bırakılamaz",
    "emailFormat": "Lütfen geçerli bir e-posta giriniz"
  },
  "message": {
    "somethingWentWrong": "Bir şeyler yanlış gitti",
    "success": "İşlem başarılı"
  },
  "greeting": {
    "hello_user": "Merhaba {}!"
  }
}
```

**`assets/translations/en.json`**
```json
{
  "project": {
    "name": "My App"
  },
  "button": {
    "save": "Save",
    "cancel": "Cancel",
    "ok": "OK",
    "close": "Close"
  },
  "validation": {
    "requiredField": "This field is required",
    "emailFormat": "Please enter a valid email"
  },
  "message": {
    "somethingWentWrong": "Something went wrong",
    "success": "Operation successful"
  },
  "greeting": {
    "hello_user": "Hello {}!"
  }
}
```

> **⚠️ Önemli:** Her iki JSON dosyasında da aynı anahtarlar bulunmalıdır aksi takdirde eksik anahtar hatası alırsınız.

---

## 4. Yapılandırma Sınıfı `CoreLocalize`

**`lib/core/init/core_localize.dart`**

```dart
import 'package:flutter/material.dart';

/// Desteklenen dilleri enum olarak tanımlar.
/// Her dilin Locale değerini taşır.
enum AppLocale {
  en(Locale('en', 'US')),
  tr(Locale('tr', 'TR'));

  const AppLocale(this.locale);

  final Locale locale;
}

/// Lokalizasyon ayarlarını tek bir yerden yönetir.
/// @immutable: Bu sınıf değiştirilemez (immutable).
@immutable
class CoreLocalize {
  /// JSON dosyalarının bulunduğu yol
  final initialPath = 'assets/translations';

  /// Varsayılan başlangıç dili = Türkçe
  final startLocale = AppLocale.tr.locale;

  /// Desteklenen dillerin listesi (enum'dan otomatik oluşturulur)
  final List<Locale> supportedItems =
      AppLocale.values.map((e) => e.locale).toList();
}
```

---

## 5. Uygulama Başlatma

**`lib/product/init/application_init.dart`**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:your_project/core/init/core_localize.dart';

@immutable
final class ApplicationInit {
  ApplicationInit();

  final CoreLocalize localize = CoreLocalize();

  Future<void> start() async {
    // 1. Flutter binding'i başlat (en önce çağrılmalı)
    WidgetsFlutterBinding.ensureInitialized();
    
    // 2. EasyLocalization'ı başlat
    await EasyLocalization.ensureInitialized();
    
    // Diğer başlatma işlemleri (Firebase, SharedPreferences vb.)
    // await Firebase.initializeApp(...);
    // await SharedPreferences.getInstance();
  }
}
```

**`lib/main.dart`**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:your_project/features/app.dart';
import 'package:your_project/product/init/application_init.dart';

void main() async {
  // ApplicationInit'i başlat
  final initialManager = ApplicationInit();
  await initialManager.start();

  runApp(
    EasyLocalization(
      // Desteklenen diller
      supportedLocales: initialManager.localize.supportedItems,
      // JSON dosyalarının yolu
      path: initialManager.localize.initialPath,
      // Varsayılan başlangıç dili
      startLocale: initialManager.localize.startLocale,
      // Sadece dil kodunu kullan (tr, en — ülke kodu olmadan)
      useOnlyLangCode: true,
      child: const App(),
    ),
  );
}
```

---

## 6. MaterialApp Entegrasyonu

**`lib/features/app.dart`**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // ⬇️ Bu 3 satır zorunludur!
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      home: const HomeScreen(),
    );
  }
}
```

> Router kullananlar için (`go_router`, `auto_route` vb.):
> ```dart
> MaterialApp.router(
>   routerConfig: _router,
>   localizationsDelegates: context.localizationDelegates,
>   supportedLocales: context.supportedLocales,
>   locale: context.locale,
> )
> ```

---

## 7. Anahtar Kodu Üretimi (Code Generation)

JSON anahtarlarını tip güvenli Dart sabitine dönüştürmek için aşağıdaki komutu çalıştırın:

```bash
flutter pub run easy_localization:generate \
  -O lib/product/init/language \
  -f keys \
  -o locale_keys.g.dart \
  --source-dir assets/translations
```

| Parametre | Açıklama |
|---|---|
| `-O` | Çıktı **klasörü** (örn: `lib/product/init/language`) |
| `-f keys` | Çıktı formatı: sadece anahtar isimleri |
| `-o` | Çıktı **dosya adı** (`locale_keys.g.dart`) |
| `--source-dir` | JSON dosyalarının bulunduğu yol |

> **Not:** Bu komutu JSON dosyalarına her yeni anahtar eklediğinizde tekrar çalıştırın.

### Üretilen Dosya Örneği

`lib/product/init/language/locale_keys.g.dart`:

```dart
// DO NOT EDIT. This is code generated via package:easy_localization/generate.dart

// ignore_for_file: constant_identifier_names

abstract class LocaleKeys {
  static const project_name = 'project.name';
  static const project = 'project';
  static const button_save = 'button.save';
  static const button_cancel = 'button.cancel';
  static const button_ok = 'button.ok';
  static const button_close = 'button.close';
  static const validation_requiredField = 'validation.requiredField';
  static const validation_emailFormat = 'validation.emailFormat';
  static const message_somethingWentWrong = 'message.somethingWentWrong';
  static const message_success = 'message.success';
  static const greeting_hello_user = 'greeting.hello_user';
}
```

---

## 8. Widget İçinde Kullanım

Import satırlarını ekleyin:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:your_project/product/init/language/locale_keys.g.dart';
```

### Temel Kullanım

```dart
// ✅ Önerilen: Tip güvenli (LocaleKeys üzerinden)
Text(LocaleKeys.button_save.tr())

// ⚠️ Alternatif: String ile (typo riski var)
Text('button.save'.tr())
```

### Argüman ile Kullanım

JSON:
```json
{
  "greeting": {
    "hello_user": "Merhaba {}!"
  }
}
```

Dart:
```dart
Text(LocaleKeys.greeting_hello_user.tr(args: ['Ahmet']))
// Çıktı: "Merhaba Ahmet!"
```

### Çoğul Form (Plural)

JSON:
```json
{
  "item_count": "{} öğe var | {} öğe var"
}
```

Dart:
```dart
Text(LocaleKeys.item_count.plural(3))
// Çıktı: "3 öğe var"
```

### Tam Örnek Widget

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:your_project/product/init/language/locale_keys.g.dart';

class ExampleScreen extends StatelessWidget {
  const ExampleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.project_name.tr()),
      ),
      body: Column(
        children: [
          // Basit metin
          Text(LocaleKeys.message_somethingWentWrong.tr()),

          // Argümanlı
          Text(LocaleKeys.greeting_hello_user.tr(args: ['Kullanıcı'])),

          // Dil değiştirme butonları
          Row(
            children: [
              ElevatedButton(
                onPressed: () => context.setLocale(const Locale('tr', 'TR')),
                child: const Text('🇹🇷 Türkçe'),
              ),
              ElevatedButton(
                onPressed: () => context.setLocale(const Locale('en', 'US')),
                child: const Text('🇺🇸 English'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

---

## 9. Dil Değiştirme

### Programatik Dil Değiştirme

```dart
// Türkçeye geç
context.setLocale(const Locale('tr', 'TR'));

// İngilizceye geç
context.setLocale(const Locale('en', 'US'));
```

> `easy_localization`, seçilen dili kalıcı olarak `SharedPreferences`'a kaydeder. Uygulama yeniden açıldığında son seçilen dil otomatik olarak geri yüklenir.

### Mevcut Dili Okuma

```dart
// context.locale = seçili dil
final currentLocale = context.locale; // Locale('tr', 'TR')
final langCode = context.locale.languageCode; // 'tr'
```

### AppLocale Enum ile Güvenli Değiştirme

`CoreLocalize`'daki `AppLocale` enum'unu kullanarak daha güvenli dil değiştirme:

```dart
// core/init/core_localize.dart
enum AppLocale {
  en(Locale('en', 'US')),
  tr(Locale('tr', 'TR'));

  const AppLocale(this.locale);
  final Locale locale;
}

// Widget içinde kullanım:
context.setLocale(AppLocale.en.locale);
context.setLocale(AppLocale.tr.locale);
```

---

## 10. İleri Seviye Kullanım

### JSON: Tarih & Sayı Formatlaması

```json
{
  "date": "Tarih: {}",
  "price": "{} TL"
}
```

```dart
Text(LocaleKeys.date.tr(args: [DateFormat('dd.MM.yyyy').format(DateTime.now())]))
```

### Riverpod ile Entegrasyon (State'den dil değiştirme)

```dart
// Riverpod provider'ı ile de kolayca entegre edebilirsiniz.
// BuildContext olmadan dil değiştirmeniz gerekiyorsa,
// EasyLocalization.of(context) yerine GlobalKey kullanımını araştırın.

// Provider içinde değil, UI katmanında (Widget build) context.setLocale() kullanın:
ref.listen(selectedLocaleProvider, (_, locale) {
  context.setLocale(locale);
});
```

---

## 11. Sık Yapılan Hatalar

| Hata | Neden | Çözüm |
|---|---|---|
| `MissingPluginException` | Uygulama yeniden başlatılmadı | `flutter clean && flutter run` çalıştır |
| Çeviri görünmüyor, anahtar görünüyor | Code generation çalıştırılmadı | `rps lang` veya üretim komutunu çalıştır |
| JSON parse hatası | JSON formatı bozuk | JSON dosyasını validator ile kontrol et |
| Desteklenmeyen dil | `AppLocale`'e eklenmemiş | `AppLocale` enum'una ve `supportedLocales`'e ekle |
| `assets/translations/` not found | pubspec.yaml'a eklenmemiş | `flutter: assets:` altına `- assets/translations/` ekle |
| Yeni anahtar çalışmıyor | `locale_keys.g.dart` güncellenmemiş | Üretim komutunu tekrar çalıştır |

---

## ✅ Kontrol Listesi

Projenize entegrasyondan önce aşağıdaki adımları tamamlayın:

- [ ] `pubspec.yaml`'a `easy_localization` ve `intl` bağımlılığı eklendi
- [ ] `assets/translations/` klasörü oluşturuldu ve `pubspec.yaml`'a asset olarak eklendi
- [ ] `tr.json` ve `en.json` dosyaları oluşturuldu
- [ ] `core_localize.dart` dosyası oluşturuldu
- [ ] `application_init.dart`'ta `EasyLocalization.ensureInitialized()` çağrıldı
- [ ] `main.dart`'ta `EasyLocalization` widget'ı ile uygulama sarmalandı
- [ ] `app.dart`'ta `localizationsDelegates`, `supportedLocales` ve `locale` tanımlandı
- [ ] Anahtar üretim komutu çalıştırıldı → `locale_keys.g.dart` oluşturuldu
- [ ] Widget'larda `LocaleKeys.xxx.tr()` ile kullanım test edildi

---

*Kaynak: `hatayi_yasat-main` projesi — `easy_localization ^3.0.1`*
