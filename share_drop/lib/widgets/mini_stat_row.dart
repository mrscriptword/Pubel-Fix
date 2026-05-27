import 'package:flutter/material.dart';

class MiniStatRow extends StatelessWidget {
  final int sent;
  final int received;
  final String storage;

  const MiniStatRow({
    Key? key,
    required this.sent,
    required this.received,
    required this.storage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          Expanded(child: _buildMiniStat(context, sent.toString(), 'Dikirim', Icons.arrow_upward, const Color(0xFFE8F5EE), const Color(0xFF1A7A4A))),
          const SizedBox(width: 12),
          Expanded(child: _buildMiniStat(context, received.toString(), 'Diterima', Icons.arrow_downward, const Color(0xFFEEF3FD), const Color(0xFF2D5BE3))),
          const SizedBox(width: 12),
          Expanded(child: _buildMiniStat(context, storage, 'Dipakai', Icons.storage, const Color(0xFFFDF2E8), const Color(0xFFB85C0A))),
        ],
      ),
    );
  }

  Widget _buildMiniStat(BuildContext context, String val, String label, IconData icon, Color bgColor, Color iconColor) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(val, style: theme.textTheme.displayLarge?.copyWith(fontSize: 22, height: 1)),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: theme.iconTheme.color)),
        ],
      ),
    );
  }
}
