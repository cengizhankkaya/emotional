import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyDialog {
  static Future<void> launchPrivacyPolicy() async {
    final Uri url = Uri.parse('https://your-privacy-policy-url.com'); // TODO: Replace with actual URL
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  static Future<void> launchTermsOfService() async {
    final Uri url = Uri.parse('https://your-terms-of-service-url.com'); // TODO: Replace with actual URL
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }
}
