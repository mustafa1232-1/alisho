import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData buildAppTheme(Locale locale) {
  const background = Color(0xFFF5F1E8);
  const olive = Color(0xFF5F7352);
  const ink = Color(0xFF213646);
  const accent = Color(0xFFD98C3F);
  final isArabic = locale.languageCode == 'ar';

  final textTheme = (isArabic
          ? GoogleFonts.notoSansArabicTextTheme()
          : GoogleFonts.nunitoSansTextTheme())
      .apply(
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
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: ink,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.96),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final weight = states.contains(WidgetState.selected)
            ? FontWeight.w700
            : FontWeight.w500;
        return textTheme.labelMedium?.copyWith(fontWeight: weight);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected) ? olive : ink,
        );
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.6),
      selectedIconTheme: const IconThemeData(color: olive),
      selectedLabelTextStyle:
          textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      color: Colors.white.withValues(alpha: 0.92),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: const Color(0xFFF0E9DC),
      selectedColor: olive.withValues(alpha: 0.16),
      side: BorderSide.none,
      labelStyle: textTheme.bodySmall,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ink,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      behavior: SnackBarBehavior.floating,
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
