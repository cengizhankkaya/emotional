import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
            // Mağaza linkinizi buraya ekleyin
            // launchUrl(Uri.parse('https://play.google.com/store/apps/details?id=YOUR_APP_ID'));
            // Örnek olarak bırakıyorum.
          },
          child: const Text("Güncelle"),
        ),
      ],
    );
  }
}
