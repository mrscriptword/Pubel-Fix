import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserSettings {
  final ThemeMode themeMode;
  final String username;
  
  UserSettings({required this.themeMode, required this.username});
  
  UserSettings copyWith({ThemeMode? themeMode, String? username}) {
    return UserSettings(
      themeMode: themeMode ?? this.themeMode,
      username: username ?? this.username,
    );
  }
}

class UserSettingsNotifier extends StateNotifier<UserSettings> {
  UserSettingsNotifier() : super(UserSettings(themeMode: ThemeMode.system, username: 'Pubel User'));
  
  void toggleTheme(bool isDark) {
    state = state.copyWith(themeMode: isDark ? ThemeMode.dark : ThemeMode.light);
  }
  
  void updateUsername(String name) {
    state = state.copyWith(username: name);
  }
}

final userSettingsProvider = StateNotifierProvider<UserSettingsNotifier, UserSettings>((ref) {
  return UserSettingsNotifier();
});
