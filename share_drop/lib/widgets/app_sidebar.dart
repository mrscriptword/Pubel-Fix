import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_spacing.dart';
import '../theme/app_colors.dart';
import '../providers/user_profile_provider.dart';
import '../screens/settings_screen.dart';

class AppSidebar extends ConsumerWidget {
  final int selectedIndex;
  final Function(int) onMenuSelected;
  final Function(String) onCategorySelected;
  final int sharedBadgeCount; // Berapa jumlah file di menu "Dikirim"

  const AppSidebar({
    Key? key,
    required this.selectedIndex,
    required this.onMenuSelected,
    required this.onCategorySelected,
    this.sharedBadgeCount = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    // Mengambil data device dari provider
    final userProfile = ref.watch(userProfileProvider);

    return Container(
      width: AppSpacing.sidebarWidth, // 220px
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(right: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Sidebar Header (Brand Logo)
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: theme.textTheme.bodyLarge?.color, // Setara var(--text)
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(Icons.sync_alt, color: theme.scaffoldBackgroundColor, size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pubel', style: theme.textTheme.titleLarge),
                      Text('v2.0 / flutter', style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'DM Mono',
                        fontSize: 11,
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(color: theme.dividerColor, height: 1),

          // 2. Navigation Section (Scrollable if overflow)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              children: [
                Text('MENU', style: theme.textTheme.labelSmall),
                const SizedBox(height: 6),
                
                _buildNavItem(
                  context: context,
                  title: 'Beranda',
                  icon: Icons.home_outlined,
                  isActive: selectedIndex == 0,
                  onTap: () => onMenuSelected(0),
                ),
                _buildNavItem(
                  context: context,
                  title: 'File Explorer',
                  icon: Icons.folder_outlined,
                  isActive: selectedIndex == 1,
                  onTap: () => onMenuSelected(1),
                ),
                _buildNavItem(
                  context: context,
                  title: 'Dikirim',
                  icon: Icons.share_outlined,
                  isActive: selectedIndex == 2,
                  badgeCount: sharedBadgeCount,
                  onTap: () => onMenuSelected(2),
                ),

                const SizedBox(height: 24),
                Text('KATEGORI', style: theme.textTheme.labelSmall),
                const SizedBox(height: 6),
                
                _buildCategoryItem(
                  context: context,
                  title: 'Gambar',
                  icon: Icons.image_outlined,
                  iconColor: theme.brightness == Brightness.dark ? AppColors.darkRed : AppColors.red,
                  onTap: () => onCategorySelected('Images'),
                ),
                _buildCategoryItem(
                  context: context,
                  title: 'Video',
                  icon: Icons.movie_outlined,
                  iconColor: theme.brightness == Brightness.dark ? AppColors.darkAccent : AppColors.accent,
                  onTap: () => onCategorySelected('Videos'),
                ),
                _buildCategoryItem(
                  context: context,
                  title: 'Musik',
                  icon: Icons.music_note_outlined,
                  iconColor: theme.brightness == Brightness.dark ? AppColors.darkAmber : AppColors.amber,
                  onTap: () => onCategorySelected('Music'),
                ),
                _buildCategoryItem(
                  context: context,
                  title: 'Dokumen',
                  icon: Icons.description_outlined,
                  iconColor: theme.brightness == Brightness.dark ? AppColors.darkGreen : AppColors.green,
                  onTap: () => onCategorySelected('Docs'),
                ),
              ],
            ),
          ),

          // 3. Footer (Device Info Pill)
          Divider(color: theme.dividerColor, height: 1),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.inputDecorationTheme.fillColor, // var(--surface2)
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Row(
                  children: [
                    // Green Dot Indicator
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary, // var(--green)
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.secondary.withOpacity(0.2),
                            spreadRadius: 2,
                          )
                        ]
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userProfile.deviceName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            userProfile.deviceSub,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'DM Mono',
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isActive,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    // Background dan warna teks saat aktif menggunakan skema aksen
    final activeBg = theme.primaryColor.withOpacity(0.1); 
    final activeColor = theme.primaryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Row(
          children: [
            Icon(
              icon, 
              size: 20, 
              color: isActive ? activeColor : theme.iconTheme.color
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                  color: isActive ? activeColor : theme.iconTheme.color,
                ),
              ),
            ),
            if (badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeCount.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontFamily: 'DM Mono',
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 10),
            Text(
              title,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.iconTheme.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
