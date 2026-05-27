import 'package:flutter/material.dart';
import 'dart:ui';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AppBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 84,
          padding: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xE6111009) : const Color(0xE6F7F5F1), // rgba with 0.9 opacity
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNavItem(context, Icons.home_outlined, 'Beranda', 0),
              _buildNavItem(context, Icons.send_outlined, 'Kirim', 1),
              _buildNavItem(context, Icons.folder_outlined, 'File', 2),
              _buildNavItem(context, Icons.history_outlined, 'Riwayat', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, int index) {
    final isActive = currentIndex == index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Warna mengikuti mobile design (inactive abu-abu, active hitam/putih tegas)
    final inactiveColor = const Color(0xFFB0ADA8);
    final activeColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final bgColor = isActive ? (isDark ? Colors.white12 : Colors.black12) : Colors.transparent;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isActive ? activeColor : inactiveColor,
                fontSize: 10,
                letterSpacing: 0.2, // setara dengan 0.02em
              ),
            ),
          ],
        ),
      ),
    );
  }
}
