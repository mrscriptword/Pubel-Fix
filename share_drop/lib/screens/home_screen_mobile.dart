import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/file_list_provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/storage_provider.dart';
import '../models/file_item.dart';
import '../widgets/mobile_upload_card.dart';
import '../widgets/mini_stat_row.dart';
import '../widgets/category_chips.dart';
import '../widgets/file_item_card.dart';

class HomeScreenMobile extends ConsumerWidget {
  const HomeScreenMobile({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userProfile = ref.watch(userProfileProvider);
    final fileListState = ref.watch(fileListProvider);
    final storageState = ref.watch(storageProvider);

    final filesData = fileListState.value ?? [];
    int sentCount = filesData.where((f) => f.status == FileStatus.sent).length;
    int receivedCount = filesData.where((f) => f.status == FileStatus.received || f.status == FileStatus.ready).length;
    
    String storageText = '0 GB';
    storageState.whenData((s) {
      storageText = '${(s.usedMB / 1024).toStringAsFixed(1)} GB';
    });

    // Ambil nama depan dari Device Name (misal: "Pubel Preview" -> "Pubel")
    final firstName = userProfile.deviceName.split(' ').first;
    // Ambil inisial (misal: "PU")
    final initial = firstName.length >= 2 ? firstName.substring(0, 2).toUpperCase() : firstName.toUpperCase();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header (Greeting & Avatar)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Selamat pagi, $firstName 👋',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.iconTheme.color),
                        ),
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: theme.textTheme.bodyLarge?.color,
                          child: Text(
                            initial,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.surface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kirim &\nTerima File',
                      style: theme.textTheme.titleLarge?.copyWith(fontSize: 28, height: 1.1),
                    ),
                  ],
                ),
              ),

              // 2. Upload Card
              MobileUploadCard(onTap: () {
                // TODO: Buka file picker
              }),

              // 3. Stats Horizontal
              MiniStatRow(sent: sentCount, received: receivedCount, storage: storageText),

              // 4. Recent Files Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('File Terbaru', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text('Lihat semua', style: theme.textTheme.bodySmall?.copyWith(color: theme.iconTheme.color)),
                  ],
                ),
              ),

              // 5. Category Chips Horizontal
              CategoryChips(onSelected: (cat) {
                // TODO: Filter list
              }),
              
              const SizedBox(height: 8),

              // 6. List of Files (Reusable widget FileItemCard)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: fileListState.when(
                  loading: () => const Center(child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  )),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                  data: (files) {
                    if (files.isEmpty) {
                      return const Center(child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text('Tidak ada file terbaru.'),
                      ));
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: files.length,
                      itemBuilder: (context, index) {
                        return FileItemCard(
                          file: files[index],
                          onDownload: () {},
                          onShare: () {},
                          onDelete: () {},
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
