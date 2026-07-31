import 'package:flutter/material.dart';

/// Shared application colors. These are the single source of truth for both
/// themes so feature screens do not drift away from the approved palette.
abstract final class AppPalette {
  // Dark theme
  static const darkBackground = Color(0xFF09090B);
  static const darkSurface = Color(0xFF111827);
  static const darkCard = Color(0xFF18181B);
  static const darkBorder = Color.fromRGBO(255, 255, 255, 0.06);
  static const darkTextPrimary = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFFCBD5E1);
  static const darkAccentGreen = Color(0xFF22C55E);
  static const darkAccentBlue = Color(0xFF3B82F6);
  static const darkDanger = Color(0xFFEF4444);
  static const darkWarning = Color(0xFFFACC15);
  static const darkHoverSurface = Color(0xFF1F2430);

  // Light theme
  static const lightBackground = Color(0xFFF8FAFC);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFF1F5F9);
  static const lightTextPrimary = Color(0xFF0F172A);
  static const lightTextSecondary = Color(0xFF475569);
  static const lightBorder = Color(0xFFE2E8F0);
  static const lightAccentGreen = Color(0xFF16A34A);
  static const lightAccentBlue = Color(0xFF2563EB);
  static const lightDanger = Color(0xFFDC2626);
  static const lightWarning = Color(0xFFD97706);
}

class AppTheme {
  static ThemeData get darkTheme {
    const scheme = ColorScheme.dark(
      primary: AppPalette.darkAccentGreen,
      secondary: AppPalette.darkAccentBlue,
      tertiary: AppPalette.darkWarning,
      error: AppPalette.darkDanger,
      surface: AppPalette.darkSurface,
      onPrimary: AppPalette.darkBackground,
      onSecondary: AppPalette.darkTextPrimary,
      onSurface: AppPalette.darkTextPrimary,
      outline: AppPalette.darkBorder,
    );

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppPalette.darkBackground,
      canvasColor: AppPalette.darkBackground,
      primaryColor: AppPalette.darkAccentGreen,
      cardColor: AppPalette.darkCard,
      dividerColor: AppPalette.darkBorder,
      colorScheme: scheme,
      textTheme: ThemeData.dark().textTheme.apply(
        bodyColor: AppPalette.darkTextPrimary,
        displayColor: AppPalette.darkTextPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppPalette.darkBackground,
        foregroundColor: AppPalette.darkTextPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppPalette.darkCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppPalette.darkBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.darkSurface,
        labelStyle: const TextStyle(color: AppPalette.darkTextSecondary),
        hintStyle: const TextStyle(color: AppPalette.darkTextSecondary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppPalette.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: AppPalette.darkAccentGreen,
            width: 1.5,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.darkAccentGreen,
          foregroundColor: AppPalette.darkBackground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.darkAccentGreen,
          side: const BorderSide(color: AppPalette.darkAccentGreen),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppPalette.darkCard,
        selectedItemColor: AppPalette.darkAccentGreen,
        unselectedItemColor: AppPalette.darkTextSecondary,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppPalette.darkCard,
        indicatorColor: AppPalette.darkHoverSurface,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppPalette.darkCard,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  static ThemeData get lightTheme {
    const scheme = ColorScheme.light(
      primary: AppPalette.lightAccentGreen,
      secondary: AppPalette.lightAccentBlue,
      tertiary: AppPalette.lightWarning,
      error: AppPalette.lightDanger,
      surface: AppPalette.lightCard,
      onPrimary: AppPalette.lightCard,
      onSecondary: AppPalette.lightCard,
      onSurface: AppPalette.lightTextPrimary,
      outline: AppPalette.lightBorder,
    );

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppPalette.lightBackground,
      canvasColor: AppPalette.lightBackground,
      primaryColor: AppPalette.lightAccentGreen,
      cardColor: AppPalette.lightCard,
      dividerColor: AppPalette.lightBorder,
      colorScheme: scheme,
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: AppPalette.lightTextPrimary,
        displayColor: AppPalette.lightTextPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppPalette.lightBackground,
        foregroundColor: AppPalette.lightTextPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppPalette.lightCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppPalette.lightBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.lightCard,
        labelStyle: const TextStyle(color: AppPalette.lightTextSecondary),
        hintStyle: const TextStyle(color: AppPalette.lightTextSecondary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppPalette.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: AppPalette.lightAccentGreen,
            width: 1.5,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.lightAccentGreen,
          foregroundColor: AppPalette.lightCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.lightAccentGreen,
          side: const BorderSide(color: AppPalette.lightAccentGreen),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppPalette.lightCard,
        selectedItemColor: AppPalette.lightAccentGreen,
        unselectedItemColor: AppPalette.lightTextSecondary,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppPalette.lightCard,
        indicatorColor: AppPalette.lightSurfaceAlt,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppPalette.lightCard,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  static ThemeData cyberTheme = darkTheme;
}

extension AppThemeExtension on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get bg =>
      isDark ? AppPalette.darkBackground : AppPalette.lightBackground;
  Color get cardBg => isDark ? AppPalette.darkCard : AppPalette.lightCard;
  Color get secondaryCardBg =>
      isDark ? AppPalette.darkSurface : AppPalette.lightSurfaceAlt;
  Color get border => isDark ? AppPalette.darkBorder : AppPalette.lightBorder;
  Color get textPrimary =>
      isDark ? AppPalette.darkTextPrimary : AppPalette.lightTextPrimary;
  Color get textSecondary =>
      isDark ? AppPalette.darkTextSecondary : AppPalette.lightTextSecondary;
  Color get textMuted => textSecondary.withOpacity(isDark ? 0.60 : 0.70);
  Color get bottomNavBg => cardBg;
  Color get inputBg => isDark ? AppPalette.darkSurface : AppPalette.lightCard;
  Color get hoverSurface =>
      isDark ? AppPalette.darkHoverSurface : AppPalette.lightSurfaceAlt;
  Color get primary => activeAccent;
  Color get activeAccent => Theme.of(this).colorScheme.primary;
  Color get safe => activeAccent;
  Color get warning =>
      isDark ? AppPalette.darkWarning : AppPalette.lightWarning;
  Color get danger => isDark ? AppPalette.darkDanger : AppPalette.lightDanger;
  Color get information =>
      isDark ? AppPalette.darkAccentBlue : AppPalette.lightAccentBlue;

  List<Color> get primaryGradient => const [
    Color(0xFF071A12),
    Color(0xFF0D241B),
  ];

  Color get primaryButtonText =>
      isDark ? AppPalette.darkBackground : AppPalette.lightCard;
}
