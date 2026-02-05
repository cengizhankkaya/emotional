import 'package:emotional/core/services/drive_service.dart';
import 'package:emotional/features/room/presentation/widgets/drive_file_empty_state.dart';
import 'package:emotional/features/room/presentation/widgets/drive_file_error_view.dart';
import 'package:emotional/features/room/presentation/manager/download_manager.dart';
import 'package:emotional/features/room/presentation/widgets/drive_file_list_item.dart';
import 'package:emotional/product/utility/constants/project_padding.dart';
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

      // 2. Fetch all files from Drive
      final files = await driveService.listVideoFiles();

      if (mounted) {
        setState(() {
          _allFiles = files;
          _downloadedFiles = downloadManager.downloadedVideos;
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
        backgroundColor: const Color(0xFF1E2229),
        title: const Text('Dosyayı Sil', style: TextStyle(color: Colors.white)),
        content: Text(
          '${file.name} dosyasını silmek istediğinize emin misiniz?',
          style: const TextStyle(color: Colors.white70),
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
        final driveService = context.read<DriveService>();

        await downloadManager.deleteDownloadedVideo(file.name!, driveService);

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
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1D21),
        appBar: AppBar(
          title: const Text(
            'Video Seç',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Colors.deepPurpleAccent,
            labelColor: Colors.deepPurpleAccent,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'İndirilenler'),
              Tab(text: 'Drive (Tümü)'),
            ],
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
                  _buildList(_downloadedFiles, isLocal: true),
                  _buildList(_allFiles, isLocal: false),
                ],
              ),
      ),
    );
  }

  Widget _buildList(List<drive.File> files, {required bool isLocal}) {
    if (files.isEmpty) {
      return DriveFileEmptyState(isLocal: isLocal);
    }

    return ListView.builder(
      padding: const ProjectPadding.allMedium(),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return DriveFileListItem(
          file: file,
          isLocal: isLocal,
          onTap: () => Navigator.pop(context, file),
          onDelete: isLocal ? () => _deleteFile(file) : null,
        );
      },
    );
  }
}
