import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyDialog {
  static Future<void> launchPrivacyPolicy() async {
    final Uri url = Uri.parse(
      'https://my-portfolio-1ece9.web.app/#/emoti-privacy-policy',
    );
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  static Future<void> launchTermsOfService() async {
    final Uri url = Uri.parse(
      'https://my-portfolio-1ece9.web.app/#/emoti-privacy-policy',
    ); // Terms of Service (currently pointing to privacy policy)
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }
}
