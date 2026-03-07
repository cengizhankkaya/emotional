<div align="center">
  <img src="assets/logo/logo.png" alt="Emoti Logo" width="150" height="auto" />
  <h1>Emoti</h1>
  <p><strong>Gerçek zamanlı WebRTC iletişimi, senkronize medya oynatma ve Firebase tabanlı güvenli bir arka uç (backend) sunan modern ve yüksek ölçeklenebilir Flutter uygulaması.</strong></p>

  <p>
    <a href="https://flutter.dev/"><img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" alt="Flutter"></a>
    <a href="https://dart.dev/"><img src="https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white" alt="Dart"></a>
    <a href="https://firebase.google.com/"><img src="https://img.shields.io/badge/Firebase-%23FFCA28.svg?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase"></a>
    <a href="https://webrtc.org/"><img src="https://img.shields.io/badge/WebRTC-%23333333.svg?style=for-the-badge&logo=webrtc&logoColor=white" alt="WebRTC"></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge" alt="License"></a>
  </p>
  <p>
    <a href="https://play.google.com/store/apps/details?id=com.esce.emoti">
      <img src="https://upload.wikimedia.org/wikipedia/commons/7/78/Google_Play_Store_badge_EN.svg" alt="Get it on Google Play" height="50">
    </a>
  </p>
  
  <p>
    <a href="README.md">🇬🇧 English</a> | <b>🇹🇷 Türkçe</b>
  </p>
</div>

---

## 📖 Emoti Hakkında

**Emoti**, Flutter ile geliştirilmiş açık kaynaklı bir sosyal medya ve senkronize video izleme platformudur. Kullanıcıların sanal odalar oluşturmasına, arkadaşlarını davet etmesine ve videoyu gerçek zamanlı (WebRTC) görüntülü ve sesli görüşme yaparken tamamen senkronize bir şekilde izlemelerine olanak tanır.

Google Drive'dan bir film izliyor, YouTube'dan içerik akışı yapıyor veya yerel bir dosya oynatıyor olsanız da, Emoti odadaki herkesin ekranını mükemmel bir saniye hassasiyetiyle eşzamanlı tutar.

---

## 📸 Uygulama Görüntüleri (Screenshots)
<div align="center">
  <h3>📱 Uygulama Ekran Görüntüleri</h3>
  <table style="width:100%">
    <tr>
      <td align="center" width="16%">
        <img src="https://github.com/user-attachments/assets/0fb6368f-4224-40cc-91d9-5849787e745d" alt="Ana Ekran" width="160"/>
        <br><sub><b>Giriş</b></sub>
      </td>
      <td align="center" width="16%">
        <img src="https://github.com/user-attachments/assets/8dce462b-9e5c-42d9-a6dc-9a3461795c2b" alt="Oda Düzeni" width="160"/>
        <br><sub><b>Odalar</b></sub>
      </td>
      <td align="center" width="16%">
        <img src="https://github.com/user-attachments/assets/583c8103-9fe4-4651-bd43-60f17515d4d4" alt="Görüntülü Arama" width="160"/>
        <br><sub><b>Video İzleme</b></sub>
      </td>
      <td align="center" width="16%">
        <img src="https://github.com/user-attachments/assets/ce580e21-d633-4aab-af2b-3c91e387c514" alt="Özellikler 1" width="160"/>
        <br><sub><b>Arama</b></sub>
      </td>
      <td align="center" width="16%">
        <img src="https://github.com/user-attachments/assets/8a2cdc42-56d2-4708-ad36-c6ef1626a881" alt="Özellikler 2" width="160"/>
        <br><sub><b>Sohbet</b></sub>
      </td>
      <td align="center" width="16%">
        <img src="https://github.com/user-attachments/assets/d26a6b39-9d0b-479b-8d49-936117b02f3a" alt="Özellikler 3" width="160"/>
        <br><sub><b>Emoti</b></sub>
      </td>
    </tr>
  </table>
</div>
---

## ✨ Özellikler

- 🎥 **Senkronize Video Oynatma:** Arkadaşlarınızla birlikte video izleyin. Oynatma, duraklatma ve ileri/geri sarma (seek) olayları odadaki tüm eşler (peers) arasında anında senkronize edilir.
- 📞 **Gerçek Zamanlı Görüntülü ve Sesli Arama:** WebRTC tarafından desteklenen yerleşik P2P iletişim.
- 📁 **Çoklu Medya Kaynakları:** Yerel dosyalar, doğrudan URL bağları, YouTube akışları ve Google Drive entegrasyonu desteği.
- 💬 **Canlı Sohbet:** Sanal odalar içinde anında metin mesajlaşması.
- 🛋️ **Dinamik Düzenler (Layouts):** Farklı izleme deneyimleri arasından seçim yapın:
  - **Koltuk (Armchair) Modu:** Sanal koltukları temsil eden rahat bir oda ortamı.
  - **Sinema (Cinema) Modu:** Sinematik bir düzenle tamamen videoya odaklanın.
  - **Bölünmüş (Split) Mod:** Video oynatıcısı ile arkadaşlarınızın web kamerası görüntülerini mükemmel bir dengeyle ortadan ikiye bölün.
- 🔗 **Derin Bağlantılar (Deep Linking):** Özel URL'ler kullanarak kullanıcıları doğrudan odalara davet edin (ör. `emoti://join/{roomId}`).
- 🔒 **Yüksek Güvenlik:** Derinlemesine entegre edilmiş ortam (environment) şifrelemesi, API anahtarlarının havuzda (repository) veya derlenmiş (compiled) kodda asla açığa çıkmamasını sağlar.
- 🌍 **Yerelleştirme (Localization):** Kutudan çıktığı haliyle çoklu dil desteği (İngilizce ve Türkçe).

---

## 🛠 Neden Bu Teknolojiler? (Kaputun Altı)

Kod tabanımızı inceleyen geliştiriciler için, yüksek performans, sürdürülebilirlik ve ölçeklenebilirlik sağlamak adına teknoloji yığınımızı (tech stack) özenle kurguladık. Kullanılan paketlerin ve **neden** kullanıldıklarının bir dökümü:

| Teknoloji | Paket | Neden kullanıyoruz? |
| :--- | :--- | :--- |
| **Durum Yönetimi (State Management)** | [`flutter_bloc`](https://pub.dev/packages/flutter_bloc) & `equatable` | Katı, öngörülebilir bir durum konteyneri sağlar. İş mantığını kullanıcı arayüzünden (UI) ayırarak, projenin karmaşıklığı büyüdükçe uygulamanın yüksek oranda test edilebilir ve bakımının kolay olmasını sağlar. |
| **Video Oynatıcı** | [`media_kit`](https://pub.dev/packages/media_kit) | Flutter için en güçlü, platformlar arası (cross-platform) video oynatıcıdır. Çok fazla medya ağırlıklı bir uygulama için kritik olan yerel (native) donanım ivmelendirmesini kullanır ve neredeyse her codec'i destekler. |
| **Gerçek Zamanlı İletişim** | [`flutter_webrtc`](https://pub.dev/packages/flutter_webrtc) | Ağır medya trafiğini merkezi bir sunucu üzerinden yönlendirmeden (sunucu maliyetlerini önemli ölçüde azaltır) düşük gecikmeli, uçtan uca (P2P) eşdüzey ses ve video yayınını sağlar. |
| **Arka Uç (Backend) & Sinyalleşme**| [`firebase_database`](https://pub.dev/packages/firebase_database) | WebRTC sinyalleşme sunucumuz (SDP teklifleri, yanıtları ve ICE adaylarının değişimi), oda durumlarını yönetimi ve düşük gecikmeli canlı sohbet için Firebase Realtime Database'i kullanıyoruz. |
| **Güvenlik** | [`envied`](https://pub.dev/packages/envied) | Açık kaynaklı uygulamalar "key scraping" (anahtar çalınması) saldırılarına karşı savunmasızdır. Envied, `.env` değişkenlerimizi karmaşıklaştırılmış (obfuscated) Dart koduna derleyerek API anahtarlarının anahtar depoda asma sızmamasını veya binary dosyasından tersine mühendislikle (reverse-engineer) kolayca çözülmemesini garanti altına alır. |
| **Arka Plan İşlemleri** | [`background_downloader`](https://pub.dev/packages/background_downloader) | Uygulama arka plana atıldığında bile Google Drive'dan (veya URL'den) büyük boyutlu video dosyalarının kopmadan sağlam bir şekilde indirilmesine olanak tanıyarak kesintiye uğramış indirmeleri önler. |

---

## 🏗 Mimari & Klasör Yapısı

Bu proje, **Temiz Mimari (Clean Architecture)** ile **Özellik Öncelikli (Feature-First)** tasarım desenlerinin hibrit bir versiyonunu kullanır. Bu sayede özellikler birbirlerinden izole (decoupled) kalır; böylece birden çok kişinin aynı anda geliştirme yaparken çakışma (merge conflict) yaratması önlenir.

```text
lib/
├── core/                       # Uygulamadan bağımsız, evrensel servisler & utility'ler
│   ├── bloc/                   # Global durumlar (örn. İnternet bağlantısı durumu yöneticisi)
│   ├── init/                   # Çekirdek başlatmalar (örn. Çoklu dil/Localization kurulumu)
│   ├── manager/                # Global yöneticiler (örn. Yerel CacheManager)
│   └── services/               # Singleton servisler (DriveService, DownloadService, PermissionService, YoutubeService)
│
├── features/                   # Özellik tabanlı (feature-based) modüler yapı
│   ├── app.dart                # Ana uygulama widget sarmalayıcısı (wrapper)
│   ├── auth/                   # Kimlik doğrulama modülü (Google Sign-In mantığı, AuthBloc, Login ekranı)
│   ├── call/                   # P2P Video/Sesli Arama modülü
│   │   ├── bloc/               # CallState durum (state) yönetimi
│   │   ├── domain/             # Arama arayüzü ve enumlar (Arama boyutları, kalite ön ayarları)
│   │   ├── presentation/       # Görüntülü arama widget'ları ve ayar sayfaları
│   │   └── service/            # WebRTCService, SignalingService, MediaDeviceService
│   ├── chat/                   # Oda içi canlı metin mesajlaşma modülü
│   ├── home/                   # Pano (Dashboard) modülü
│   │   └── presentation/       # Ana ekran, derin link (deep link) ile katılma, izin talep iletişim kutuları
│   ├── room/                   # Temel sanal oda modülü (Son derece karmaşık ve kapsamlı)
│   │   ├── bloc/               # Oda yaşam döngüsü & İndirme Cubit'i
│   │   ├── data/               # Firebase Realtime Database repository entegrasyonu
│   │   ├── domain/             # Oda kullanım senaryoları (Katıl, Çık, Oluştur) & Düzen (Layout) Enumları
│   │   └── presentation/       # Temel oda arayüzü, Dinamik Düzenler (Koltuk, Sinema, Bölünmüş), Katılımcılar, Kontroller
│   └── video_player/           # Senkronize video oynatma modülü
│       ├── bloc/               # Oynatıcı durumu (Oynat/Duraklat/Sar senkronizasyonu)
│       └── presentation/       # MediaKit arayüz eklentileri, Resim-içinde-Resim (PiP) mantığı
│
├── product/                    # Uygulamaya özel UI kitleri, temalar, sabitler ve derlenmiş asset'ler
│   ├── generated/              # Otomatik oluşturulan asset referansları (flutter_gen)
│   ├── init/                   # Uygulama başlangıç görevleri (ApplicationInit, Theme, BLoC'lar için ProductScope)
│   ├── model/                  # Global modeller (örn. Remote Config Verileri)
│   ├── utility/                # Sabit değerler (ColorsCustom, boşluklar, fontlar) ve eklentiler (extensions)
│   └── widget/                 # Özel paylaşımlı widget'lar (Diyaloglar, özel butonlar)
│
├── firebase_options.dart       # Otomatik oluşturulmuş Firebase konfigürasyon dosyası
└── main.dart                   # Temiz (Clean) giriş noktası (ApplicationInit ve runApp'i çağırır)
```

### Katman Sorumlulukları:
1.  **Core (`core/`)**: Belirli iş mantıklarından (business logic) tamamen bağımsızdır. Herhangi bir diğer Flutter projesine sürükle-bırak yöntemiyle eklenebilecek genelleştirilmiş çözümler içerir (örneğin; aynı anda birden fazla izin iletişim kutusunun ekranı doldurmasını engelleyen katı "mutex" kilitlerine sahip `PermissionService`).
2.  **Product (`product/`)**: *Bu* uygulamaya özgü ancak global olarak kullanılan mantık ve widget'ları içerir. Tema, uygulamaya özel widget'lar, başlatıcılar (initializers) gibi yapılandırma mantıklarını `product/init/` klasörü içinde tutarak `main.dart` dosyasını kirletmekten kaçınırız.
3.  **Features (`features/`)**: İş mantığı (business logic) tarafından yönlendirilir. Her kapasite/özellik izole edilmiştir. Bir özellik (feature) klasörü içinde Kullanıcı Arayüzü (`presentation/`), Durum Yönetimi (`bloc/`) ve Algoritma (`domain/` ve `data/`) olmak üzere ayrım yapılır.

---

## 🚀 Başvuru Kaynağı (Başlangıç)

Emoti'yi yerel ortamınızda (local) çalıştırmak veya koda katkıda bulunmak mı istiyorsunuz? Projeyi kurmak için şu adımları izleyin.

### 📋 Ön Koşullar
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (^3.10.4)
- Bir [Firebase](https://console.firebase.google.com/) hesabı (Arka uç ve sinyalleşme sunucunuz (signaling server) olarak çalışması için gereklidir).

### 1️⃣ Projeyi İndirin (Clone)
```bash
git clone https://github.com/cengizhankkaya/emotional.git
cd emotional
```

### 2️⃣ Bağımlılıkları (Dependencies) Yükleyin
```bash
flutter pub get
```

### 3️⃣ Çevresel Değişkenleri Ayarlayın (Çok Önemli)
Bu proje açık kaynaklı olduğu için API anahtarları güvenlik gayesiyle projeden (repository) tamamen silinmiştir. Uygulamanın derlenmesi (compile) için kendi `.env` (ortam) dosyalarınızı oluşturmanız gerekir.

1. `assets/` klasörüne gidin ve bir `env` dizini (directory) oluşturun:
   ```bash
   mkdir -p assets/env
   ```
2. `assets/env/` klasörü içinde iki dosya oluşturun: `.env` (geliştirme/dev için) ve `.prod.env` (üretim/production için).
3. Gerekli API değişkenlerinizi her iki dosyaya da ekleyin.
   ```env
   BASEURL=https://sizin-api-url-adresiniz.com
   # lib/product/init/config/app_enviroment.dart dosyasının okuduklarına göre gerekli anahtarları buraya ekleyin
   ```
4. Karartılmış (obfuscated) özel yapılandırma dosyalarını güvenli bir şekilde derleyip oluşturmak için (Generate) build runner komutunu çalıştırın:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
   *Not: Bunu başarılı bir şekilde yaparsanız, `dev_env.g.dart` gibi dosyalar otomatik oluşturulacaktır.*

### 4️⃣ Firebase Kurulumunu Yapın
Auth (Kimlik Doğrulama) ve WebRTC sinyalleşmesinin çalışabilmesi için uygulamayı kendi uyguladığınız Firebase projenize bağlamanız gerekir.
1. [Firebase Konsolu](https://console.firebase.google.com/) üzerinden bir proje oluşturun.
2. Kimlik Doğrulama (Authentication) sekmesinde **Google Sign-In**'i aktif (Enable) hale getirin.
3. Bir **Gerçek Zamanlı Veritabanı (Realtime Database)** oluşturun (Başlamak için Test Modunda başlatın ya da test edilecek uygun kuralları ayarlayın).
4. Aktif projenizi otomatik olarak konfigüre etmek için [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup) kullanın:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

### 5️⃣ Uygulamayı Çalıştırın
```bash
flutter run
```

---

## 🤝 Katkıda Bulunma (Contributing)

Emoti, açık kaynak (open-source) topluluğu tarafından ve bu topluluk için inşa edilmiştir. Flutter, WebRTC veya Clean Architecture öğreniyorsanız eğer yeni yetenekler kazanmak veya test etmek için harika bir adrestir!

1. Projeyi kendinize "Fork"layın
2. Özelliğiniz (Feature) için bir Branch oluşturun (`git checkout -b feature/YeniHarikaOzellik`)
3. Değişikliklerinizi "Commit"leyin (`git commit -m 'YeniHarikaOzellik eklendi'`)
4. Branch inize(dalınıza) "Push"layın (`git push origin feature/YeniHarikaOzellik`)
5. Bir "Pull Request" (PR) açın

**Kodlama Standartları (Coding Standards):** Lütfen dahili klasör yapısına ve isimlendirmelere bağlı kalın. Herhangi bir durum yönetimi (state management) özelliği ekleyecek iseniz BLoC kullanın ve sunumunuzu (presentation/UI katmanı) mantıksız/hesapsız (dumb) tutmaya çalışın. PR taahhüt (commit) etmeden önce daima `flutter format` çalıştırın.

---

## 📜 Lisans

MIT Lisansı altında dağıtılmaktadır. Daha fazla bilgi için [LICENSE](LICENSE) dosyasına bakın.

---

<div align="center">
  <b>Cengizhan KAYA tarafından ❤️ ile tasarlandı/inşa edildi</b><br>
  <i>Flutter Topluluğu İçin Açık Kaynak</i>
</div>
