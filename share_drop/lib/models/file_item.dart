enum FileType { image, video, document, music, archive, unknown }
enum FileStatus { ready, sending, sent, receiving, received, error }

class FileItem {
  final String id;
  final String name;
  final int sizeInBytes;
  final FileType type;
  final FileStatus status;
  final double progress; // 0.0 to 1.0
  final DateTime date;

  FileItem({
    required this.id,
    required this.name,
    required this.sizeInBytes,
    required this.type,
    required this.status,
    this.progress = 0.0,
    required this.date,
  });

  FileItem copyWith({
    String? id,
    String? name,
    int? sizeInBytes,
    FileType? type,
    FileStatus? status,
    double? progress,
    DateTime? date,
  }) {
    return FileItem(
      id: id ?? this.id,
      name: name ?? this.name,
      sizeInBytes: sizeInBytes ?? this.sizeInBytes,
      type: type ?? this.type,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      date: date ?? this.date,
    );
  }
}
