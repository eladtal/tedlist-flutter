import 'package:flutter/material.dart';

class AppTheme {
  // Tedlist Color Palette
  static const Color teddyRed = Color(0xFFEF5350);
  static const Color mintByte = Color(0xFFB2F2BB);
  static const Color eggshell = Color(0xFFFAF9F6);
  static const Color bananaCream = Color(0xFFFFF3B0);
  static const Color teddyBrown = Color(0xFF3E3C3A);
  static const Color denimTrade = Color(0xFF4A6FA5);

  // Light Theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: teddyRed,
      secondary: mintByte,
      background: eggshell,
      surface: Colors.white,
      error: Colors.red.shade700,
      onPrimary: Colors.white,
      onSecondary: teddyBrown,
      onBackground: teddyBrown,
      onSurface: teddyBrown,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: eggshell,
    appBarTheme: const AppBarTheme(
      backgroundColor: eggshell,
      elevation: 0,
      centerTitle: true,
      foregroundColor: teddyBrown,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: teddyRed,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: Colors.white,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: teddyRed, width: 2),
      ),
    ),
  );

  // Dark Theme (simplified version for now)
  static final ThemeData darkTheme = ThemeData.dark().copyWith(
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: teddyRed,
      secondary: mintByte,
      background: Colors.grey[900]!,
      surface: Colors.grey[800]!,
      error: Colors.red.shade300,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onBackground: Colors.white,
      onSurface: Colors.white,
      onError: Colors.black,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: teddyRed,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
  );
} 