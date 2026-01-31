import 'dart:io';
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
      decoration: const BoxDecoration(
        color: Color(0xFF1E2229),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isHost && downloadedVideos.isNotEmpty) ...[
            _buildDownloadedVideosSection(),
            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
          ],
          if (fileName != null) ...[
            _buildSelectedVideoSection(),
            const SizedBox(height: 16),
          ],
          _buildActionButtons(),
          if (fileName == null && !isHost) _buildWaitingMessage(),
        ],
      ),
    );
  }

  Widget _buildDownloadedVideosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'İndirilenler',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 70,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: downloadedVideos.length,
            itemBuilder: (context, index) {
              final video = downloadedVideos[index];
              final isSelected = video.id == fileId;

              return GestureDetector(
                onTap: () => onSelectVideo(video),
                child: Container(
                  width: 110,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.deepPurple.withOpacity(0.2)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: Colors.deepPurpleAccent, width: 2)
                        : Border.all(color: Colors.white10),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: isSelected
                            ? Colors.deepPurpleAccent
                            : Colors.green,
                        size: 18,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        video.name ?? 'Bilinmeyen',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.deepPurpleAccent
                              : Colors.white70,
                          fontSize: 10,
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

  Widget _buildSelectedVideoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selected Video:',
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          fileName!,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (downloadProgress != null) ...[
          const SizedBox(height: 16),
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
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
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
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        if (isHost && fileName != null) const SizedBox(width: 12),
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
                  borderRadius: BorderRadius.circular(12),
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
