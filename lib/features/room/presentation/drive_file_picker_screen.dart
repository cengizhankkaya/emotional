import 'package:emotional/core/services/drive_service.dart';
import 'package:emotional/features/room/presentation/manager/download_manager.dart';
import 'package:emotional/features/room/presentation/manager/helpers/download_file_helper.dart';
import 'package:emotional/features/room/presentation/widgets/drive_file_empty_state.dart';
import 'package:emotional/features/room/presentation/widgets/drive_file_error_view.dart';
import 'package:emotional/features/room/presentation/widgets/drive_file_grid_item.dart';
import 'package:emotional/features/room/presentation/widgets/drive_file_list_item.dart';
import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class DriveFilePickerScreen extends StatefulWidget {
  const DriveFilePickerScreen({super.key});

  @override
  State<DriveFilePickerScreen> createState() => _DriveFilePickerScreenState();
}

class _DriveFilePickerScreenState extends State<DriveFilePickerScreen> {
  List<drive.File> _allFiles = [];
  List<drive.File> _downloadedFiles = [];
  List<drive.File> _galleryFiles = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    try {
      final driveService = context.read<DriveService>();
      final downloadManager = DownloadManager();

      // 1. Refresh global download list (scans all directories)
      await downloadManager.loadDownloadedVideos(driveService);

      // 2. Load Gallery Files
      final galleryFiles = await DownloadFileHelper().listGalleryVideos();
      final galleryDriveFiles = <drive.File>[];

      for (var f in galleryFiles) {
        try {
          final size = f.lengthSync().toString();
          galleryDriveFiles.add(
            drive.File()
              ..id =
                  'local://${f.path}' // Prefix to identify as local
              ..name = f.path.split('/').last
              ..mimeType = 'video/mp4'
              ..size = size,
          );
        } catch (e) {
          debugPrint('Error mapping gallery file ${f.path}: $e');
          // Add without size if it fails, or skip? Better to list it even if size unknown
          galleryDriveFiles.add(
            drive.File()
              ..id = f.path
              ..name = f.path.split('/').last
              ..mimeType = 'video/mp4',
          );
        }
      }

      // 3. Fetch all files from Drive
      final files = await driveService.listVideoFiles();

      if (mounted) {
        setState(() {
          _allFiles = files;
          _downloadedFiles = downloadManager.downloadedVideos;
          _galleryFiles = galleryDriveFiles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e.toString().contains('403') ||
              e.toString().contains('disabled')) {
            _error =
                'Google Drive API etkin değil.\nLütfen Cloud Console\'dan etkinleştirin.';
          } else {
            _error = e.toString();
          }
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteFile(drive.File file) async {
    if (file.name == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ColorsCustom.darkGray,
        title: const Text(
          'Dosyayı Sil',
          style: TextStyle(color: ColorsCustom.white),
        ),
        content: Text(
          '${file.name} dosyasını silmek istediğinize emin misiniz?',
          style: const TextStyle(color: ColorsCustom.darkGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final downloadManager = DownloadManager();

        await downloadManager.deleteDownloadedVideo(file.name!);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Dosya silindi.')));
          _loadFiles(); // Refresh UI
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1D21),
        appBar: AppBar(
          title: const Text(
            'Video Seç',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF1A1D21),
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2229),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: ColorsCustom.skyBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: ColorsCustom.white,
                unselectedLabelColor: ColorsCustom.gray,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: 'İndirilenler'),
                  Tab(text: 'Galeri'),
                  Tab(text: 'Drive'),
                ],
              ),
            ),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.deepPurple),
              )
            : _error != null
            ? DriveFileErrorView(error: _error!)
            : TabBarView(
                children: [
                  _buildDownloadList(_downloadedFiles),
                  _buildGalleryList(_galleryFiles),
                  _buildDriveGrid(_allFiles),
                ],
              ),
      ),
    );
  }

  Widget _buildDownloadList(List<drive.File> files) {
    if (files.isEmpty) {
      return const DriveFileEmptyState(isLocal: true);
    }

    return ListView.builder(
      padding: const ProjectPadding.allMedium(),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return DriveFileListItem(
          file: file,
          isLocal: true,
          onTap: () => Navigator.pop(context, file),
          onDelete: () => _deleteFile(file),
        );
      },
    );
  }

  Widget _buildGalleryList(List<drive.File> files) {
    if (files.isEmpty) {
      return const Center(
        child: Text(
          'Cihazda video bulunamadı.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const ProjectPadding.allMedium(),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return DriveFileListItem(
          file: file,
          isLocal: true,
          onTap: () => Navigator.pop(context, file),
          // Gallery files cannot be deleted from here for safety
          onDelete: null,
        );
      },
    );
  }

  Widget _buildDriveGrid(List<drive.File> files) {
    if (files.isEmpty) {
      return const DriveFileEmptyState(isLocal: false);
    }

    return GridView.builder(
      padding: const ProjectPadding.allMedium(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return DriveFileGridItem(
          file: file,
          onTap: () => Navigator.pop(context, file),
        );
      },
    );
  }
}
