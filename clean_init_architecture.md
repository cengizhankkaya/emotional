# Flutter Clean Init Architecture 🚀

Bu belge, Flutter projelerinde `main.dart` dosyasını karmaşadan kurtarmak ve uygulama başlatma (init) süreçlerini modüler bir yapıda yönetmek için oluşturulmuş standart başlangıç şablonudur.

## 📁 Klasör Yapısı (Öneri)
Projeyi ölçeklenebilir tutmak için `main.dart` dışındaki yapılandırma dosyalarını `lib/product/init/` (veya `lib/core/init/`) klasörü altında topluyoruz.

```text
lib/
├── main.dart
└── product/
    └── init/
        ├── application_init.dart   # Uygulama açılırken çalışacak asenkron servisler
        └── product_scope.dart      # Provider, Bloc ve DI (Dependency Injection) sarmalayıcısı
```

---

## 📄 1. `application_init.dart`
Tüm başlangıç ayarları, veritabanı bağlantıları, yerelleştirme (localization) ve paket başlatmaları burada yapılır.

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@immutable
final class ApplicationInit {
  
  /// Uygulama başlamadan önce çalışması gereken tüm asenkron işlemleri yönetir.
  Future<void> start() async {
    // 1. Flutter Engine'i başlat
    WidgetsFlutterBinding.ensureInitialized();

    // 2. Ekran döndürmeyi sabitle (Opsiyonel)
    await _setPreferredOrientations();

    // 3. Ortak Paketlerin Başlatılması (Örn: Firebase, Hive, Localization vb.)
    // await Firebase.initializeApp();
    // await AppLocalization.ensureInitialized();
    // await LocalStorage.init();
  }

  /// Cihazın sadece dikey (Portrait) modda çalışmasını sağlar
  Future<void> _setPreferredOrientations() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
}
```

---

## 📄 2. `product_scope.dart`
Uygulama genelinde kullanılacak olan State Management (Örn: BLoC, Provider) ve Repository (Veri katmanı) tanımlamaları bu dosya içinde yapılarak ağaç (widget tree) karmaşası önlenir.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProductScope extends StatelessWidget {
  const ProductScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // İhtiyaç duyulan servisleri burada önceden tanımlayabilirsiniz
    // final customService = CustomApiManager();

    return MultiRepositoryProvider(
      providers: [
        // Repository'lerinizi (Veri bağımlılıklarınızı) buraya ekleyin
        // RepositoryProvider<AuthRepository>(create: (context) => AuthRepositoryImpl()),
      ],
      child: MultiBlocProvider(
        providers: [
          // Uygulama genelinde yaşayacak Bloc/Cubit'leri buraya ekleyin
          // BlocProvider<AuthBloc>(create: (context) => AuthBloc(context.read<AuthRepository>())),
        ],
        child: child,
      ),
    );
  }
}
```

---

## 📄 3. `main.dart`
Tüm kurulumlar alt katmanlara devredildiği için `main.dart` dosyası en sade ve okunaklı halinde kalır. Sadece başlatıcıyı çağırır ve UI ağacını çizer.

```dart
import 'package:flutter/material.dart';
import 'product/init/application_init.dart';
import 'product/init/product_scope.dart';

void main() async {
  // 1. Başlatma yöneticisini çağır
  final appInit = ApplicationInit();
  await appInit.start();

  // 2. Uygulamayı ProductScope ile sarmalayarak çalıştır
  runApp(
    const ProductScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clean Init App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('Uygulama başarıyla başlatıldı! 🎉'),
        ),
      ),
    );
  }
}
```
