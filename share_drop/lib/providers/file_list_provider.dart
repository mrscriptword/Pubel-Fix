import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../models/file_item.dart';

class FileListNotifier extends StateNotifier<AsyncValue<List<FileItem>>> {
  FileListNotifier() : super(const AsyncValue.loading()) {
    _scanFiles();
  }

  Future<void> _scanFiles() async {
    state = const AsyncValue.loading();
    try {
      bool hasPermission = false;
      if (Platform.isAndroid) {
        // Meminta akses penuh sesuai arahan pengguna
        final status = await Permission.manageExternalStorage.request();
        if (status.isGranted) {
          hasPermission = true;
        } else {
          final storage = await Permission.storage.request();
          hasPermission = storage.isGranted;
        }
      } else {
        hasPermission = true; // Desktop otomatis granted
      }

      if (!hasPermission) {
        state = AsyncValue.error('Izin akses penyimpanan ditolak', StackTrace.current);
        return;
      }

      final Directory rootDir = Directory('/storage/emulated/0/');
      if (!rootDir.existsSync()) {
        state = const AsyncValue.data([]);
        return;
      }

      List<FileItem> scannedFiles = [];
      
      // Ambil file dari Download, Documents, dan Camera untuk contoh nyata 
      // yang tidak me-lag UI, sementara izin MANAGE_EXTERNAL_STORAGE tetap aktif
      final targetDirs = [
        Directory('/storage/emulated/0/Download'),
        Directory('/storage/emulated/0/Documents'),
        Directory('/storage/emulated/0/DCIM/Camera'),
      ];

      for (var dir in targetDirs) {
        if (dir.existsSync()) {
          try {
            final entities = dir.listSync(recursive: false, followLinks: false);
            for (var entity in entities) {
              if (entity is File) {
                final stat = entity.statSync();
                final ext = entity.path.split('.').last.toLowerCase();
                
                FileType type = FileType.document;
                if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) type = FileType.image;
                if (['mp4', 'mkv', 'avi', 'mov'].contains(ext)) type = FileType.video;
                if (['mp3', 'wav', 'm4a'].contains(ext)) type = FileType.music;
                if (['zip', 'rar', '7z'].contains(ext)) type = FileType.archive;
                
                scannedFiles.add(
                  FileItem(
                    id: entity.path,
                    name: entity.path.split('/').last,
                    sizeInBytes: stat.size,
                    type: type,
                    status: FileStatus.ready,
                    date: stat.modified,
                    progress: 0.0,
                  )
                );
              }
            }
          } catch (e) {
            // Abaikan error pada folder yang terkunci
          }
        }
      }

      // Urutkan dari yang terbaru dan limit 50 file
      scannedFiles.sort((a, b) => b.date.compareTo(a.date));
      if (scannedFiles.length > 50) {
        scannedFiles = scannedFiles.sublist(0, 50);
      }
      
      state = AsyncValue.data(scannedFiles);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void addFile(FileItem file) {
    state.whenData((files) {
      state = AsyncValue.data([file, ...files]);
    });
  }

  void updateFileProgress(String id, double progress, FileStatus status) {
    state.whenData((files) {
      final newFiles = files.map((f) {
        if (f.id == id) {
          return f.copyWith(progress: progress, status: status);
        }
        return f;
      }).toList();
      state = AsyncValue.data(newFiles);
    });
  }
}

final fileListProvider = StateNotifierProvider<FileListNotifier, AsyncValue<List<FileItem>>>((ref) {
  return FileListNotifier();
});
