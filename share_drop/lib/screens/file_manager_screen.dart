import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../providers/file_list_provider.dart';
import '../providers/storage_provider.dart';
import '../models/file_item.dart';

class FileManagerScreen extends ConsumerStatefulWidget {
  const FileManagerScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends ConsumerState<FileManagerScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storageState = ref.watch(storageProvider);
    final fileListState = ref.watch(fileListProvider);

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme),
            _buildSearchBar(theme),
            _buildStorageVisual(theme, storageState),
            _buildSectionHeader(theme, 'Kategori Folder'),
            _buildFolderGrid(theme, fileListState),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Text('File Saya', style: theme.textTheme.titleLarge?.copyWith(fontSize: 26)),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: theme.iconTheme.color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Cari file atau folder...',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.iconTheme.color),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageVisual(ThemeData theme, AsyncValue<StorageInfo> storageState) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: theme.primaryColor, borderRadius: BorderRadius.circular(24)),
      child: storageState.when(
        data: (storage) {
          final double usedGB = storage.usedMB / 1024;
          final double totalGB = storage.totalMB / 1024;
          final double percentage = (totalGB > 0) ? (usedGB / totalGB) : 0;
          final int percentInt = (percentage * 100).toInt();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Penyimpanan Internal', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('$percentInt% Terpakai', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
                    ],
                  ),
                  const Icon(Icons.storage_rounded, color: Colors.white54, size: 24),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${usedGB.toStringAsFixed(1)} GB', style: theme.textTheme.displayLarge?.copyWith(color: Colors.white, fontSize: 32, height: 1)),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('dari ${totalGB.toStringAsFixed(0)} GB', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(4)),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: percentage.clamp(0.0, 1.0),
                  child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 24), child: CircularProgressIndicator(color: Colors.white))),
        error: (err, stack) => Center(child: Text('Gagal memuat: $err', style: const TextStyle(color: Colors.white))),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildFolderGrid(ThemeData theme, AsyncValue<List<FileItem>> fileListState) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        final isDark = theme.brightness == Brightness.dark;

        return fileListState.when(
          data: (files) {
            int imgCount = 0; int imgSize = 0;
            int vidCount = 0; int vidSize = 0;
            int docCount = 0; int docSize = 0;
            int musCount = 0; int musSize = 0;

            for (var f in files) {
              if (f.type == FileType.image) { imgCount++; imgSize += f.sizeInBytes; }
              else if (f.type == FileType.video) { vidCount++; vidSize += f.sizeInBytes; }
              else if (f.type == FileType.document) { docCount++; docSize += f.sizeInBytes; }
              else if (f.type == FileType.music) { musCount++; musSize += f.sizeInBytes; }
            }

            String formatSize(int bytes) {
              if (bytes == 0) return '0 B';
              double mb = bytes / (1024 * 1024);
              if (mb > 1024) {
                return '${(mb/1024).toStringAsFixed(1)} GB';
              }
              return '${mb.toStringAsFixed(1)} MB';
            }

            final folders = [
              {'name': 'Gambar', 'icon': Icons.image_rounded, 'color': isDark ? AppColors.darkRed : AppColors.red, 'count': imgCount.toString(), 'size': formatSize(imgSize)},
              {'name': 'Video', 'icon': Icons.movie_rounded, 'color': isDark ? AppColors.darkAccent : AppColors.accent, 'count': vidCount.toString(), 'size': formatSize(vidSize)},
              {'name': 'Dokumen', 'icon': Icons.description_rounded, 'color': isDark ? AppColors.darkGreen : AppColors.green, 'count': docCount.toString(), 'size': formatSize(docSize)},
              {'name': 'Musik', 'icon': Icons.music_note_rounded, 'color': isDark ? AppColors.darkAmber : AppColors.amber, 'count': musCount.toString(), 'size': formatSize(musSize)},
            ];

            return GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.1,
              ),
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final f = folders[index];
                return _folderCard(theme, f['name'] as String, f['icon'] as IconData, f['color'] as Color, f['count'] as String, f['size'] as String);
              },
            );
          },
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
          error: (err, stack) => const SizedBox(),
        );
      },
    );
  }

  Widget _folderCard(ThemeData theme, String name, IconData icon, Color color, String count, String size) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 22),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                child: Text(count, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const Spacer(),
          Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
          Text(size, style: theme.textTheme.bodySmall?.copyWith(color: theme.iconTheme.color)),
        ],
      ),
    );
  }
}
