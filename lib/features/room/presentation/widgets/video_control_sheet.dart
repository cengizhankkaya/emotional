import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/call/domain/enums/call_quality_preset.dart';
import 'package:emotional/features/room/bloc/download_cubit.dart';
import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
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
  bool _isExpanded = true;

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
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            color: ColorsCustom.darkABlue.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(context.dynamicValue(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: ColorsCustom.white10, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: context.dynamicValue(40),
                          height: context.dynamicValue(4),
                          decoration: BoxDecoration(
                            color: ColorsCustom.white10,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        if (!_isExpanded) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.settings,
                                color: Colors.white70,
                                size: 14,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Kontrolleri Göster',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: context.dynamicValue(12),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (_isExpanded) ...[
                SizedBox(height: context.dynamicHeight(0.008)),
                if (widget.fileName != null) ...[
                  _buildSelectedVideoSection(context, state),
                  SizedBox(height: context.dynamicHeight(0.012)),
                ],
                _buildActionButtons(context, state),
                SizedBox(height: context.dynamicHeight(0.012)),
                const Divider(color: Colors.white10),
                SizedBox(height: context.dynamicHeight(0.012)),
                _buildCallControls(context),
                if (widget.fileName == null && !widget.isHost)
                  _buildWaitingMessage(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCallControls(BuildContext context) {
    return BlocBuilder<CallBloc, CallState>(
      builder: (context, state) {
        if (state is! CallConnected) return const SizedBox.shrink();

        final isMuted = state.isMuted;
        final isVideoEnabled = state.isVideoEnabled;
        final isScreenSharing = state.isScreenSharing;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildQualitySelector(context, state.currentQuality),
            _buildCallControlButton(
              context: context,
              onPressed: () => context.read<CallBloc>().add(ToggleMute()),
              icon: isMuted ? Icons.mic_off : Icons.mic,
              label: isMuted ? 'Sesi Aç' : 'Sustur',
              color: isMuted ? Colors.redAccent : Colors.greenAccent,
            ),
            _buildCallControlButton(
              context: context,
              onPressed: () => context.read<CallBloc>().add(ToggleVideo()),
              icon: isVideoEnabled ? Icons.videocam : Icons.videocam_off,
              label: isVideoEnabled ? 'Kapat' : 'Aç',
              color: isVideoEnabled ? Colors.blueAccent : Colors.grey,
            ),
            _buildCallControlButton(
              context: context,
              onPressed: () =>
                  context.read<CallBloc>().add(ToggleScreenShare()),
              icon: isScreenSharing
                  ? Icons.stop_screen_share
                  : Icons.screen_share,
              label: isScreenSharing ? 'Durdur' : 'Paylaş',
              color: isScreenSharing
                  ? Colors.orangeAccent
                  : ColorsCustom.skyBlue,
            ),
          ],
        );
      },
    );
  }

  Widget _buildQualitySelector(
    BuildContext context,
    CallQualityPreset current,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<CallQualityPreset>(
          initialValue: current,
          icon: const Icon(Icons.high_quality_outlined, color: Colors.white70),
          onSelected: (quality) =>
              context.read<CallBloc>().add(ChangeQuality(quality)),
          itemBuilder: (context) => CallQualityPreset.values
              .map(
                (q) => PopupMenuItem(
                  value: q,
                  child: Row(
                    children: [
                      Icon(
                        q == current
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 16,
                        color: q == current
                            ? ColorsCustom.skyBlue
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(q.displayName, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              )
              .toList(),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.05),
            padding: const EdgeInsets.all(10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Colors.white10),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Kalite',
          style: TextStyle(
            color: Colors.white70,
            fontSize: context.dynamicValue(10),
          ),
        ),
      ],
    );
  }

  Widget _buildCallControlButton({
    required BuildContext context,
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          color: color,
          style: IconButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: color.withValues(alpha: 0.2)),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: context.dynamicValue(10),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedVideoSection(BuildContext context, DownloadState state) {
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
                      'Seçilen Video',
                      style: TextStyle(
                        color: ColorsCustom.gray,
                        fontSize: context.dynamicValue(12),
                      ),
                    ),
                    SizedBox(height: context.dynamicHeight(0.004)),
                    Text(
                      widget.fileName!,
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
                foregroundColor: ColorsCustom.white,
                side: const BorderSide(color: ColorsCustom.white10),
                shape: RoundedRectangleBorder(
                  borderRadius: ProjectRadius.medium(),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
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
                    ? ColorsCustom.cream
                    : isDownloading
                    ? ColorsCustom.skyBlue.withValues(alpha: 0.5)
                    : ColorsCustom.skyBlue,
                foregroundColor: ColorsCustom.white,
                disabledBackgroundColor: ColorsCustom.skyBlue.withValues(
                  alpha: 0.5,
                ),
                disabledForegroundColor: ColorsCustom.white,
                shape: RoundedRectangleBorder(
                  borderRadius: ProjectRadius.medium(),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
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
