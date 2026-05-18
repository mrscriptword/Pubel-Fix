import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

import '../server/http_server.dart';

class ActivityScreen extends StatelessWidget {
  final LocalServer server;
  const ActivityScreen({Key? key, required this.server}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Text('Riwayat', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 26)),
              ),
              _buildActivityList(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityList() {
    final activities = server.transferHistory.reversed.toList();

    if (activities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Column(
            children: [
              Icon(Icons.history_rounded, size: 64, color: AppTheme.textSecondary.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text('Belum ada riwayat transfer', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
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
        final act = activities[index];
        return _activityItem(act['title']!, act['meta']!, act['type']!);
      },
    );
  }

  Widget _activityItem(String title, String meta, String type) {
    Color dotColor;
    Color badgeBg;
    Color badgeText;
    String badgeLabel;

    if (type == 'sent') {
      dotColor = AppTheme.accentBlue;
      badgeBg = AppTheme.accentBlue.withOpacity(0.1);
      badgeText = AppTheme.accentBlue;
      badgeLabel = 'DIKIRIM';
    } else if (type == 'recv') {
      dotColor = AppTheme.accentGreen;
      badgeBg = AppTheme.accentGreen.withOpacity(0.1);
      badgeText = AppTheme.accentGreen;
      badgeLabel = 'DITERIMA';
    } else {
      dotColor = AppTheme.accentRed;
      badgeBg = AppTheme.accentRed.withOpacity(0.1);
      badgeText = AppTheme.accentRed;
      badgeLabel = 'GAGAL';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.04)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              const SizedBox(height: 4),
              Container(width: 10, height: 10, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              Container(width: 1, height: 40, color: Colors.black.withOpacity(0.07)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary, height: 1.4)),
                const SizedBox(height: 3),
                Text(meta, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(100)),
            child: Text(badgeLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: badgeText)),
          ),
        ],
      ),
    );
  }
}
