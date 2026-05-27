import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../providers/activity_history_provider.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activities = ref.watch(activityHistoryProvider);

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Text('Riwayat', style: theme.textTheme.titleLarge?.copyWith(fontSize: 26)),
            ),
            _buildActivityList(activities, theme),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityList(List<ActivityItem> activities, ThemeData theme) {
    if (activities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 80),
          child: Column(
            children: [
              Icon(Icons.history_rounded, size: 64, color: theme.iconTheme.color?.withOpacity(0.2)),
              const SizedBox(height: 16),
              Text('Belum ada riwayat transfer', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        return _activityItem(activities[index], theme);
      },
    );
  }

  Widget _activityItem(ActivityItem act, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    Color dotColor;
    Color badgeBg;
    Color badgeText;
    String badgeLabel;

    if (act.type == 'sent') {
      dotColor = isDark ? AppColors.darkAccent : AppColors.accent;
      badgeBg = dotColor.withOpacity(0.15);
      badgeText = dotColor;
      badgeLabel = 'DIKIRIM';
    } else if (act.type == 'recv') {
      dotColor = isDark ? AppColors.darkGreen : AppColors.green;
      badgeBg = dotColor.withOpacity(0.15);
      badgeText = dotColor;
      badgeLabel = 'DITERIMA';
    } else {
      dotColor = isDark ? AppColors.darkRed : AppColors.red;
      badgeBg = dotColor.withOpacity(0.15);
      badgeText = dotColor;
      badgeLabel = 'GAGAL';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.dividerColor))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              const SizedBox(height: 4),
              Container(width: 12, height: 12, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle, border: Border.all(color: theme.scaffoldBackgroundColor, width: 2))),
              Container(width: 2, height: 40, color: theme.dividerColor),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(act.title, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, height: 1.3)),
                const SizedBox(height: 4),
                Text(act.meta, style: theme.textTheme.bodySmall?.copyWith(color: theme.iconTheme.color)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(100)),
            child: Text(badgeLabel, style: theme.textTheme.labelSmall?.copyWith(color: badgeText, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
