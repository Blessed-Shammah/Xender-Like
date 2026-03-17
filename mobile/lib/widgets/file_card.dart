import 'package:flutter/material.dart';
import '../models/file_model.dart';
import 'package:intl/intl.dart';

class FileCard extends StatelessWidget {
  final FileModel file;
  final String? previewUrl;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const FileCard({
    super.key,
    required this.file,
    this.previewUrl,
    required this.onDownload,
    required this.onDelete,
  });

  IconData _getCategoryIcon() {
    switch (file.category) {
      case 'image': return Icons.image_rounded;
      case 'video': return Icons.videocam_rounded;
      case 'audio': return Icons.headphones_rounded;
      case 'document': return Icons.description_rounded;
      case 'spreadsheet': return Icons.table_chart_rounded;
      case 'presentation': return Icons.slideshow_rounded;
      case 'archive': return Icons.folder_zip_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  Color _getCategoryColor() {
    switch (file.category) {
      case 'image': return const Color(0xFFF472B6);
      case 'video': return const Color(0xFFFB923C);
      case 'audio': return const Color(0xFF34D399);
      case 'document': return const Color(0xFF60A5FA);
      case 'spreadsheet': return const Color(0xFF4ADE80);
      case 'presentation': return const Color(0xFFFBBF24);
      case 'archive': return const Color(0xFFA78BFA);
      default: return const Color(0xFF94A3B8);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // --- File Icon / Preview ---
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: previewUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            previewUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(_getCategoryIcon(), color: color, size: 26),
                          ),
                        )
                      : Center(
                          child: Icon(_getCategoryIcon(), color: color, size: 26),
                        ),
                ),
                const SizedBox(width: 14),

                // --- File Info ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.originalName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            file.extension.toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${file.sizeFormatted} · ${_formatDate(file.uploadedAt)}',
                            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    ],
                  ),
                ),

                // --- Actions ---
                IconButton(
                  icon: const Icon(Icons.download_rounded, size: 22),
                  color: const Color(0xFF6366F1),
                  onPressed: onDownload,
                  tooltip: 'Download',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 22),
                  color: Colors.white.withValues(alpha: 0.3),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
