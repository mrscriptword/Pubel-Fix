enum SessionType { upload, download }

class TransferSession {
  final String sessionId;
  final SessionType type;
  final String targetDeviceName;
  final int totalFiles;
  final int transferredFiles;
  final double overallProgress; // 0.0 to 1.0
  final bool isCompleted;

  TransferSession({
    required this.sessionId,
    required this.type,
    required this.targetDeviceName,
    required this.totalFiles,
    this.transferredFiles = 0,
    this.overallProgress = 0.0,
    this.isCompleted = false,
  });

  TransferSession copyWith({
    String? sessionId,
    SessionType? type,
    String? targetDeviceName,
    int? totalFiles,
    int? transferredFiles,
    double? overallProgress,
    bool? isCompleted,
  }) {
    return TransferSession(
      sessionId: sessionId ?? this.sessionId,
      type: type ?? this.type,
      targetDeviceName: targetDeviceName ?? this.targetDeviceName,
      totalFiles: totalFiles ?? this.totalFiles,
      transferredFiles: transferredFiles ?? this.transferredFiles,
      overallProgress: overallProgress ?? this.overallProgress,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
