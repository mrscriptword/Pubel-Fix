import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/app_theme.dart';
import 'providers/settings_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ),
  );
  
  runApp(
    // Membungkus seluruh aplikasi dengan ProviderScope untuk Riverpod
    const ProviderScope(
      child: PubelApp(),
    ),
  );
}

class PubelApp extends ConsumerWidget {
  const PubelApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Terhubung ke userSettingsProvider untuk mengambil ThemeMode
    final userSettings = ref.watch(userSettingsProvider);
    
    return MaterialApp(
      title: 'Pubel',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: userSettings.themeMode,
      home: const SplashScreen(nextScreen: MainScreen()),
      debugShowCheckedModeBanner: false,
    );
  }
}
