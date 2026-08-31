import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const green = Color(0xFF2E7D32);
  static const paleGreen = Color(0xFFE9F5E9);
  static const lightGreen = Color(0xFFC8E6C9);
  static const orange = Color(0xFFE07D21);
  static const text = Color(0xFF212121);
  static const muted = Color(0xFF616161);
  static const border = Color(0xFFD9D9D9);
  static const chip = Color(0xFFF2F2F2);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.green),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        color: AppColors.text,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: AppColors.text,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: TextStyle(color: AppColors.text),
    ),
  );
}
