import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';

class DownloadErrorHelper {
  String getErrorMessage(dynamic e) {
    String userMessage = LocaleKeys.download_errors_failedToStart.tr();
    final errorString = e.toString();

    if (errorString.contains('User not signed in')) {
      userMessage = LocaleKeys.download_errors_notLoggedIn.tr();
    } else if (errorString.contains('SocketException') ||
        errorString.contains('Network is unreachable') ||
        errorString.contains('HandshakeException')) {
      userMessage = LocaleKeys.download_errors_noInternet.tr();
    } else {
      userMessage = LocaleKeys.download_errors_downloadError.tr(
        args: [errorString],
      );
    }
    return userMessage;
  }

  String getStatusErrorMessage(String statusName, String diagnosticInfo) {
    if (statusName == 'Canceled') {
      return LocaleKeys.download_status_stopped.tr();
    } else {
      if (diagnosticInfo.contains('403')) {
        return LocaleKeys.download_errors_accessDenied.tr();
      } else if (diagnosticInfo.contains('404')) {
        return LocaleKeys.download_errors_fileNotFound.tr();
      } else {
        return LocaleKeys.download_errors_failedTryAgain.tr();
      }
    }
  }
}
