import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';

class DriveFileEmptyState extends StatelessWidget {
  final bool isLocal;

  const DriveFileEmptyState({super.key, required this.isLocal});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isLocal ? Icons.download_done_outlined : Icons.folder_off_outlined,
            size: context.dynamicValue(80),
            color: Colors.white24,
          ),
          SizedBox(height: context.dynamicHeight(0.02)),
          Text(
            isLocal
                ? LocaleKeys.drive_noDownloadedVideos.tr()
                : LocaleKeys.drive_noVideosFound.tr(),
            style: TextStyle(
              color: Colors.white54,
              fontSize: context.dynamicValue(18),
            ),
          ),
        ],
      ),
    );
  }
}
