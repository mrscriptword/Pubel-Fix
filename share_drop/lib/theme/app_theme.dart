import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bg,
      primaryColor: AppColors.accent,
      fontFamily: AppTextStyles.fontSans,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accent,
        onPrimary: Colors.white,
        secondary: AppColors.green,
        onSecondary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.text,
        error: AppColors.red,
        onError: Colors.white,
      ),
      textTheme: const TextTheme(
        displayLarge: AppTextStyles.statValue,
        titleLarge: AppTextStyles.brandHeading,
        titleMedium: AppTextStyles.topbarTitle,
        bodyLarge: AppTextStyles.navItem,
        bodyMedium: AppTextStyles.bodyText,
        labelSmall: AppTextStyles.sectionLabel,
      ).apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      cardTheme: CardTheme(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: AppTextStyles.bodyMedium,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: AppTextStyles.bodyText.copyWith(color: AppColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: const BorderSide(color: AppColors.border2),
        ),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.muted,
        size: 20,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      primaryColor: AppColors.darkAccent,
      fontFamily: AppTextStyles.fontSans,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkAccent,
        onPrimary: Colors.white,
        secondary: AppColors.darkGreen,
        onSecondary: Colors.white,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkText,
        error: AppColors.darkRed,
        onError: Colors.white,
      ),
      textTheme: const TextTheme(
        displayLarge: AppTextStyles.statValue,
        titleLarge: AppTextStyles.brandHeading,
        titleMedium: AppTextStyles.topbarTitle,
        bodyLarge: AppTextStyles.navItem,
        bodyMedium: AppTextStyles.bodyText,
        labelSmall: AppTextStyles.sectionLabel,
      ).apply(
        bodyColor: AppColors.darkText,
        displayColor: AppColors.darkText,
      ),
      cardTheme: CardTheme(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: AppTextStyles.bodyMedium,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: AppTextStyles.bodyText.copyWith(color: AppColors.darkMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: const BorderSide(color: AppColors.darkBorder2),
        ),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.darkMuted,
        size: 20,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
