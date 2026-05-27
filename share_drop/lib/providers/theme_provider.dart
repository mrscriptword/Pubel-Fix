import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// default: ThemeMode.light sesuai dengan <html data-theme="light">
final themeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);
