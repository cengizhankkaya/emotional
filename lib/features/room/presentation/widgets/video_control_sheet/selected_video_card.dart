import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/features/room/bloc/download_cubit.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';

class SelectedVideoCard extends StatelessWidget {
  final String fileName;
  final DownloadState state;

  const SelectedVideoCard({
    super.key,
    required this.fileName,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const ProjectPadding.allMedium(),
      decoration: BoxDecoration(
        color: ColorsCustom.darkGray.withValues(alpha: 0.3),
        borderRadius: ProjectRadius.medium(),
        border: Border.all(color: ColorsCustom.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.play_circle_outline_rounded,
                color: ColorsCustom.skyBlue,
                size: context.dynamicValue(24),
              ),
              SizedBox(width: context.dynamicValue(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocaleKeys.video_selectedVideo.tr(),
                      style: TextStyle(
                        color: ColorsCustom.gray,
                        fontSize: context.dynamicValue(12),
                      ),
                    ),
                    SizedBox(height: context.dynamicHeight(0.004)),
                    Text(
                      fileName,
                      style: TextStyle(
                        color: ColorsCustom.white,
                        fontSize: context.dynamicValue(16),
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (state.downloadProgress != null && !state.isVideoDownloaded) ...[
            SizedBox(height: context.dynamicHeight(0.016)),
            LinearProgressIndicator(
              value: state.downloadProgress,
              backgroundColor: ColorsCustom.darkGray,
              color: ColorsCustom.skyBlue,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
          if (state.statusMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                state.statusMessage!,
                style: TextStyle(
                  color: ColorsCustom.gray,
                  fontSize: context.dynamicValue(12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
