import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData buildAppTheme() {
  const background = Color(0xFFF5F1E8);
  const olive = Color(0xFF5F7352);
  const ink = Color(0xFF213646);
  const accent = Color(0xFFD98C3F);

  final textTheme = GoogleFonts.notoSansArabicTextTheme().apply(
    bodyColor: ink,
    displayColor: ink,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: olive,
      secondary: accent,
      surface: Colors.white,
      onSurface: ink,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    ),
    scaffoldBackgroundColor: background,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      elevation: 0,
      foregroundColor: ink,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white.withValues(alpha: 0.92),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
