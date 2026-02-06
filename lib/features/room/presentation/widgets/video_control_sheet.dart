import 'package:emotional/features/room/bloc/download_cubit.dart';
import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class VideoControlSheet extends StatelessWidget {
  final bool isHost;
  final String roomId;
  final String? fileName;
  final String? fileId;
  final VoidCallback onPickVideo;
  final void Function(drive.File) onSelectVideo;
  final VoidCallback onPlay;

  const VideoControlSheet({
    super.key,
    required this.isHost,
    required this.roomId,
    required this.fileName,
    required this.fileId,
    required this.onPickVideo,
    required this.onSelectVideo,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadCubit, DownloadState>(
      builder: (context, state) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1E2229),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(context.dynamicValue(30)),
              topRight: Radius.circular(context.dynamicValue(30)),
            ),
          ),
          padding: const ProjectPadding.allLarge(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.error != null)
                _buildErrorListener(
                  context,
                ), // Though better handled by BlocListener in parent
              if (isHost && state.downloadedVideos.isNotEmpty) ...[
                _buildDownloadedVideosSection(context, state.downloadedVideos),
                SizedBox(height: context.dynamicHeight(0.024)),
                const Divider(color: Colors.white10),
                SizedBox(height: context.dynamicHeight(0.016)),
              ],
              if (fileName != null) ...[
                _buildSelectedVideoSection(context, state),
                SizedBox(height: context.dynamicHeight(0.016)),
              ],
              _buildActionButtons(context, state),
              if (fileName == null && !isHost) _buildWaitingMessage(),
            ],
          ),
        );
      },
    );
  }

  // Hacky inline listener widget since we are inside BlocBuilder
  Widget _buildErrorListener(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // This is not ideal inside build, but for now we rely on the Cubit clearing the error
      // or we should use BlocListener in the parent widget.
      // Let's assume RoomScreen handles errors or we just show text.
      // Actually, let's just ignore for now as we don't have a clean way to show snackbar from here without context issues
    });
    return const SizedBox.shrink();
  }

  Widget _buildDownloadedVideosSection(
    BuildContext context,
    List<drive.File> downloadedVideos,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'İndirilenler',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: context.dynamicValue(14),
          ),
        ),
        SizedBox(height: context.dynamicHeight(0.012)),
        SizedBox(
          height: context.dynamicValue(70),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: downloadedVideos.length,
            itemBuilder: (context, index) {
              final video = downloadedVideos[index];
              final isSelected = video.id == fileId;

              return GestureDetector(
                onTap: () => onSelectVideo(video),
                child: Container(
                  width: context.dynamicValue(110),
                  margin: EdgeInsets.only(
                    right: context.dynamicValue(12),
                  ), // Only margin adjusted
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.deepPurple.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: ProjectRadius.medium(),
                    border: isSelected
                        ? Border.all(color: Colors.deepPurpleAccent, width: 2)
                        : Border.all(color: Colors.white10),
                  ),
                  padding: const ProjectPadding.allSmall(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: isSelected
                            ? Colors.deepPurpleAccent
                            : Colors.green,
                        size: context.dynamicValue(18),
                      ),
                      SizedBox(height: context.dynamicHeight(0.002)),
                      Text(
                        video.name ?? 'Bilinmeyen',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.deepPurpleAccent
                              : Colors.white70,
                          fontSize: context.dynamicValue(10),
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedVideoSection(BuildContext context, DownloadState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selected Video:',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: context.dynamicValue(12),
          ),
        ),
        SizedBox(height: context.dynamicHeight(0.004)),
        Text(
          fileName!,
          style: TextStyle(
            color: Colors.white,
            fontSize: context.dynamicValue(16),
            fontWeight: FontWeight.bold,
          ),
        ),
        if (state.downloadProgress != null) ...[
          SizedBox(height: context.dynamicHeight(0.016)),
          LinearProgressIndicator(
            value: state.downloadProgress,
            backgroundColor: Colors.grey[800],
          ),
        ],
        if (state.statusMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              state.statusMessage!,
              style: TextStyle(
                color: Colors.grey,
                fontSize: context.dynamicValue(12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, DownloadState state) {
    final isDownloading = state.downloadProgress != null;

    return Row(
      children: [
        if (isHost)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPickVideo,
              icon: const Icon(Icons.video_library),
              label: const Text('Tümünü Gör'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                shape: RoundedRectangleBorder(
                  borderRadius: ProjectRadius.medium(),
                ),
              ),
            ),
          ),
        if (isHost && fileName != null)
          SizedBox(width: context.dynamicValue(12)),
        if (fileName != null && fileId != null)
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: isDownloading
                  ? null
                  : () {
                      if (state.isVideoDownloaded) {
                        onPlay();
                      } else {
                        context.read<DownloadCubit>().downloadVideo(
                          fileId!,
                          fileName!,
                        );
                      }
                    },
              icon: isDownloading
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
                      state.isVideoDownloaded
                          ? Icons.play_arrow
                          : Icons.download,
                    ),
              label: Text(
                state.isVideoDownloaded
                    ? 'Oynat'
                    : isDownloading
                    ? 'İndiriliyor %${(state.downloadProgress! * 100).toInt()}'
                    : 'İndir',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: state.isVideoDownloaded
                    ? Colors.green
                    : isDownloading
                    ? Colors.blueAccent.withValues(alpha: 0.5)
                    : Colors.blueAccent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.blueAccent.withValues(
                  alpha: 0.5,
                ),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: ProjectRadius.medium(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWaitingMessage() {
    return const Center(
      child: Text(
        'Host video seçimi yapıyor...',
        style: TextStyle(color: Colors.grey),
      ),
    );
  }
}
