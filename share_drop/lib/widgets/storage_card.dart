import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/app_colors.dart';

class StorageCard extends StatelessWidget {
  final String usedSpace;
  final String totalSpace;
  final double percentage; // 0.0 to 1.0

  const StorageCard({
    Key? key,
    required this.usedSpace,
    required this.totalSpace,
    required this.percentage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Warna untuk icon
    final amberColor = theme.brightness == Brightness.dark ? AppColors.darkAmber : AppColors.amber;
    final amberSoftColor = theme.brightness == Brightness.dark ? AppColors.darkAmberSoft : AppColors.amberSoft;

    // Warna gradient linear (Amber -> Red)
    final redColor = theme.brightness == Brightness.dark ? AppColors.darkRed : AppColors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PENYIMPANAN',
                style: theme.textTheme.labelSmall,
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: amberSoftColor,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(Icons.storage, color: amberColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Custom Gradient Progress Bar
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.inputDecorationTheme.fillColor, // var(--surface2)
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(
                    colors: [amberColor, redColor],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          // Teks metadata monospace
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$usedSpace digunakan',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'DM Mono',
                  fontSize: 11,
                  color: theme.iconTheme.color,
                ),
              ),
              Text(
                '$totalSpace total',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'DM Mono',
                  fontSize: 11,
                  color: theme.iconTheme.color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
