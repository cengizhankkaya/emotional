import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/features/room/bloc/download_cubit.dart';
import 'package:emotional/features/room/presentation/widgets/video_control_sheet/call_controls_bar.dart';
import 'package:emotional/features/room/presentation/widgets/video_control_sheet/selected_video_card.dart';
import 'package:emotional/features/room/presentation/widgets/video_control_sheet/video_action_buttons.dart';
import 'package:emotional/features/room/presentation/widgets/video_control_sheet/youtube_input_section.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
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
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _checkFile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DownloadCubit>().prefetchDriveFiles();
      }
    });
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
              _DragHandle(
                isExpanded: _isExpanded,
                onTap: () => setState(() => _isExpanded = !_isExpanded),
              ),
              if (_isExpanded) ...[
                SizedBox(height: context.dynamicHeight(0.008)),
                if (widget.fileName != null) ...[
                  SelectedVideoCard(fileName: widget.fileName!, state: state),
                  SizedBox(height: context.dynamicHeight(0.012)),
                ],
                VideoActionButtons(
                  isHost: widget.isHost,
                  fileName: widget.fileName,
                  fileId: widget.fileId,
                  onPickVideo: widget.onPickVideo,
                  onPlay: widget.onPlay,
                ),
                SizedBox(height: context.dynamicHeight(0.012)),
                if (widget.isHost)
                  YoutubeInputSection(onSelectVideo: widget.onSelectVideo),
                SizedBox(height: context.dynamicHeight(0.012)),
                const Divider(color: Colors.white10),
                SizedBox(height: context.dynamicHeight(0.012)),
                const CallControlsBar(),
                if (widget.fileName == null && !widget.isHost)
                  _WaitingMessage(),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DragHandle extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onTap;

  const _DragHandle({required this.isExpanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
              if (!isExpanded) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.settings, color: Colors.white70, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      LocaleKeys.video_showControls.tr(),
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
    );
  }
}

class _WaitingMessage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        LocaleKeys.room_hostSelectingVideo.tr(),
        style: const TextStyle(color: Colors.grey),
      ),
    );
  }
}
