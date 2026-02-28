import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:flutter/material.dart';

class PermissionSheet extends StatelessWidget {
  final VoidCallback onGrant;

  const PermissionSheet({super.key, required this.onGrant});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const ProjectPadding.allLarge(),
      decoration: BoxDecoration(
        color: ColorsCustom.darkBlue,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(context.dynamicValue(24)),
          topRight: Radius.circular(context.dynamicValue(24)),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              LocaleKeys.home_permissions_title.tr(),
              style: TextStyle(
                fontSize: context.dynamicValue(22),
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.dynamicHeight(0.01)),
            Text(
              LocaleKeys.home_permissions_subtitle.tr(),
              style: TextStyle(
                fontSize: context.dynamicValue(14),
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.dynamicHeight(0.04)),
            _buildPermissionItem(
              context,
              icon: Icons.video_call_rounded,
              title: LocaleKeys.home_permissions_cameraMicTitle.tr(),
              subtitle: LocaleKeys.home_permissions_cameraMicSubtitle.tr(),
            ),
            SizedBox(height: context.dynamicHeight(0.02)),
            _buildPermissionItem(
              context,
              icon: Icons.photo_library_rounded,
              title: LocaleKeys.home_permissions_galleryTitle.tr(),
              subtitle: LocaleKeys.home_permissions_gallerySubtitle.tr(),
            ),
            SizedBox(height: context.dynamicHeight(0.02)),
            _buildPermissionItem(
              context,
              icon: Icons.notifications_active_rounded,
              title: LocaleKeys.home_permissions_notificationsTitle.tr(),
              subtitle: LocaleKeys.home_permissions_notificationsSubtitle.tr(),
            ),
            SizedBox(height: context.dynamicHeight(0.02)),
            _buildPermissionItem(
              context,
              icon: Icons.storage_rounded,
              title: LocaleKeys.home_permissions_storageTitle.tr(),
              subtitle: LocaleKeys.home_permissions_storageSubtitle.tr(),
            ),
            SizedBox(height: context.dynamicHeight(0.03)),
            ElevatedButton(
              onPressed: onGrant,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: ColorsCustom.darkBlue,
                padding: const ProjectPadding.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: ProjectRadius.medium(),
                ),
                elevation: 0,
              ),
              child: Text(
                LocaleKeys.home_permissions_button.tr(),
                style: TextStyle(
                  fontSize: context.dynamicValue(16),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: context.dynamicHeight(0.02)),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const ProjectPadding.allMedium(),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: ProjectRadius.medium(),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: context.dynamicValue(24),
          ),
        ),
        SizedBox(width: context.dynamicWidth(0.04)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: context.dynamicValue(16),
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: context.dynamicHeight(0.005)),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: context.dynamicValue(13),
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
