import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LeaveRoomDialog extends StatelessWidget {
  const LeaveRoomDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: context.dynamicWidth(0.8),
        padding: const ProjectPadding.allLarge(),
        decoration: BoxDecoration(
          color: ColorsCustom.darkBlue,
          borderRadius: ProjectRadius.medium(),
          border: Border.all(
            color: ColorsCustom.skyBlue.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const ProjectPadding.allMedium(),
              decoration: BoxDecoration(
                color: ColorsCustom.imperilRead.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.no_meeting_room_rounded,
                color: ColorsCustom.imperilRead,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Odadan Çık',
              style: GoogleFonts.righteous(
                color: Colors.white,
                fontSize: 20,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Odadan ayrılmak istediğinize emin misiniz?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
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
                    style: TextButton.styleFrom(
                      padding: const ProjectPadding.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: ProjectRadius.small(),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    child: const Text(
                      'İptal',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
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
                      elevation: 0,
                      padding: const ProjectPadding.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: ProjectRadius.small(),
                      ),
                    ),
                    child: const Text(
                      'Ayrıl',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => const LeaveRoomDialog(),
    );
  }
}
