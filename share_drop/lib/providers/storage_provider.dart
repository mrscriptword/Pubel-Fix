import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:disk_space_2/disk_space_2.dart';

class StorageInfo {
  final double totalMB;
  final double usedMB;
  
  StorageInfo({required this.totalMB, required this.usedMB});
}

class StorageNotifier extends StateNotifier<AsyncValue<StorageInfo>> {
  StorageNotifier() : super(const AsyncValue.loading()) {
    _loadStorage();
  }
  
  Future<void> _loadStorage() async {
    try {
      final double? totalSpace = await DiskSpace.getTotalDiskSpace;
      final double? freeSpace = await DiskSpace.getFreeDiskSpace;
      
      if (totalSpace != null && freeSpace != null) {
        state = AsyncValue.data(StorageInfo(
          totalMB: totalSpace,
          usedMB: totalSpace - freeSpace,
        ));
      } else {
        state = AsyncValue.error('Gagal membaca storage', StackTrace.current);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final storageProvider = StateNotifierProvider<StorageNotifier, AsyncValue<StorageInfo>>((ref) {
  return StorageNotifier();
});
