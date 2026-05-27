import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/user_profile_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _usernameController;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(userSettingsProvider);
    final isDark = theme.brightness == Brightness.dark;

    // Sync init value
    if (_usernameController.text.isEmpty && settings.username.isNotEmpty) {
      _usernameController.text = settings.username;
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.iconTheme.color),
        title: Text('Pengaturan', style: theme.textTheme.titleMedium?.copyWith(color: theme.iconTheme.color, fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: theme.dividerColor, height: 1),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text('PROFIL PENGGUNA', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            child: TextField(
              controller: _usernameController,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                labelText: 'Nama Perangkat',
                labelStyle: theme.textTheme.bodySmall?.copyWith(color: theme.iconTheme.color),
                border: InputBorder.none,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.save_rounded, size: 20),
                  color: theme.primaryColor,
                  onPressed: () {
                    ref.read(userSettingsProvider.notifier).updateUsername(_usernameController.text);
                    ref.read(userProfileProvider.notifier).updateDeviceName(_usernameController.text);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('Nama berhasil disimpan'),
                      backgroundColor: theme.primaryColor,
                      behavior: SnackBarBehavior.floating,
                    ));
                  },
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          Text('TAMPILAN', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            child: SwitchListTile(
              title: Text('Dark Mode', style: theme.textTheme.bodyLarge ?? const TextStyle()),
              subtitle: Text('Gunakan tema gelap', style: theme.textTheme.bodySmall?.copyWith(color: theme.iconTheme.color)),
              value: isDark,
              activeColor: theme.primaryColor,
              onChanged: (val) {
                ref.read(themeProvider.notifier).state = val ? ThemeMode.dark : ThemeMode.light;
                ref.read(userSettingsProvider.notifier).toggleTheme(val);
              },
            ),
          ),

          const SizedBox(height: 32),
          Text('TENTANG APLIKASI', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              children: [
                Icon(Icons.sync_alt_rounded, size: 48, color: theme.primaryColor),
                const SizedBox(height: 12),
                Text('Pubel', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Versi 2.0.0 Beta', style: theme.textTheme.bodySmall?.copyWith(color: theme.iconTheme.color)),
                const SizedBox(height: 16),
                Text('Aplikasi transfer file premium, cepat, dan aman melalui koneksi lokal.', 
                  textAlign: TextAlign.center, 
                  style: theme.textTheme.bodyMedium
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
