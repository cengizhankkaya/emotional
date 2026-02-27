import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/core/services/youtube_service.dart';
import 'package:emotional/features/room/bloc/download_cubit.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class VideoActionButtons extends StatelessWidget {
  final bool isHost;
  final String? fileName;
  final String? fileId;
  final VoidCallback onPickVideo;
  final VoidCallback onPlay;

  const VideoActionButtons({
    super.key,
    required this.isHost,
    required this.fileName,
    required this.fileId,
    required this.onPickVideo,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadCubit, DownloadState>(
      builder: (context, state) {
        final isDownloading =
            state.downloadProgress != null && !state.isVideoDownloaded;

        return Row(
          children: [
            if (isHost)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickVideo,
                  icon: const Icon(Icons.video_library),
                  label: Text(LocaleKeys.button_seeAll.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ColorsCustom.white,
                    side: const BorderSide(color: ColorsCustom.white10),
                    shape: RoundedRectangleBorder(
                      borderRadius: ProjectRadius.medium(),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            if (isHost && fileName != null)
              SizedBox(width: context.dynamicValue(12)),
            if (fileName != null && fileId != null)
              Expanded(
                flex: 2,
                child: _PlayDownloadButton(
                  fileName: fileName!,
                  fileId: fileId!,
                  state: state,
                  isDownloading: isDownloading,
                  onPlay: onPlay,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PlayDownloadButton extends StatelessWidget {
  final String fileName;
  final String fileId;
  final DownloadState state;
  final bool isDownloading;
  final VoidCallback onPlay;

  const _PlayDownloadButton({
    required this.fileName,
    required this.fileId,
    required this.state,
    required this.isDownloading,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final youtubeService = YouTubeService();
    final isLocalFile = fileId.startsWith('local://');
    final isYouTube = youtubeService.isValidYouTubeUrl(fileId);
    final isMissingLocalFile = isLocalFile && !state.isVideoDownloaded;
    final isReadyToPlay = state.isVideoDownloaded || isYouTube;

    return ElevatedButton.icon(
      onPressed: (isDownloading || isMissingLocalFile) && !isYouTube
          ? null
          : () {
              if (isReadyToPlay) {
                if (isYouTube || state.localVideoFile != null) {
                  onPlay();
                } else {
                  debugPrint(
                    'VideoActionButtons: isVideoDownloaded=true but localVideoFile=null, rechecking...',
                  );
                  context.read<DownloadCubit>().checkFileExists(fileName);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(LocaleKeys.video_fileChecking.tr()),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } else {
                context.read<DownloadCubit>().downloadVideo(fileId, fileName);
              }
            },
      icon: isDownloading && !isYouTube
          ? SizedBox(
              width: context.dynamicValue(16),
              height: context.dynamicValue(16),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withValues(alpha: 0.7),
                ),
              ),
            )
          : Icon(
              isReadyToPlay
                  ? Icons.play_arrow
                  : isMissingLocalFile
                  ? Icons.error_outline
                  : Icons.download,
            ),
      label: Text(
        isReadyToPlay
            ? LocaleKeys.button_play.tr()
            : isDownloading
            ? LocaleKeys.video_downloading.tr(
                args: ['${(state.downloadProgress! * 100).toInt()}'],
              )
            : isMissingLocalFile
            ? LocaleKeys.video_localFileMissing.tr()
            : LocaleKeys.button_download.tr(),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isReadyToPlay
            ? ColorsCustom.cream
            : isDownloading || isMissingLocalFile
            ? ColorsCustom.skyBlue.withValues(alpha: 0.5)
            : ColorsCustom.skyBlue,
        foregroundColor: ColorsCustom.white,
        disabledBackgroundColor: ColorsCustom.skyBlue.withValues(alpha: 0.5),
        disabledForegroundColor: ColorsCustom.white,
        shape: RoundedRectangleBorder(borderRadius: ProjectRadius.medium()),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}
