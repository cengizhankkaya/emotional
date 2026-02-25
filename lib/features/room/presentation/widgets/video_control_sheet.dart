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
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:emotional/core/services/youtube_service.dart';
import 'package:emotional/features/room/presentation/widgets/youtube_search_sheet.dart';
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
  final _youtubeUrlController = TextEditingController();
  final _youtubeService = YouTubeService();
  bool _isYoutubeValid = false;

  @override
  void dispose() {
    _youtubeUrlController.dispose();
    _youtubeService.dispose();
    super.dispose();
  }

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
                if (widget.isHost) _buildYouTubeInput(context),
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
            _buildCallControlButton(
              context: context,
              onPressed: () => _showSettingsModal(context, state),
              icon: Icons.settings_outlined,
              label: 'Ayarlar',
              color: Colors.white70,
            ),
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

  void _showSettingsModal(BuildContext context, CallConnected state) {
    final callBloc = context.read<CallBloc>();
    showModalBottomSheet(
      context: context,
      backgroundColor: ColorsCustom.darkABlue,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) => BlocProvider.value(
        value: callBloc,
        child: BlocBuilder<CallBloc, CallState>(
          builder: (context, state) {
            if (state is! CallConnected) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Görüşme Ayarları',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: modalContext.dynamicValue(18),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10),
                  _buildSettingsListTile(
                    context: modalContext,
                    icon: Icons.high_quality_outlined,
                    title: 'Yayın Kalitesi',
                    subtitle: state.currentQuality.displayName,
                    onTap: () => _showQualityMenu(modalContext, state),
                  ),
                  _buildSettingsListTile(
                    context: modalContext,
                    icon: Icons.videocam_outlined,
                    title: 'Kamera',
                    subtitle:
                        state.videoInputs
                            .where(
                              (d) => d.deviceId == state.selectedVideoInputId,
                            )
                            .firstOrNull
                            ?.label ??
                        'Varsayılan',
                    onTap: () => _showDeviceMenu(
                      modalContext,
                      'Kamera Seçimi',
                      state.videoInputs,
                      state.selectedVideoInputId,
                      (d) => callBloc.add(ChangeVideoInput(d)),
                    ),
                  ),
                  _buildSettingsListTile(
                    context: modalContext,
                    icon: Icons.mic_none_outlined,
                    title: 'Mikrofon',
                    subtitle:
                        state.audioInputs
                            .where(
                              (d) => d.deviceId == state.selectedAudioInputId,
                            )
                            .firstOrNull
                            ?.label ??
                        'Varsayılan',
                    onTap: () => _showDeviceMenu(
                      modalContext,
                      'Mikrofon Seçimi',
                      state.audioInputs,
                      state.selectedAudioInputId,
                      (d) => callBloc.add(ChangeAudioInput(d)),
                    ),
                  ),
                  _buildSettingsListTile(
                    context: modalContext,
                    icon: Icons.speaker_outlined,
                    title: 'Hoparlör',
                    subtitle:
                        state.audioOutputs
                            .where(
                              (d) => d.deviceId == state.selectedAudioOutputId,
                            )
                            .firstOrNull
                            ?.label ??
                        'Varsayılan',
                    onTap: () => _showDeviceMenu(
                      modalContext,
                      'Hoparlör Seçimi',
                      state.audioOutputs,
                      state.selectedAudioOutputId,
                      (d) => callBloc.add(ChangeAudioOutput(d)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSettingsListTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: ColorsCustom.skyBlue),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.white30),
      onTap: onTap,
    );
  }

  void _showQualityMenu(BuildContext context, CallConnected initialState) {
    final callBloc = context.read<CallBloc>();
    showModalBottomSheet(
      context: context,
      backgroundColor: ColorsCustom.darkABlue,
      builder: (modalContext) => BlocProvider.value(
        value: callBloc,
        child: BlocBuilder<CallBloc, CallState>(
          builder: (context, state) {
            if (state is! CallConnected) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                          _showSettingsModal(context, state);
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'Yayın Kalitesi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: CallQualityPreset.values
                          .map(
                            (q) => ListTile(
                              leading: Icon(
                                q == state.currentQuality
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: q == state.currentQuality
                                    ? ColorsCustom.cream
                                    : Colors.white30,
                              ),
                              title: Text(
                                q.displayName,
                                style: TextStyle(
                                  color: q == state.currentQuality
                                      ? ColorsCustom.cream
                                      : Colors.white,
                                  fontWeight: q == state.currentQuality
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              onTap: () {
                                debugPrint(
                                  '[VideoControlSheet] Quality selected: $q',
                                );
                                callBloc.add(ChangeQuality(q));
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showDeviceMenu(
    BuildContext context,
    String title,
    List<MediaDeviceInfo> initialDevices,
    String? initialId,
    Function(MediaDeviceInfo) onSelected,
  ) {
    final callBloc = context.read<CallBloc>();
    showModalBottomSheet(
      context: context,
      backgroundColor: ColorsCustom.darkABlue,
      isScrollControlled: true,
      builder: (modalContext) => BlocProvider.value(
        value: callBloc,
        child: BlocBuilder<CallBloc, CallState>(
          builder: (context, state) {
            if (state is! CallConnected) return const SizedBox.shrink();

            final List<MediaDeviceInfo> devices;
            final String? currentId;
            if (title.contains('Kamera')) {
              devices = state.videoInputs;
              currentId = state.selectedVideoInputId;
            } else if (title.contains('Mikrofon')) {
              devices = state.audioInputs;
              currentId = state.selectedAudioInputId;
            } else if (title.contains('Hoparlör')) {
              devices = state.audioOutputs;
              currentId = state.selectedAudioOutputId;
            } else {
              devices = initialDevices;
              currentId = initialId;
            }

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(modalContext).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                          _showSettingsModal(context, state);
                        },
                      ),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (devices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Cihaz bulunamadı',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: devices
                          .map(
                            (d) => ListTile(
                              leading: Icon(
                                d.deviceId == currentId
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: d.deviceId == currentId
                                    ? ColorsCustom.cream
                                    : Colors.white30,
                              ),
                              title: Text(
                                d.label.isEmpty ? 'Bilinmeyen Cihaz' : d.label,
                                style: TextStyle(
                                  color: d.deviceId == currentId
                                      ? ColorsCustom.cream
                                      : Colors.white,
                                  fontWeight: d.deviceId == currentId
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                              onTap: () {
                                debugPrint(
                                  '[VideoControlSheet] Device selected: ${d.label} (${d.deviceId})',
                                );
                                onSelected(d);
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
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
            child: Builder(
              builder: (context) {
                final isLocalFile = widget.fileId!.startsWith('local://');
                final isYouTube = _youtubeService.isValidYouTubeUrl(
                  widget.fileId!,
                );
                final isMissingLocalFile =
                    isLocalFile && !state.isVideoDownloaded;

                final isReadyToPlay = state.isVideoDownloaded || isYouTube;

                return ElevatedButton.icon(
                  onPressed: (isDownloading || isMissingLocalFile) && !isYouTube
                      ? null
                      : () {
                          if (isReadyToPlay) {
                            if (isYouTube || state.localVideoFile != null) {
                              widget.onPlay();
                            } else {
                              // State is inconsistent, trigger a fresh check
                              debugPrint(
                                'VideoControlSheet: isVideoDownloaded=true but localVideoFile=null, rechecking...',
                              );
                              context.read<DownloadCubit>().checkFileExists(
                                widget.fileName!,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Video dosyası kontrol ediliyor...',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          } else {
                            // Only try to download if it's NOT a local-only file
                            context.read<DownloadCubit>().downloadVideo(
                              widget.fileId!,
                              widget.fileName!,
                            );
                          }
                        },
                  icon: isDownloading && !isYouTube
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
                          isReadyToPlay
                              ? Icons.play_arrow
                              : isMissingLocalFile
                              ? Icons.error_outline
                              : Icons.download,
                        ),
                  label: Text(
                    isReadyToPlay
                        ? 'Oynat'
                        : isDownloading
                        ? 'İndiriliyor %${(state.downloadProgress! * 100).toInt()}'
                        : isMissingLocalFile
                        ? 'Yerel Dosya (Eksik)'
                        : 'İndir',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isReadyToPlay
                        ? ColorsCustom.cream
                        : isDownloading || isMissingLocalFile
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
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildYouTubeInput(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'YouTube Video',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              onPressed: () => _showYouTubeSearch(context),
              icon: const Icon(
                Icons.search,
                size: 20,
                color: ColorsCustom.skyBlue,
              ),
              tooltip: 'YouTube\'da Ara',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _youtubeUrlController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'https://youtube.com/watch?v=...',
                  hintStyle: const TextStyle(
                    color: Colors.white30,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: ProjectRadius.medium(),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _isYoutubeValid = _youtubeService.isValidYouTubeUrl(value);
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isYoutubeValid
                  ? () {
                      widget.onSelectVideo(
                        drive.File(
                          id: _youtubeUrlController.text.trim(),
                          name: 'YouTube Video',
                        ),
                      );
                      _youtubeUrlController.clear();
                      setState(() => _isYoutubeValid = false);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorsCustom.skyBlue,
                disabledBackgroundColor: ColorsCustom.skyBlue.withValues(
                  alpha: 0.3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: ProjectRadius.medium(),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              child: const Text('İzle'),
            ),
          ],
        ),
      ],
    );
  }

  void _showYouTubeSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => YouTubeSearchSheet(
        onVideoSelected: (url, title) {
          widget.onSelectVideo(drive.File(id: url, name: title));
        },
      ),
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
