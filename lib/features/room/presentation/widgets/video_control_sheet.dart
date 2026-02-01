import 'dart:io';
import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class VideoControlSheet extends StatelessWidget {
  final bool isHost;
  final String roomId;
  final String? fileName;
  final String? fileId;
  final List<drive.File> downloadedVideos;
  final double? downloadProgress;
  final String? downloadStatus;
  final bool isVideoDownloaded;
  final File? localVideoFile;
  final VoidCallback onPickVideo;
  final void Function(drive.File) onSelectVideo;
  final VoidCallback onDownloadOrPlay;

  const VideoControlSheet({
    super.key,
    required this.isHost,
    required this.roomId,
    required this.fileName,
    required this.fileId,
    required this.downloadedVideos,
    required this.downloadProgress,
    required this.downloadStatus,
    required this.isVideoDownloaded,
    required this.localVideoFile,
    required this.onPickVideo,
    required this.onSelectVideo,
    required this.onDownloadOrPlay,
  });

  @override
  Widget build(BuildContext context) {
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
          if (isHost && downloadedVideos.isNotEmpty) ...[
            _buildDownloadedVideosSection(context),
            SizedBox(height: context.dynamicHeight(0.024)),
            const Divider(color: Colors.white10),
            SizedBox(height: context.dynamicHeight(0.016)),
          ],
          if (fileName != null) ...[
            _buildSelectedVideoSection(context),
            SizedBox(height: context.dynamicHeight(0.016)),
          ],
          _buildActionButtons(context),
          if (fileName == null && !isHost) _buildWaitingMessage(),
        ],
      ),
    );
  }

  Widget _buildDownloadedVideosSection(BuildContext context) {
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

  Widget _buildSelectedVideoSection(BuildContext context) {
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
        if (downloadProgress != null) ...[
          SizedBox(height: context.dynamicHeight(0.016)),
          LinearProgressIndicator(
            value: downloadProgress,
            backgroundColor: Colors.grey[800],
          ),
        ],
        if (downloadStatus != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              downloadStatus!,
              style: TextStyle(
                color: Colors.grey,
                fontSize: context.dynamicValue(12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
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
              onPressed: onDownloadOrPlay,
              icon: Icon(isVideoDownloaded ? Icons.play_arrow : Icons.download),
              label: Text(isVideoDownloaded ? 'Oynat' : 'İndir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isVideoDownloaded
                    ? Colors.green
                    : Colors.blueAccent,
                foregroundColor: Colors.white,
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
