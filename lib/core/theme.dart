import 'package:flutter/material.dart';

class VaultTheme {
  static const Color bgDeep = Color(0xFF07070C);
  static const Color bgCard = Color(0xFF12121E);
  static const Color neonCyan = Color(0xFF00F5FF);
  static const Color electricViolet = Color(0xFF8B00FF);
  static const Color hotPink = Color(0xFFFF007F);
  static const Color textMain = Colors.white;
  static const Color textMuted = Color(0xFF8F8FAD);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: electricViolet,
      scaffoldBackgroundColor: bgDeep,
      colorScheme: const ColorScheme.dark(
        primary: electricViolet,
        secondary: neonCyan,
        tertiary: hotPink,
        error: Colors.redAccent,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: textMain,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
        bodyLarge: TextStyle(
          color: textMain,
          fontSize: 16,
          letterSpacing: 0.5,
        ),
        bodyMedium: TextStyle(
          color: textMuted,
          fontSize: 14,
        ),
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x1FFFFFFF), width: 1),
        ),
      ),
    );
  }
}
