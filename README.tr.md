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
    <a href="README.md">🇬🇧 English</a> | <b>🇹🇷 Türkçe</b>
  </p>
</div>

---

## 📖 Emoti Hakkında

**Emoti**, Flutter ile geliştirilmiş açık kaynaklı bir sosyal medya ve senkronize video izleme platformudur. Kullanıcıların sanal odalar oluşturmasına, arkadaşlarını davet etmesine ve videoyu gerçek zamanlı (WebRTC) görüntülü ve sesli görüşme yaparken tamamen senkronize bir şekilde izlemelerine olanak tanır.

Google Drive'dan bir film izliyor, YouTube'dan içerik akışı yapıyor veya yerel bir dosya oynatıyor olsanız da, Emoti odadaki herkesin ekranını mükemmel bir saniye hassasiyetiyle eşzamanlı tutar.

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
├── core/             # Uygulamadan bağımsız, evrensel servisler (İnternet dinleyicisi, Önbellek, İzinler)
├── features/         # Özellik tabanlı (feature-based) modüler yapı
│   ├── app.dart      # Ana uygulama bağlayıcı yapısı
│   ├── auth/         # Kimlik doğrulama akışları (Google Sign-In entegrasyonu)
│   ├── call/         # WebRTC Sinyalleşme, PeerConnection ve Medya Cihazları yönetimi
│   ├── chat/         # Oda içi mesajlaşma mantığı
│   ├── home/         # Pano (Dashboard), Derin Linkler (Deep Links) yöneticisi, izin doğrulamaları
│   ├── room/         # En karmaşık modül: Oda durumu, senkronize oynatma, dinamik düzenler (layouts)
│   └── video_player/ # MediaKit UI entegrasyonu, PiP (Resim-içinde-resim)
├── product/          # Uygulamaya özel UI kitleri, temalar, sabitler ve derlenmiş asset'ler
└── main.dart         # Temiz (Clean) giriş noktası
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
