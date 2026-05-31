# Sign in with Apple — Firebase ve Apple Developer kurulumu

Uygulama kodu hazır. App Store öncesi aşağıdaki adımları tamamlayın.

## Apple Developer

1. [Certificates, Identifiers & Profiles](https://developer.apple.com/account) → **Identifiers** → `com.esce.emoti`
2. **Sign in with Apple** özelliğini etkinleştirin ve kaydedin.
3. Xcode’da **Runner** target → **Signing & Capabilities** → capability’nin göründüğünü doğrulayın (`Runner.entitlements` repoda mevcut).

## Firebase Console

1. **Authentication** → **Sign-in method** → **Apple** → Enable
2. **Services ID** (web için gerekirse) ve **Apple team ID** / **Key ID** / **Private key** (.p8) alanlarını Apple Developer’dan doldurun.
3. iOS native giriş için genelde bundle ID `com.esce.emoti` yeterlidir; sorun olursa Firebase dokümantasyonundaki [Apple provider](https://firebase.google.com/docs/auth/ios/apple) adımlarını izleyin.

## Test

- **Öncelik: gerçek iPhone.** Simulator’da parola doğru olsa bile sheet kapanmayabilir (Apple / Simulator hatası).
- App Store Connect → **App Review Information** notu: “Login: Sign in with Apple and Google on the first screen. Account deletion: Profile (logo) → Delete account.”

## Simulator’da parola sonrası takılma

Konsolda yalnızca şunu görüp ilerlemiyorsa:

```text
[AppleAuth] Firebase signInWithProvider(Apple)…
```

…ve **“completed” satırı gelmiyorsa**, uygulama kodu değil **Apple sistem UI’si** yanıt vermiyor demektir. Denenecekler:

1. **Gerçek cihazda** test et.
2. Simulator: **Settings → Apple Account** — hesap girişli olsun; Simulator’u yeniden başlat.
3. [appleid.apple.com](https://appleid.apple.com) → **Sign-In and Security** → uygulamalar listesinden Emoti / ilgili girişi kaldır, tekrar dene.
4. Apple Developer’da `com.esce.emoti` için **Sign in with Apple**’ı kapatıp tekrar aç.
5. Firebase Console’da **Apple** provider’ın **Enabled** olduğunu doğrula.
