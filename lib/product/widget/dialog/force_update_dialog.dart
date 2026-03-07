import 'package:flutter/material.dart';

class ForceUpdateDialog extends StatelessWidget {
  const ForceUpdateDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false, // Kullanıcı kapatamasın
      builder: (context) => const ForceUpdateDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Güncelleme Gerekli"),
      content: const Text(
        "Uygulamaya devam edebilmek için lütfen yeni sürümü indirin.",
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            // TODO: Replace with your actual App Store / Play Store link when published
            // launchUrl(Uri.parse('https://play.google.com/store/apps/details?id=com.cengizhankkaya.emoti'));
          },
          child: const Text("Güncelle"),
        ),
      ],
    );
  }
}
