/// App Store ve giriş ekranında kullanılan yasal metin URL'leri.
abstract final class LegalUrls {
  static const privacyPolicy =
      'https://my-portfolio-1ece9.web.app/#/emoti-privacy-policy';

  static const termsOfService =
      'https://my-portfolio-1ece9.web.app/terms.html';

  /// EULA URL — Apple App Store Guideline 1.2 uyumluluğu için.
  /// Terms of Service ile aynı sayfayı kullanır (EULA ibareleri içermelidir).
  static const eula = termsOfService;
}
