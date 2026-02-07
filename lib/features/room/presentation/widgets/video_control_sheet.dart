import 'package:emotional/features/room/bloc/download_cubit.dart';
import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class VideoControlSheet extends StatefulWidget {
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
  State<VideoControlSheet> createState() => _VideoControlSheetState();
}

class _VideoControlSheetState extends State<VideoControlSheet> {
  @override
  void initState() {
    super.initState();
    _checkFile();
  }

  @override
  void didUpdateWidget(covariant VideoControlSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fileName != oldWidget.fileName) {
      debugPrint(
        'VideoControlSheet: fileName changed from ${oldWidget.fileName} to ${widget.fileName}',
      );
      _checkFile();
    }
  }

  void _checkFile() {
    if (widget.fileName != null) {
      debugPrint(
        'VideoControlSheet: Checking existence for ${widget.fileName}',
      );
      context.read<DownloadCubit>().checkFileExists(widget.fileName!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DownloadCubit, DownloadState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, state) {
        debugPrint(
          'VideoControlSheet: Rebuild. fileName: ${widget.fileName}, isVideoDownloaded: ${state.isVideoDownloaded}',
        );
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
              if (widget.isHost && state.downloadedVideos.isNotEmpty) ...[
                _buildDownloadedVideosSection(context, state.downloadedVideos),
                SizedBox(height: context.dynamicHeight(0.024)),
                const Divider(color: Colors.white10),
                SizedBox(height: context.dynamicHeight(0.016)),
              ],
              if (widget.fileName != null) ...[
                _buildSelectedVideoSection(context, state),
                SizedBox(height: context.dynamicHeight(0.016)),
              ],
              _buildActionButtons(context, state),
              if (widget.fileName == null && !widget.isHost)
                _buildWaitingMessage(),
            ],
          ),
        );
      },
    );
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
              final isSelected = video.id == widget.fileId;

              return GestureDetector(
                onTap: () => widget.onSelectVideo(video),
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
          'Seçilen Video:',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: context.dynamicValue(12),
          ),
        ),
        SizedBox(height: context.dynamicHeight(0.004)),
        Text(
          widget.fileName!,
          style: TextStyle(
            color: Colors.white,
            fontSize: context.dynamicValue(16),
            fontWeight: FontWeight.bold,
          ),
        ),
        if (state.downloadProgress != null && !state.isVideoDownloaded) ...[
          SizedBox(height: context.dynamicHeight(0.016)),
          LinearProgressIndicator(
            value: state.downloadProgress,
            backgroundColor: Colors.grey[800],
            color: Colors.deepPurpleAccent,
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
    // If video is downloaded, we shouldn't consider it "downloading" even if progress is still clearing (e.g. 100%)
    final isDownloading =
        state.downloadProgress != null && !state.isVideoDownloaded;

    return Row(
      children: [
        if (widget.isHost)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.onPickVideo,
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
        if (widget.isHost && widget.fileName != null)
          SizedBox(width: context.dynamicValue(12)),
        if (widget.fileName != null && widget.fileId != null)
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: isDownloading
                  ? null
                  : () {
                      if (state.isVideoDownloaded) {
                        widget.onPlay();
                      } else {
                        context.read<DownloadCubit>().downloadVideo(
                          widget.fileId!,
                          widget.fileName!,
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
