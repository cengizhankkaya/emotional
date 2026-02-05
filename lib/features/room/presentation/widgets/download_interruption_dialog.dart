import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';

class DownloadInterruptionDialog extends StatelessWidget {
  const DownloadInterruptionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ColorsCustom.darkABlue,
      shape: RoundedRectangleBorder(borderRadius: ProjectRadius.large()),
      child: Padding(
        padding: ProjectPadding.allLarge(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.security_rounded,
              color: ColorsCustom.skyBlue,
              size: 48,
            ),
            SizedBox(height: context.dynamicHeight(0.02)),
            Text(
              'İşlem Güvenliği',
              style: TextStyle(
                color: ColorsCustom.white,
                fontSize: context.dynamicValue(20),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: context.dynamicHeight(0.01)),
            Text(
              'Ekranı kapatmamanız indirme işleminin güvenliği ve veri bütünlüğü için önemlidir. Lütfen işlem bitene kadar bekleyiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ColorsCustom.white.withValues(alpha: 0.7),
                fontSize: context.dynamicValue(14),
              ),
            ),
            SizedBox(height: context.dynamicHeight(0.03)),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorsCustom.skyBlue,
                  foregroundColor: ColorsCustom.darkBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: ProjectRadius.medium(),
                  ),
                  padding: ProjectPadding.allMedium(),
                ),
                child: const Text(
                  'Anladım',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
