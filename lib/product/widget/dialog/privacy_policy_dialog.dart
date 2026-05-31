import 'package:emotional/product/utility/constants/legal_urls.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyDialog {
  static Future<void> launchPrivacyPolicy() async {
    final Uri url = Uri.parse(LegalUrls.privacyPolicy);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  static Future<void> launchTermsOfService() async {
    final Uri url = Uri.parse(LegalUrls.termsOfService);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }
}
