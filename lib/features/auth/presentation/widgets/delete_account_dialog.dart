import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DeleteAccountDialog extends StatelessWidget {
  const DeleteAccountDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: context.dynamicWidth(0.85),
        padding: const ProjectPadding.allLarge(),
        decoration: BoxDecoration(
          color: ColorsCustom.darkBlue,
          borderRadius: ProjectRadius.medium(),
          border: Border.all(
            color: ColorsCustom.imperilRead.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: ColorsCustom.imperilRead,
              size: 40,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.righteous(
                color: Colors.white,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      LocaleKeys.button_cancel.tr(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorsCustom.imperilRead,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<bool?> showStep1(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => DeleteAccountDialog(
        title: LocaleKeys.auth_deleteAccount_title.tr(),
        message: LocaleKeys.auth_deleteAccount_message.tr(),
        confirmLabel: LocaleKeys.auth_deleteAccount_continue.tr(),
      ),
    );
  }

  static Future<bool?> showStep2(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => DeleteAccountDialog(
        title: LocaleKeys.auth_deleteAccount_title.tr(),
        message: LocaleKeys.auth_deleteAccount_confirmMessage.tr(),
        confirmLabel: LocaleKeys.auth_deleteAccount_confirmButton.tr(),
      ),
    );
  }
}
