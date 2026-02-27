# 📱 Emotional — Proje Genel Bakışı

> **Flutter** ile geliştirilmiş gerçek zamanlı video izleme, WebRTC tabanlı görüntülü arama ve Google Drive entegrasyonunu bir arada sunan sosyal medya / senkronize video izleme uygulaması.

---

## 📋 Proje Bilgileri

| Özellik | Değer |
|---------|-------|
| **Uygulama Adı** | `emotional` |
| **Versiyon** | `1.0.1+12` |
| **Flutter SDK** | `^3.10.4` |
| **Platform** | Android, iOS (birincil), Web, macOS, Linux, Windows |
| **Firebase Projesi** | `emotional-app-b42af` |
| **Dil Desteği** | Türkçe (tr), İngilizce (en) |

---

## 🏗️ Proje Mimarisi

Proje, **Clean Architecture** ve **Feature-First** yapısını birleştiren bir mimariye sahiptir.

```
lib/
├── main.dart               # Uygulama giriş noktası
├── firebase_options.dart   # Firebase platform ayarları (auto-generated)
├── core/                   # Uygulama geneli çekirdek servisler
├── features/               # Feature-based modüler yapı
│   ├── app.dart
│   ├── auth/
│   ├── call/
│   ├── chat/
│   ├── home/
│   ├── room/
│   └── video_player/
└── product/                # UI, tema, yardımcı araçlar
```

### Mimari Katmanlar

```
Presentation (UI / Widgets / Screens)
        ↕
    BLoC (Business Logic)
        ↕
    Domain (UseCases, Entities, Interfaces)
        ↕
    Data (Repositories, Remote/Local Sources)
        ↕
    Core Services (Singleton servisler)
```

---

## 🚀 Başlatma Akışı (`main.dart`)

```
main()
  └── ApplicationInit.start()
        ├── WidgetsFlutterBinding.ensureInitialized()
        ├── ZoConnectivityWatcher().setUp()       ← Ağ izleme
        ├── EasyLocalization.ensureInitialized()  ← Dil desteği
        ├── Firebase.initializeApp()              ← Firebase başlatma
        ├── FirebaseRemoteConfig.fetchAndActivate() ← Remote Config (5sn timeout)
        └── backgroundStart() [unawaited]
              ├── MediaKit.ensureInitialized()    ← Video player
              ├── DownloadService.initialize()    ← İndirme servisi
              ├── DownloadManager.initialize()    ← İndirme yöneticisi
              └── SystemChrome (portrait lock)    ← Ekran yönü kilidi
runApp(
  EasyLocalization(
    child: ProductScope(     ← Tüm BLoC'ları sağlar
      child: MyApp()         ← MaterialApp
    )
  )
)
```

---

## 📁 Klasör Yapısı (Detaylı)

### `lib/core/` — Çekirdek Katman

Uygulama genelinde kullanılan singleton servisler ve temel altyapı.

```
core/
├── bloc/
│   └── network/
│       └── network_bloc.dart          # Ağ bağlantısı BLoC
├── init/
│   └── core_localize.dart             # Dil/yerelleştirme yapılandırması
├── manager/
│   └── cache_manager.dart             # SharedPreferences üzerinden cache yönetimi
└── services/
    ├── download/
    │   ├── download_model.dart        # İndirme görev modeli
    │   └── download_service.dart      # Background download servisi (singleton)
    ├── drive_service.dart             # Google Drive API entegrasyonu
    ├── permission_service.dart        # İzin yönetimi (singleton, mutex kilidi)
    └── youtube_service.dart           # YouTube metadata/stream servisi
```

#### Önemli Servisler

| Servis | Sorumluluk |
|--------|-----------|
| `PermissionService` | Kamera, mikrofon, bildirim, depolama, batarya izinleri. Eşzamanlı istek yarışını önleyen mutex kilidi |
| `DownloadService` | `background_downloader` ile arka plan indirme. Duraklatma/devam/iptal desteği |
| `DriveService` | Google OAuth ile Drive dosyalarını listeleme/indirme |
| `YoutubeService` | `youtube_explode_dart` ile video meta verisi ve stream URL'leri |
| `CacheManager` | Son oda ID'si, batarya reddi gibi basit cache işlemleri |

---

### `lib/features/` — Özellik Modülleri

#### `features/auth/` — Kimlik Doğrulama

```
auth/
├── bloc/
│   ├── auth_bloc.dart     # AuthAuthenticated / AuthUnauthenticated durumları
│   ├── auth_event.dart    # Login, Logout olayları
│   └── auth_state.dart    # Durum sınıfları
└── presentation/
    ├── auth_status_wrapper.dart   # BLoC builder → HomeScreen ↔ LoginScreen
    ├── login_screen.dart          # Google ile giriş ekranı
    └── widgets/
        ├── login_background.dart  # Arka plan görseli
        ├── login_form.dart        # Giriş butonu
        └── logout_dialog.dart     # Çıkış onay diyalogu
```

**Akış:** `AuthStatusWrapper` → `AuthAuthenticated` ise `HomeScreen`, değil ise `LoginScreen`. Çıkış yapıldığında `CallBloc` ve `RoomBloc` da temizlenir.

---

#### `features/home/` — Ana Ekran

```
home/
└── presentation/
    ├── home_screen.dart               # Ana ekran (StatefulWidget)
    ├── helpers/
    │   └── user_helper.dart           # Kullanıcı adı formatlama
    └── widgets/
        ├── home_app_bar.dart          # Özel AppBar (logo, ayarlar, profil)
        ├── create_room_card.dart      # Oda oluşturma kartı
        ├── join_room_card.dart        # Oda katılma kartı (deep link desteği)
        ├── home_download_card.dart    # Google Drive indirme kısayolu
        ├── room_divider.dart          # "veya" ayırıcı
        ├── permission_sheet.dart      # İzin isteme bottom sheet
        ├── profile_dialog.dart        # Profil bilgisi diyalogu
        └── settings_dialog.dart       # Ayarlar diyalogu (izin yönetimi)
```

**Özellikler:**
- **Deep Link** desteği: `emotional://join/{roomId}` ve `https://emotional-app-b42af.web.app/join/{roomId}`
- Son oda ID'si cache'den yüklenir
- Kamera/mikrofon izni yoksa `PermissionSheet` gösterilir
- Oda oluşturulunca/katılınca `RoomScreen`'e push

---

#### `features/room/` — Oda / İzleme Odası

En büyük ve en karmaşık özellik modülü.

```
room/
├── bloc/
│   ├── room_bloc.dart           # Oda yönetimi (oluştur/katıl/ayrıl)
│   ├── room_event.dart          # CreateRoom, JoinRoom, LeaveRoom olayları
│   ├── room_state.dart          # RoomInitial, RoomLoading, RoomJoined, RoomError
│   └── download_cubit.dart      # İndirme durumu yönetimi
├── data/
│   └── repositories/
│       └── room_repository_impl.dart  # Firebase Realtime Database implementasyonu
├── domain/
│   ├── entities/
│   │   └── room_entity.dart           # Oda veri modeli
│   ├── enums/
│   │   └── room_layout_mode.dart      # Koltuk/Cinema/Split düzen modları
│   ├── repositories/
│   │   └── room_repository.dart       # Soyut interface
│   └── usecases/
│       ├── create_room_usecase.dart   # Oda oluşturma iş mantığı
│       ├── join_room_usecase.dart     # Oda katılma iş mantığı
│       └── leave_room_usecase.dart    # Odadan ayrılma iş mantığı
└── presentation/
    ├── room_screen.dart               # Ana oda ekranı
    ├── drive_file_picker_screen.dart  # Google Drive dosya seçici
    ├── manager/
    │   ├── download_manager.dart      # İndirme kuyruğu yönetimi
    │   ├── helpers/
    │   │   └── download_permission_helper.dart  # İzin yardımcısı
    │   └── ...
    ├── mixins/
    │   └── ...                        # Ekran mixin'leri
    └── widgets/
        ├── room_screen_content.dart   # Ana içerik (en büyük widget, 21KB)
        ├── video_control_sheet.dart   # Video kontrol paneli (34KB)
        ├── avatar_participant_widget.dart   # Katılımcı avatarı (15KB)
        ├── screen_share_fullscreen_view.dart # Ekran paylaşımı tam ekran
        ├── screen_share_pip.dart      # Picture-in-Picture ekran paylaşımı
        ├── cinema_layout.dart         # Sinema düzeni
        ├── split_media_layout.dart    # Bölünmüş ekran düzeni
        ├── room_seating_widget.dart   # Koltuk düzeni
        ├── armchair_selector_sheet.dart  # Koltuk seçici
        ├── armchair_widget.dart       # Koltuk görseli
        ├── sofa_widget.dart           # Kanepe görseli
        ├── table_widget.dart          # Masa görseli
        ├── furniture_theme_data.dart  # Mobilya tema varlıkları
        ├── room_top_bar.dart          # Üst çubuk (katılımcılar, kontroller)
        ├── participant_video_row.dart # Katılımcı video sırası
        ├── audio_visualizer.dart      # Ses görselleştirici
        ├── floating_message_bubble.dart  # Yüzen mesaj balonu
        ├── leave_room_dialog.dart     # Oda terk etme onayı
        ├── download_interruption_dialog.dart # İndirme kes uyarısı
        ├── youtube_search_sheet.dart  # YouTube arama
        ├── drive_file_grid_item.dart  # Drive dosya ızgara öğesi
        ├── drive_file_list_item.dart  # Drive dosya liste öğesi
        ├── drive_file_empty_state.dart # Boş durum gösterimi
        └── drive_file_error_view.dart # Hata gösterimi
```

**Düzen Modları:** `RoomLayoutMode` enum'u üç mod tanımlar:
- 🪑 **Armchair** — Koltuk/Mobilya düzeni (varsayılan)
- 🎬 **Cinema** — Sinema modu
- 📺 **Split** — Bölünmüş ekran

---

#### `features/call/` — WebRTC Görüntülü Arama

```
call/
├── bloc/
│   ├── call_bloc.dart      # Arama durumu yönetimi
│   ├── call_event.dart     # StartCall, EndCall, LeaveCall
│   └── call_state.dart     # CallIdle, CallActive, CallError
├── domain/
│   ├── enums/
│   │   ├── call_quality_preset.dart  # Kalite presetleri (Low/Medium/High)
│   │   └── call_video_size.dart      # Video boyut presetleri
│   └── services/
│       ├── i_call_service.dart        # Arama servisi arayüzü
│       └── i_media_device_service.dart # Medya cihaz arayüzü
├── presentation/
│   ├── call_widget.dart              # Video görüşme widget'ı
│   └── call_settings_sheet.dart      # Kamera/mikrofon ayarları
└── service/
    ├── webrtc_service.dart           # WebRTC bağlantı yönetimi
    ├── webrtc_manager.dart           # RTCPeerConnection yönetimi
    ├── signaling_service.dart        # Firebase aracılığıyla sinyalleşme
    ├── media_device_service.dart     # Kamera/mikrofon cihaz servisi
    └── audio_session_service.dart    # Ses oturumu yönetimi
```

**WebRTC Akışı:**
1. `SignalingService` → Firebase Realtime Database üzerinden offer/answer/ICE
2. `WebRTCManager` → RTCPeerConnection yönetimi
3. `WebRTCService` → Üst düzey arama koordinasyonu
4. `AudioSessionService` → `audio_session` ile arka plan ses yönetimi

---

#### `features/chat/` — Gerçek Zamanlı Sohbet

```
chat/
├── bloc/
│   ├── chat_bloc.dart       # Mesaj gönderme/alma yönetimi
│   ├── chat_event.dart      # SendMessage, LoadMessages
│   └── chat_state.dart      # ChatLoaded, ChatError
├── data/
│   └── message_model.dart   # Mesaj veri modeli (JSON serialize)
├── presentation/
│   └── chat_widget.dart     # Sohbet arayüzü
└── repository/
    └── chat_repository.dart # Firebase Realtime Database mesajlaşma
```

---

#### `features/video_player/` — Video Oynatıcı

```
video_player/
├── bloc/
│   ├── video_player_bloc.dart   # Oynatıcı durumu
│   ├── video_player_event.dart  # Play, Pause, Seek, Load
│   └── video_player_state.dart  # Yükleniyor/Oynuyor/Duraklatıldı
├── data/
│   └── ...                      # Video kaynak modelleri
└── presentation/
    └── widgets/
        └── mini_player_overlay.dart  # Küçük oynatıcı overlay (PiP dahil)
        └── ... (toplam 13 widget)
```

**Desteklenen Kaynaklar:** Yerel dosyalar, Google Drive, YouTube (stream URL)

---

### `lib/product/` — Ürün Katmanı (UI Altyapısı)

```
product/
├── generated/
│   └── assets.gen.dart          # flutter_gen ile otomatik oluşturulan asset referansları
├── init/
│   ├── application_init.dart    # Uygulama başlatma orchestrator
│   ├── application_theme.dart   # Material 3 tema tanımı
│   ├── product_scope.dart       # Tüm BLoC Provider'ları sağlayan widget
│   └── version_check_wrapper.dart # Zorunlu güncelleme wrapper'ı
├── model/
│   └── enum/
│       └── firebase_remote_enums.dart  # Remote Config anahtar enum'ları
├── utility/
│   ├── constants/
│   │   ├── app_icons.dart           # İkon sabitleri
│   │   ├── project_padding.dart     # Padding sabitleri
│   │   └── project_radius.dart      # Border radius sabitleri
│   ├── decorations/
│   │   └── colors_custom.dart       # Uygulama renk paleti
│   ├── responsiveness/
│   │   └── responsive_extension.dart # BuildContext extension (dinamik boyutlar)
│   └── validator/
│       └── version_validator.dart   # Versiyon karşılaştırma yardımcısı
└── widget/
    ├── dialog/
    │   └── force_update_dialog.dart  # Zorunlu güncelleme diyalogu
    └── network_status_header.dart    # Çevrimdışı uyarı başlığı
```

---

## 🎨 Tema & Tasarım

### Renk Paleti (`ColorsCustom`)

| Renk Adı | Hex | Kullanım |
|----------|-----|---------|
| `darkBlue` | `#1A1D21` | Ana arka plan, primary |
| `darkABlue` | `#1E2229` | İkincil arka plan |
| `skyBlue` | `#69A2B8` | Vurgu rengi |
| `cream` | `#DEBCA4` | Sıcak vurgu |
| `imperilRead` | `#EF2636` | Hata/tehlike |
| `lightGray` | `#CED4DA` | İkincil metin |
| `white` | `#FFFFFF` | Metin, ikon |
| `black` | `#000000` | Koyu metin |

### Tipografi
- **Font:** `Poppins` (Google Fonts)
- **Tema:** Material 3, light mode base + dark custom scaffold

### Splash Ekranı
- Arka plan: `#1A1D21`
- Logo: `assets/logo/logo.png`
- Android 12 uyumlu

---

## 📦 Bağımlılıklar

### Temel Paketler

| Paket | Versiyon | Amaç |
|-------|----------|------|
| `flutter_bloc` | ^9.1.1 | State management |
| `equatable` | ^2.0.8 | BLoC state karşılaştırma |
| `easy_localization` | ^3.0.8 | Çoklu dil desteği |
| `google_fonts` | ^8.0.0 | Poppins font |

### Firebase

| Paket | Versiyon | Amaç |
|-------|----------|------|
| `firebase_core` | ^3.4.0 | Firebase temel |
| `firebase_auth` | ^5.7.0 | Kimlik doğrulama |
| `firebase_database` | ^11.2.0 | Realtime Database (oda/sinyal) |
| `firebase_remote_config` | ^5.0.2 | Uzak yapılandırma |
| `firebase_analytics` | ^11.3.0 | Analitik |

### Google & Auth

| Paket | Versiyon | Amaç |
|-------|----------|------|
| `google_sign_in` | ^6.1.6 | Google OAuth |
| `googleapis` | ^11.4.0 | Google Drive API |
| `extension_google_sign_in_as_googleapis_auth` | ^2.0.12 | OAuth adaptörü |

### Video & Medya

| Paket | Versiyon | Amaç |
|-------|----------|------|
| `media_kit` | ^1.1.10 | Çapraz platform video oynatıcı |
| `media_kit_video` | ^1.2.4 | Video widget |
| `media_kit_libs_video` | ^1.0.4 | Native codec kütüphaneleri |
| `flutter_webrtc` | ^1.3.0 | WebRTC peer-to-peer görüşme |
| `camera` | ^0.11.3 | Kamera erişimi |
| `youtube_explode_dart` | ^2.2.0 | YouTube stream URL çıkarma |
| `audio_session` | ^0.2.2 | Ses oturumu yönetimi |
| `lottie` | ^3.1.2 | Animasyon desteği |
| `flutter_svg` | ^2.0.9 | SVG desteği |
| `simple_pip_mode` | ^1.1.0 | Picture-in-Picture modu |
| `wakelock_plus` | ^1.3.3 | Ekranı açık tutma |

### İndirme & Dosya

| Paket | Versiyon | Amaç |
|-------|----------|------|
| `background_downloader` | ^7.10.1 | Arka plan dosya indirme |
| `file_picker` | ^10.3.8 | Dosya seçici |
| `path_provider` | ^2.1.1 | Uygulama dizin yolları |
| `share_plus` | ^12.0.1 | Dosya paylaşma |

### İzin & Cihaz

| Paket | Versiyon | Amaç |
|-------|----------|------|
| `permission_handler` | ^12.0.1 | İzin isteme |
| `device_info_plus` | ^12.3.0 | Android/iOS cihaz bilgisi |
| `package_info_plus` | ^8.1.0 | Uygulama versiyonu |

### Yardımcı

| Paket | Versiyon | Amaç |
|-------|----------|------|
| `connectivity_watcher` | ^3.0.6 | Ağ bağlantısı izleme |
| `app_links` | ^7.0.0 | Deep link / Universal link |
| `url_launcher` | ^6.3.1 | URL açma |
| `shared_preferences` | ^2.5.4 | Yerel kalıcı depolama |
| `intl` | ^0.20.2 | Tarih/saat formatlama |
| `font_awesome_flutter` | ^10.5.0 | FontAwesome ikonları |
| `hugeicons` | ^0.0.7 | Hugeicons ikon seti |

### Dev Bağımlılıkları

| Paket | Amaç |
|-------|------|
| `flutter_gen_runner` | Asset code generation |
| `build_runner` | Code generation runner |
| `flutter_launcher_icons` | Uygulama ikonu oluşturma |
| `flutter_native_splash` | Native splash ekranı |
| `flutter_lints` | Lint kuralları |

---

## 🗂️ Assets (Varlıklar)

```
assets/
├── translations/
│   ├── tr.json          # Türkçe çeviriler
│   └── en.json          # İngilizce çeviriler
├── icons/               # PNG ikonlar
├── images/
│   └── armchair/        # Mobilya görselleri
├── svg/                 # SVG dosyaları
├── logo/
│   └── logo.png         # Uygulama logosu (splash + launcher icon)
├── lottie/              # Lottie animasyonları
├── docs/                # Belge dosyaları
├── branding/            # Marka varlıkları
└── app/                 # Uygulama özel görseller
```

---

## 🔥 Firebase Yapısı

### Realtime Database
- **Sinyal / WebRTC:** Offer, Answer, ICE candidate alışverişi
- **Oda yönetimi:** `rooms/{roomId}` → katılımcılar, medya durumu
- **Sohbet:** `rooms/{roomId}/messages`

### Remote Config
- Zorunlu güncelleme sürümü (`minimum_version`)
- Diğer uzak yapılandırma değerleri (`firebase_remote_enums.dart`)

### Authentication
- Google Sign-In (OAuth 2.0)
- Firebase Auth ile oturum yönetimi

---

## 🔗 Deep Link Yapısı

| Şema | Örnek | Açıklama |
|------|-------|---------|
| Custom Scheme | `emotional://join/{roomId}` | Android/iOS deep link |
| Universal Link | `https://emotional-app-b42af.web.app/join/{roomId}` | Web → App yönlendirme |

---

## 📐 Durum Yönetimi (BLoC)

| BLoC | Dosya | Sorumluluk |
|------|-------|-----------|
| `AuthBloc` | `auth/bloc/` | Giriş/çıkış durumu |
| `RoomBloc` | `room/bloc/` | Oda yaşam döngüsü |
| `CallBloc` | `call/bloc/` | WebRTC arama |
| `ChatBloc` | `chat/bloc/` | Mesajlaşma |
| `VideoPlayerBloc` | `video_player/bloc/` | Video oynatıcı |
| `NetworkBloc` | `core/bloc/network/` | Ağ durumu |
| `DownloadCubit` | `room/bloc/` | İndirme durumu |

`ProductScope` widget'ı tüm BLoC'ları `MultiBlocProvider` ile uygulama geneline sağlar.

---

## 🛡️ İzin Yönetimi

`PermissionService` singleton, tüm izinleri merkezi olarak yönetir:

| İzin | Platform | Notlar |
|------|----------|--------|
| Kamera | Android/iOS | WebRTC için zorunlu |
| Mikrofon | Android/iOS | WebRTC için zorunlu |
| Bildirim | Android 13+ | İndirme bildirimleri |
| Depolama | Android < 10 | SDK ≥ 33'te otomatik geçer |
| Video/Fotoğraf | Android 13+ | Galeri erişimi |
| Batarya Optimizasyonu | Android | Arka plan indirme için |

**Özellik:** Mutex kilidi ile eşzamanlı izin isteklerini önler. Batarya optimizasyonunu kullanıcı reddetti ise bir daha sormaz (cache ile gezinim).

---

## 🧩 Kod Üretimi (Code Generation)

```yaml
flutter_gen:
  output: lib/product/generated/
  integrations:
    lottie: true
    flutter_svg: true
```

`assets.gen.dart` → Tüm asset yolları tip güvenli sabitler olarak erişilebilir.

---

## 🌐 Çoklu Dil (Localization)

- **Paket:** `easy_localization`
- **Dosyalar:** `assets/translations/tr.json`, `assets/translations/en.json`
- **Yapılandırma:** `CoreLocalize` → başlangıç locale, desteklenen locale'ler

---

## 📊 Önemli Metrikler

| Metrik | Değer |
|--------|-------|
| Toplam Dart dosyası | ~108 dosya (`lib/` içinde) |
| En büyük widget | `video_control_sheet.dart` (34KB) |
| En karmaşık feature | `room/` (55 dosya) |
| Firebase servisleri | 5 (Core, Auth, Database, RemoteConfig, Analytics) |
| Desteklenen izin türleri | 7 |

---

*Bu dosya Antigravity tarafından otomatik olarak oluşturulmuştur. • `emotional v1.0.1+12` • 2026-02-27*
