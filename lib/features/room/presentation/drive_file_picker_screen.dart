import 'dart:io';

import 'package:emotional/core/services/drive_service.dart';
import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';

class DriveFilePickerScreen extends StatefulWidget {
  const DriveFilePickerScreen({super.key});

  @override
  State<DriveFilePickerScreen> createState() => _DriveFilePickerScreenState();
}

class _DriveFilePickerScreenState extends State<DriveFilePickerScreen> {
  List<drive.File> _allFiles = [];
  List<drive.File> _downloadedFiles = [];
  List<drive.File> _otherFiles = [];
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
      final files = await driveService.listVideoFiles();

      // Check for local files
      final appDir = await getApplicationDocumentsDirectory();
      final downloadedFiles = <drive.File>[];
      final otherFiles = <drive.File>[];

      for (var file in files) {
        if (file.name != null) {
          final localFile = File('${appDir.path}/${file.name}');
          if (await localFile.exists()) {
            downloadedFiles.add(file);
          } else {
            otherFiles.add(file);
          }
        } else {
          otherFiles.add(file);
        }
      }

      if (mounted) {
        setState(() {
          _allFiles = files;
          _downloadedFiles = downloadedFiles;
          _otherFiles =
              otherFiles; // Or keep all in "Drive" tab? Let's show All in Drive tab for completeness, or just non-downloaded. Plan said "Drive: All others".
          // Actually, let's keep "Drive" tab as "All Drive Files" (or "Cloud") and "Downloaded" as "Local".
          // But to avoid duplicates visually if user wants to see what is ON DEVICE vs CLOUD ONLY:
          // Let's stick to partitions: Downloaded vs Cloud.
          // However, Cloud usually implies ALL. Let's do Downloaded vs Drive (All).
          // But plan said: "Tab 1: Downloaded, Tab 2: Drive (All/Remaining)".
          // I will use "Drive (Tümü)" for the second tab to avoid confusion.
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
            ? _buildErrorView()
            : TabBarView(
                children: [
                  _buildFileList(_downloadedFiles, isLocal: true),
                  _buildFileList(_allFiles, isLocal: false),
                ],
              ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const ProjectPadding.allLarge(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: context.dynamicValue(64),
              color: Colors.redAccent,
            ),
            SizedBox(height: context.dynamicHeight(0.02)),
            Text(
              'Bir Hata Oluştu',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontSize: context.dynamicValue(24),
              ),
            ),
            SizedBox(height: context.dynamicHeight(0.01)),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: context.dynamicValue(14),
              ),
            ),
            if (_error!.contains('etkinleştirin')) ...[
              SizedBox(height: context.dynamicHeight(0.03)),
              ElevatedButton.icon(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const ProjectPadding.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: ProjectRadius.medium(),
                  ),
                ),
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Konsolu Aç (Tarayıcı)'),
              ),
              SizedBox(height: context.dynamicHeight(0.02)),
              Container(
                padding: const ProjectPadding.allMedium(),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: ProjectRadius.small(),
                ),
                child: const SelectableText(
                  'https://console.developers.google.com/apis/api/drive.googleapis.com/overview?project=739508543260',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blueAccent, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFileList(List<drive.File> files, {required bool isLocal}) {
    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLocal
                  ? Icons.download_done_outlined
                  : Icons.folder_off_outlined,
              size: context.dynamicValue(80),
              color: Colors.white24,
            ),
            SizedBox(height: context.dynamicHeight(0.02)),
            Text(
              isLocal ? 'İndirilmiş video yok.' : 'Video bulunamadı.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: context.dynamicValue(18),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const ProjectPadding.allMedium(),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return Card(
          color: const Color(0xFF1E2229),
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: ProjectRadius.medium(),
            side: const BorderSide(color: Colors.white10),
          ),
          child: InkWell(
            borderRadius: ProjectRadius.medium(),
            onTap: () {
              Navigator.pop(context, file);
            },
            child: Padding(
              padding: const ProjectPadding.allMedium(),
              child: Row(
                children: [
                  Container(
                    width: context.dynamicValue(50),
                    height: context.dynamicValue(50),
                    decoration: BoxDecoration(
                      color: isLocal
                          ? Colors.green.withOpacity(0.1)
                          : Colors.deepPurple.withOpacity(0.1),
                      borderRadius: ProjectRadius.small(),
                    ),
                    child: Icon(
                      isLocal
                          ? Icons.check_circle_outline
                          : Icons.video_library,
                      color: isLocal ? Colors.green : Colors.deepPurpleAccent,
                      size: context.dynamicValue(28),
                    ),
                  ),
                  SizedBox(width: context.dynamicWidth(0.04)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name ?? 'Bilinmeyen Dosya',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: context.dynamicValue(16),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: context.dynamicHeight(0.005)),
                        Row(
                          children: [
                            if (file.size != null) ...[
                              Icon(
                                Icons.data_usage,
                                size: context.dynamicValue(12),
                                color: Colors.grey[400],
                              ),
                              SizedBox(width: context.dynamicWidth(0.01)),
                              Text(
                                _formatSize(file.size!),
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: context.dynamicValue(12),
                                ),
                              ),
                              SizedBox(width: context.dynamicWidth(0.03)),
                            ],
                            Icon(
                              Icons.movie_creation_outlined,
                              size: context.dynamicValue(12),
                              color: Colors.grey[400],
                            ),
                            SizedBox(width: context.dynamicWidth(0.01)),
                            Expanded(
                              child: Text(
                                file.mimeType ?? 'Video',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: context.dynamicValue(12),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white24,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatSize(String sizeStr) {
    final size = int.tryParse(sizeStr);
    if (size == null) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
