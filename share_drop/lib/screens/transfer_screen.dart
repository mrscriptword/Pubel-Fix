import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_colors.dart';
import '../providers/file_list_provider.dart';
import '../providers/user_profile_provider.dart';

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  bool _isPicking = false;

  @override
  Widget build(BuildContext context) {
    final fileListState = ref.watch(fileListProvider);
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme),
            _buildConnectionCard(theme),
            _buildPickArea(theme),
            _buildSectionHeader(theme, 'Antrian Kirim', 'Hapus semua'),
            fileListState.when(
              data: (files) => _buildQueueList(files, theme),
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
            if (fileListState.value != null && fileListState.value!.isNotEmpty) 
              _buildSendButton(fileListState.value!.length, theme),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Transfer Langsung', style: theme.textTheme.bodyMedium?.copyWith(color: theme.iconTheme.color)),
          const SizedBox(height: 4),
          Text('Kirim File', style: theme.textTheme.titleLarge?.copyWith(fontSize: 26)),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(ThemeData theme) {
    final user = ref.watch(userProfileProvider);
    
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('KONEKSI', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.5, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  const Text('Terhubung', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.green)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _deviceItem(theme, Icons.smartphone_rounded, user.deviceName, 'Pengirim', theme.textTheme.bodyLarge?.color ?? Colors.black),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.swap_horiz_rounded, color: theme.iconTheme.color, size: 20),
              ),
              _deviceItem(theme, Icons.laptop_rounded, 'PC Tujuan', 'Tujuan', AppColors.accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _deviceItem(ThemeData theme, IconData icon, String name, String sub, Color iconColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor, 
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor, width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 6),
            Text(name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 12), overflow: TextOverflow.ellipsis),
            Text(sub, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildPickArea(ThemeData theme) {
    return GestureDetector(
      onTap: _pickFiles,
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor, style: BorderStyle.solid), 
        ),
        child: Column(
          children: [
            Icon(Icons.add_to_photos_rounded, color: theme.iconTheme.color?.withOpacity(0.5), size: 36),
            const SizedBox(height: 10),
            Text('Tambah File', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Ketuk untuk memilih file', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, String actionLabel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          GestureDetector(
            onTap: () {},
            child: Text(actionLabel, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueList(List<dynamic> files, ThemeData theme) {
    if (files.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Antrian kosong', style: theme.textTheme.bodySmall),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: files.length,
      itemBuilder: (context, index) {
        return _buildQueueItem(files[index], theme);
      },
    );
  }

  Widget _buildQueueItem(dynamic file, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.dividerColor))),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Icon(Icons.insert_drive_file_rounded, color: theme.iconTheme.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(2)),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: 1.0, 
                          child: Container(decoration: BoxDecoration(color: theme.primaryColor, borderRadius: BorderRadius.circular(2))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Selesai', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.green)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton(int count, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: theme.primaryColor, borderRadius: BorderRadius.circular(18)),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Kirim Semua ($count file)', style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFiles() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);

    try {
      await FilePicker.platform.pickFiles(allowMultiple: true);
    } catch (e) {
      debugPrint('Error picking: $e');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }
}
