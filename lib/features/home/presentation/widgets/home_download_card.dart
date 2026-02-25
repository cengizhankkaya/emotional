import 'package:emotional/features/room/bloc/download_cubit.dart';
import 'package:emotional/features/room/presentation/drive_file_picker_screen.dart';
import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:googleapis/drive/v3.dart' as drive;

/// Download / video card for the home screen.
/// Replicates the download section and action buttons from VideoControlSheet
/// so the user can browse and pre-download videos before entering a room.
class HomeDownloadCard extends StatefulWidget {
  const HomeDownloadCard({super.key});

  @override
  State<HomeDownloadCard> createState() => _HomeDownloadCardState();
}

class _HomeDownloadCardState extends State<HomeDownloadCard> {
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DownloadCubit>().prefetchDriveFiles();
      }
    });
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
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
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
                                Icons.download_rounded,
                                color: Colors.white70,
                                size: 14,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'İndirmeleri Göster',
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
                // Downloaded videos list
                if (state.downloadedVideos.isNotEmpty) ...[
                  _buildDownloadedVideosList(context, state),
                  SizedBox(height: context.dynamicHeight(0.012)),
                ],
                // Download progress (if actively downloading)
                if (state.downloadProgress != null &&
                    !state.isVideoDownloaded) ...[
                  _buildDownloadProgress(context, state),
                  SizedBox(height: context.dynamicHeight(0.012)),
                ],
                // Action buttons
                _buildActionButtons(context, state),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDownloadedVideosList(BuildContext context, DownloadState state) {
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
                Icons.video_library_rounded,
                color: ColorsCustom.skyBlue,
                size: context.dynamicValue(20),
              ),
              SizedBox(width: context.dynamicValue(8)),
              Text(
                'İndirilen Videolar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: context.dynamicValue(14),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${state.downloadedVideos.length}',
                style: TextStyle(
                  color: ColorsCustom.skyBlue,
                  fontSize: context.dynamicValue(14),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: context.dynamicHeight(0.008)),
          ...state.downloadedVideos
              .take(3)
              .map(
                (video) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Colors.greenAccent,
                        size: context.dynamicValue(16),
                      ),
                      SizedBox(width: context.dynamicValue(8)),
                      Expanded(
                        child: Text(
                          video.name ?? 'Bilinmeyen Video',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: context.dynamicValue(12),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          if (state.downloadedVideos.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${state.downloadedVideos.length - 3} video daha',
                style: TextStyle(
                  color: ColorsCustom.gray,
                  fontSize: context.dynamicValue(11),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDownloadProgress(BuildContext context, DownloadState state) {
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
                Icons.downloading_rounded,
                color: ColorsCustom.skyBlue,
                size: context.dynamicValue(20),
              ),
              SizedBox(width: context.dynamicValue(8)),
              Expanded(
                child: Text(
                  'İndiriliyor %${(state.downloadProgress! * 100).toInt()}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: context.dynamicValue(14),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.dynamicHeight(0.012)),
          LinearProgressIndicator(
            value: state.downloadProgress,
            backgroundColor: ColorsCustom.darkGray,
            color: ColorsCustom.skyBlue,
            borderRadius: BorderRadius.circular(4),
          ),
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
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _openDriveFilePicker(context),
        icon: const Icon(Icons.video_library),
        label: const Text('Tümünü Gör'),
        style: OutlinedButton.styleFrom(
          foregroundColor: ColorsCustom.white,
          side: const BorderSide(color: ColorsCustom.white10),
          shape: RoundedRectangleBorder(borderRadius: ProjectRadius.medium()),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Future<void> _openDriveFilePicker(BuildContext context) async {
    final downloadCubit = context
        .read<DownloadCubit>(); // Capture before async gap
    final file = await Navigator.push<drive.File>(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: downloadCubit,
          child: const DriveFilePickerScreen(),
        ),
      ),
    );

    if (file != null && mounted) {
      // Download the selected file
      if (file.id != null && file.name != null) {
        downloadCubit.downloadVideo(file.id!, file.name!);
      }

      // Refresh downloaded videos list
      downloadCubit.loadDownloadedVideos();
    }
  }
}
