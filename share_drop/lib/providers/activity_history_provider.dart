import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActivityItem {
  final String title;
  final String meta;
  final String type;

  ActivityItem({required this.title, required this.meta, required this.type});
}

class ActivityHistoryNotifier extends StateNotifier<List<ActivityItem>> {
  ActivityHistoryNotifier() : super([
    ActivityItem(title: 'Mengirim Project_Pubel.zip', meta: 'Ke Macbook Pro • 2 Menit lalu', type: 'sent'),
    ActivityItem(title: 'Menerima design_assets.fig', meta: 'Dari iPhone 13 • 1 Jam lalu', type: 'recv'),
    ActivityItem(title: 'Gagal mengirim video_final.mp4', meta: 'Koneksi terputus • 3 Jam lalu', type: 'fail'),
    ActivityItem(title: 'Menerima cat_meme.jpg', meta: 'Dari PC Desktop • Kemarin', type: 'recv'),
  ]);

  void addActivity(ActivityItem activity) {
    state = [activity, ...state];
  }
}

final activityHistoryProvider = StateNotifierProvider<ActivityHistoryNotifier, List<ActivityItem>>((ref) {
  return ActivityHistoryNotifier();
});
