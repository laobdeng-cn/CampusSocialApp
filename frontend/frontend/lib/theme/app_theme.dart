import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const blue = Color(0xFF1677FF);
  static const blueDark = Color(0xFF0D5BE1);
  static const green = Color(0xFF18C964);
  static const orange = Color(0xFFFFA928);
  static const purple = Color(0xFF7C5CFF);
  static const red = Color(0xFFFF4D57);
  static const ink = Color(0xFF111827);
  static const text = Color(0xFF2D3748);
  static const muted = Color(0xFF7B8494);
  static const line = Color(0xFFE7ECF3);
  static const surface = Color(0xFFF5F8FC);
}

ThemeData buildAppTheme() {
  const baseText = TextTheme(
    displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
    headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
    headlineMedium: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
    titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
    bodyLarge: TextStyle(fontSize: 16, height: 1.45),
    bodyMedium: TextStyle(fontSize: 14, height: 1.45),
    labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      primary: AppColors.blue,
      secondary: AppColors.green,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.surface,
    fontFamily: 'PingFang SC',
    textTheme: baseText.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.ink,
      centerTitle: true,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.blue,
      unselectedItemColor: Color(0xFF717B8C),
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 1,
    ),
  );
}
