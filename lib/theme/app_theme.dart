import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tema global de la app: aquí se definen los colores que usan
/// automáticamente los botones, barras y campos de Material.
ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.teal,
    primary: AppColors.teal,
    secondary: AppColors.blue,
    tertiary: AppColors.aqua,
    surface: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.light,
    dividerColor: AppColors.line,
    chipTheme: const ChipThemeData(
      selectedColor: AppColors.sky,
      side: BorderSide(color: AppColors.gray),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.sky,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.teal),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.deep,
      behavior: SnackBarBehavior.floating,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.light,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
