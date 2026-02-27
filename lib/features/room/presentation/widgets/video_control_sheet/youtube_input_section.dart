import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/core/services/youtube_service.dart';
import 'package:emotional/features/room/presentation/widgets/youtube_search_sheet.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class YoutubeInputSection extends StatefulWidget {
  final void Function(drive.File) onSelectVideo;

  const YoutubeInputSection({super.key, required this.onSelectVideo});

  @override
  State<YoutubeInputSection> createState() => _YoutubeInputSectionState();
}

class _YoutubeInputSectionState extends State<YoutubeInputSection> {
  final _controller = TextEditingController();
  final _youtubeService = YouTubeService();
  bool _isValid = false;

  @override
  void dispose() {
    _controller.dispose();
    _youtubeService.dispose();
    super.dispose();
  }

  void _showYouTubeSearch() {
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

  void _submit() {
    widget.onSelectVideo(
      drive.File(id: _controller.text.trim(), name: 'YouTube Video'),
    );
    _controller.clear();
    setState(() => _isValid = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              LocaleKeys.video_youtube.tr(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              onPressed: _showYouTubeSearch,
              icon: const Icon(
                Icons.search,
                size: 20,
                color: ColorsCustom.skyBlue,
              ),
              tooltip: LocaleKeys.video_youtubeSearch.tr(),
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
                controller: _controller,
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
                    _isValid = _youtubeService.isValidYouTubeUrl(value);
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isValid ? _submit : null,
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
              child: Text(LocaleKeys.button_watch.tr()),
            ),
          ],
        ),
      ],
    );
  }
}
