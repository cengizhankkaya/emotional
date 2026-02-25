import 'package:emotional/core/services/drive_service.dart';
import 'package:emotional/features/room/bloc/download_cubit.dart';
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
  List<drive.File> _allDriveFiles = [];
  String? _nextPageToken;
  bool _isFetchingMoreDrive = false;
  bool _hasMoreDriveFiles = true;

  // In-memory pagination for local files
  List<drive.File> _allLocalDownloads = [];
  List<drive.File> _allLocalGallery = [];

  List<drive.File> _displayedDownloads = [];
  List<drive.File> _displayedGallery = [];

  int _downloadPage = 1;
  int _galleryPage = 1;
  final int _localPageSize = 10;

  bool _isFetchingMoreDownloads = false;
  bool _isFetchingMoreGallery = false;

  bool _isDownloadsLoading = true;
  bool _isGalleryLoading = true;
  bool _isDriveLoading = true;
  String? _error;

  final ScrollController _driveScrollController = ScrollController();
  final ScrollController _downloadsScrollController = ScrollController();
  final ScrollController _galleryScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _driveScrollController.addListener(_onDriveScroll);
    _downloadsScrollController.addListener(_onDownloadsScroll);
    _galleryScrollController.addListener(_onGalleryScroll);
    _loadInitialData();
  }

  @override
  void dispose() {
    _driveScrollController.dispose();
    _downloadsScrollController.dispose();
    _galleryScrollController.dispose();
    super.dispose();
  }

  void _onDriveScroll() {
    if (_driveScrollController.position.pixels >=
            _driveScrollController.position.maxScrollExtent - 200 &&
        !_isFetchingMoreDrive &&
        _hasMoreDriveFiles) {
      _fetchMoreDriveFiles();
    }
  }

  void _onDownloadsScroll() {
    if (_downloadsScrollController.position.pixels >=
            _downloadsScrollController.position.maxScrollExtent - 200 &&
        !_isFetchingMoreDownloads) {
      _loadMoreDownloads();
    }
  }

  void _onGalleryScroll() {
    if (_galleryScrollController.position.pixels >=
            _galleryScrollController.position.maxScrollExtent - 200 &&
        !_isFetchingMoreGallery) {
      _loadMoreGallery();
    }
  }

  void _loadInitialData() {
    final driveService = context.read<DriveService>();
    _loadDriveData(driveService);
    _loadDownloadsData(driveService);
    _loadGalleryData();
  }

  Future<void> _loadDriveData(DriveService driveService) async {
    try {
      final state = context.read<DownloadCubit>().state;
      if (state.prefetchedDriveFiles.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _allDriveFiles = List.from(state.prefetchedDriveFiles);
          _nextPageToken = state.prefetchedNextPageToken;
          _hasMoreDriveFiles = _nextPageToken != null;
          _isDriveLoading = false;
        });
      } else {
        final fileList = await driveService.listVideoFiles(pageSize: 10);
        if (!mounted) return;
        setState(() {
          if (fileList != null) {
            _allDriveFiles = fileList.files ?? [];
            _nextPageToken = fileList.nextPageToken;
            _hasMoreDriveFiles = _nextPageToken != null;
          }
          _isDriveLoading = false;
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
          _isDriveLoading = false;
        });
      }
    }
  }

  Future<void> _loadDownloadsData(DriveService driveService) async {
    try {
      final downloadManager = DownloadManager();
      await downloadManager.loadDownloadedVideos(driveService);
      if (!mounted) return;
      setState(() {
        _allLocalDownloads = downloadManager.downloadedVideos;
        _displayedDownloads = _allLocalDownloads.take(_localPageSize).toList();
        _isDownloadsLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isDownloadsLoading = false);
    }
  }

  Future<void> _loadGalleryData() async {
    try {
      final galleryFiles = await DownloadFileHelper().listGalleryVideos();
      final galleryDriveFiles = <drive.File>[];

      for (var f in galleryFiles) {
        galleryDriveFiles.add(
          drive.File()
            ..id =
                'local://${f.path}' // Prefix to identify as local
            ..name = f.path.split('/').last
            ..mimeType = 'video/mp4',
        );
      }

      if (!mounted) return;
      setState(() {
        _allLocalGallery = galleryDriveFiles;
        _displayedGallery = _allLocalGallery.take(_localPageSize).toList();
        _isGalleryLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isGalleryLoading = false);
    }
  }

  Future<void> _fetchMoreDriveFiles() async {
    if (_isFetchingMoreDrive || !_hasMoreDriveFiles) return;

    setState(() {
      _isFetchingMoreDrive = true;
    });

    try {
      final driveService = context.read<DriveService>();
      final fileList = await driveService.listVideoFiles(
        pageToken: _nextPageToken,
        pageSize: 10,
      );

      if (mounted && fileList != null) {
        setState(() {
          _allDriveFiles.addAll(fileList.files ?? []);
          _nextPageToken = fileList.nextPageToken;
          _hasMoreDriveFiles = _nextPageToken != null;
          _isFetchingMoreDrive = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching more drive files: $e');
      if (mounted) {
        setState(() {
          _isFetchingMoreDrive = false;
        });
      }
    }
  }

  void _loadMoreDownloads() {
    if (_isFetchingMoreDownloads) return;

    final int nextCount = _downloadPage * _localPageSize;
    if (nextCount > _allLocalDownloads.length) return; // No more files

    setState(() {
      _isFetchingMoreDownloads = true;
    });

    // Simulate marginal network delay for smooth UI feedback, optional
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _downloadPage++;
          _displayedDownloads = _allLocalDownloads
              .take(_downloadPage * _localPageSize)
              .toList();
          _isFetchingMoreDownloads = false;
        });
      }
    });
  }

  void _loadMoreGallery() {
    if (_isFetchingMoreGallery) return;

    final int nextCount = _galleryPage * _localPageSize;
    if (nextCount > _allLocalGallery.length) return; // No more files

    setState(() {
      _isFetchingMoreGallery = true;
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _galleryPage++;
          _displayedGallery = _allLocalGallery
              .take(_galleryPage * _localPageSize)
              .toList();
          _isFetchingMoreGallery = false;
        });
      }
    });
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
          _loadInitialData(); // Refresh UI
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
    // If Drive files are prefetched, default to the Drive tab (index 2)

    return DefaultTabController(
      length: 3,
      initialIndex: 2,
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
        body: _error != null
            ? DriveFileErrorView(error: _error!)
            : TabBarView(
                children: [
                  _isDownloadsLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: ColorsCustom.skyBlue,
                          ),
                        )
                      : _buildDownloadList(_displayedDownloads),
                  _isGalleryLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: ColorsCustom.skyBlue,
                          ),
                        )
                      : _buildGalleryList(_displayedGallery),
                  _isDriveLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: ColorsCustom.skyBlue,
                          ),
                        )
                      : _buildDriveGrid(_allDriveFiles),
                ],
              ),
      ),
    );
  }

  Widget _buildDownloadList(List<drive.File> files) {
    if (files.isEmpty) {
      return const DriveFileEmptyState(isLocal: true);
    }

    return Stack(
      children: [
        ListView.builder(
          controller: _downloadsScrollController,
          padding: const ProjectPadding.allMedium().copyWith(bottom: 80),
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
        ),
        if (_isFetchingMoreDownloads)
          const Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: ColorsCustom.skyBlue,
              ),
            ),
          ),
      ],
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

    return Stack(
      children: [
        ListView.builder(
          controller: _galleryScrollController,
          padding: const ProjectPadding.allMedium().copyWith(bottom: 80),
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            return DriveFileListItem(
              file: file,
              isLocal: true,
              onTap: () => Navigator.pop(context, file),
              onDelete: null,
            );
          },
        ),
        if (_isFetchingMoreGallery)
          const Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: ColorsCustom.skyBlue,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDriveGrid(List<drive.File> files) {
    if (files.isEmpty) {
      return const DriveFileEmptyState(isLocal: false);
    }

    return Stack(
      children: [
        GridView.builder(
          controller: _driveScrollController,
          padding: const ProjectPadding.allMedium().copyWith(bottom: 80),
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
        ),
        if (_isFetchingMoreDrive)
          const Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: ColorsCustom.skyBlue,
              ),
            ),
          ),
      ],
    );
  }
}
