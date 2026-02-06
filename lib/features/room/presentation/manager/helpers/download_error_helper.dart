class DownloadErrorHelper {
  String getErrorMessage(dynamic e) {
    String userMessage = 'İndirme başlatılamadı.';
    final errorString = e.toString();

    if (errorString.contains('User not signed in')) {
      userMessage = 'Oturum açılmamış. Lütfen giriş yapın.';
    } else if (errorString.contains('SocketException') ||
        errorString.contains('Network is unreachable') ||
        errorString.contains('HandshakeException')) {
      userMessage = 'İnternet bağlantısı kurulamadı veya ağ kısıtlı.';
    } else {
      userMessage = 'İndirme hatası: $errorString';
    }
    return userMessage;
  }

  String getStatusErrorMessage(String statusName, String diagnosticInfo) {
    if (statusName == 'Canceled') {
      return 'İndirme durduruldu veya iptal edildi.';
    } else {
      if (diagnosticInfo.contains('403')) {
        return 'Erişim engellendi (403). Oturumunuzu kontrol edin.';
      } else if (diagnosticInfo.contains('404')) {
        return 'Dosya bulunamadı (404).';
      } else {
        return 'İndirme başarısız. Bağlantınızı kontrol edip tekrar deneyin.';
      }
    }
  }
}
