import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:flutter/material.dart';

/// Card widget for creating a new room
class CreateRoomCard extends StatelessWidget {
  final VoidCallback onCreateRoom;

  const CreateRoomCard({super.key, required this.onCreateRoom});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E2229),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: ProjectRadius.medium(),
        side: const BorderSide(color: Colors.white10),
      ),
      child: Padding(
        padding: const ProjectPadding.allLarge(),
        child: Column(
          children: [
            Text(
              LocaleKeys.home_createRoom_title.tr(),
              style: TextStyle(
                fontSize: context.dynamicValue(18),
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: context.dynamicHeight(0.02)),
            Text(
              LocaleKeys.home_createRoom_subtitle.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: context.dynamicValue(14),
              ),
            ),
            SizedBox(height: context.dynamicHeight(0.025)),
            SizedBox(
              width: double.infinity,
              height: context.dynamicValue(50),
              child: ElevatedButton(
                onPressed: onCreateRoom,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorsCustom.cream,
                  foregroundColor: ColorsCustom.backgrounddark,
                  shape: RoundedRectangleBorder(
                    borderRadius: ProjectRadius.medium(),
                  ),
                ),
                child: Text(LocaleKeys.home_createRoom_button.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
