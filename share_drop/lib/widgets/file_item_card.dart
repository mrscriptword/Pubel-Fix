import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/file_item.dart';
import '../theme/app_spacing.dart';

class FileItemCard extends ConsumerWidget {
  final FileItem file;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;

  const FileItemCard({
    Key? key,
    required this.file,
    this.onDownload,
    this.onDelete,
    this.onShare,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Mendapatkan warna icon & background thumb berdasarkan tipe file
    Color iconColor;
    IconData iconData;

    switch (file.type) {
      case FileType.image:
        iconColor = isDark ? const Color(0xFFF06060) : const Color(0xFFD84040); // red-ish
        iconData = Icons.image_outlined;
        break;
      case FileType.video:
        iconColor = isDark ? const Color(0xFF4E7BF0) : const Color(0xFF3B82F6); // blue
        iconData = Icons.movie_outlined;
        break;
      case FileType.document:
        iconColor = isDark ? const Color(0xFF34C77A) : const Color(0xFF10B981); // green
        iconData = Icons.description_outlined;
        break;
      case FileType.music:
        iconColor = isDark ? const Color(0xFFF59B3D) : const Color(0xFFF59E0B); // amber
        iconData = Icons.music_note_outlined;
        break;
      case FileType.archive:
        iconColor = const Color(0xFF8B5CF6); // purple
        iconData = Icons.folder_zip_outlined;
        break;
      default:
        iconColor = theme.iconTheme.color ?? Colors.grey;
        iconData = Icons.insert_drive_file_outlined;
    }

    // Apakah file sedang diproses?
    final isProcessing = file.status == FileStatus.sending || file.status == FileStatus.receiving;
    final isError = file.status == FileStatus.error;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: 0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Thumbnail Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.inputDecorationTheme.fillColor, // Setara dengan --surface2
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(iconData, color: iconColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          
          // 2. Info File (Nama, Size, Progress)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  file.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                
                // Jika sedang loading, tampilkan progress bar
                if (isProcessing) ...[
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: file.progress,
                      minHeight: 4,
                      backgroundColor: theme.dividerColor,
                      valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(file.progress * 100).toInt()}% • ${_formatStatus(file.status)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.primaryColor,
                      fontFamily: 'DM Mono',
                      fontSize: 11,
                    ),
                  ),
                ] else ...[
                  // Menampilkan size & tanggal / error
                  Text(
                    isError 
                        ? 'Gagal • ${_formatBytes(file.sizeInBytes)}' 
                        : '${_formatBytes(file.sizeInBytes)} • ${_formatDate(file.date)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isError ? theme.colorScheme.error : theme.textTheme.bodySmall?.color,
                      fontFamily: 'DM Mono',
                      fontSize: 11,
                    ),
                  ),
                ]
              ],
            ),
          ),
          
          // 3. Action Buttons (Popup Menu untuk mengakomodasi action)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: theme.iconTheme.color, size: 20),
            color: theme.cardTheme.color,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
            onSelected: (value) {
              if (value == 'download' && onDownload != null) onDownload!();
              if (value == 'share' && onShare != null) onShare!();
              if (value == 'delete' && onDelete != null) onDelete!();
            },
            itemBuilder: (context) => [
              if (onDownload != null)
                PopupMenuItem(
                  value: 'download',
                  child: Row(
                    children: [
                      Icon(Icons.download_outlined, size: 18, color: theme.iconTheme.color),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Unduh', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              if (onShare != null)
                PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined, size: 18, color: theme.iconTheme.color),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Bagikan', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              if (onDelete != null)
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Hapus', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Helpers ---
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    // Sederhana saja: format "HH:mm" untuk hari ini, "Kemarin", dll.
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0 && now.day == date.day) {
      return 'Hari ini, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1 || (diff.inDays == 0 && now.day != date.day)) {
      return 'Kemarin, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${diff.inDays} hari lalu';
    }
  }

  String _formatStatus(FileStatus status) {
    switch (status) {
      case FileStatus.sending: return 'Mengirim...';
      case FileStatus.receiving: return 'Menerima...';
      case FileStatus.ready: return 'Siap';
      case FileStatus.sent: return 'Terkirim';
      case FileStatus.received: return 'Diterima';
      case FileStatus.error: return 'Gagal';
    }
  }
}
