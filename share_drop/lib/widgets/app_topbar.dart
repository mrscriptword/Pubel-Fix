import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_spacing.dart';
import '../providers/theme_provider.dart';
import '../screens/settings_screen.dart';

class AppTopbar extends ConsumerWidget {
  final String title;

  const AppTopbar({
    Key? key,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: AppSpacing.topbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.contentPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          // 1. Judul Halaman
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.iconTheme.color,
              ),
            ),
          ),
          
          // 2. Search Input
          Container(
            width: 220,
            height: 34,
            decoration: BoxDecoration(
              color: theme.inputDecorationTheme.fillColor,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Icon(Icons.search, size: 16, color: theme.iconTheme.color),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Cari file...',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.iconTheme.color,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.only(bottom: 14),
                      isDense: true,
                      fillColor: Colors.transparent, // override default theme
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          
          // 3. Tombol Toggle Tema
          _buildActionButton(
            context: context,
            icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            onTap: () {
              ref.read(themeProvider.notifier).state = isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          const SizedBox(width: 12),

          // 4. Tombol Pengaturan
          _buildActionButton(
            context: context,
            icon: Icons.settings_outlined,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: theme.inputDecorationTheme.fillColor,
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Icon(icon, size: 18, color: theme.iconTheme.color),
      ),
    );
  }
}
