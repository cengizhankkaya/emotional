import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class DriveFileListItem extends StatelessWidget {
  final drive.File file;
  final bool isLocal;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const DriveFileListItem({
    super.key,
    required this.file,
    required this.isLocal,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
        onTap: onTap,
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
                  isLocal ? Icons.check_circle_outline : Icons.video_library,
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
              if (isLocal && onDelete != null) ...[
                SizedBox(width: context.dynamicWidth(0.02)),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  onPressed: onDelete,
                ),
              ] else
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
