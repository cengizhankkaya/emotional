import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class DriveFileGridItem extends StatelessWidget {
  final drive.File file;
  final VoidCallback onTap;

  const DriveFileGridItem({super.key, required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E2229),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: ProjectRadius.medium(),
        side: const BorderSide(color: Colors.white10),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail or Placeholder
            if (file.thumbnailLink != null)
              Image.network(
                file.thumbnailLink!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPlaceholder(context),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                      color: Colors.deepPurple,
                    ),
                  );
                },
              )
            else
              _buildPlaceholder(context),

            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  stops: const [0.6, 1.0],
                ),
              ),
            ),

            // File Info
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.play_circle_fill,
                        color: Colors.white,
                        size: context.dynamicValue(20),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          file.name ?? 'Bilinmeyen Dosya',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: context.dynamicValue(12),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (file.size != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatSize(file.size!),
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: context.dynamicValue(10),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: const Color(0xFF2C3036),
      child: Center(
        child: Icon(
          Icons.video_library,
          color: Colors.white24,
          size: context.dynamicValue(40),
        ),
      ),
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
