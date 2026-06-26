import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF5CED73), // Vibrant lime green
        cardColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF5CED73),
          secondary: Color(0xFF1E1E1E),
          error: Color(0xFFFF3B30), // Neon red warning/error
          surface: Color(0xFF1E1E1E),
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E1E1E),
          selectedItemColor: Color(0xFF5CED73),
          unselectedItemColor: Color(0xFF8E8E93),
          type: BottomNavigationBarType.fixed,
        ),
      );

  static ThemeData get lightTheme => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF4F5F0),
        primaryColor: const Color(0xFF5CED73), // Vibrant lime green
        cardColor: const Color(0xFFFFFFFF),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF5CED73),
          secondary: Color(0xFF1E293B),
          error: Color(0xFFDC2626),
          surface: Color(0xFFFFFFFF),
          onSurface: Color(0xFF0F172A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF4F5F0),
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          centerTitle: true,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFFFFFFFF),
          selectedItemColor: Color(0xFF5CED73),
          unselectedItemColor: Color(0xFF64748B),
          type: BottomNavigationBarType.fixed,
        ),
      );
  
  // Deprecated placeholder reference for backward compatibility
  static ThemeData cyberTheme = darkTheme;
}

extension AppThemeExtension on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get bg => isDark ? const Color(0xFF121212) : const Color(0xFFF4F5F0);
  Color get cardBg => isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);
  Color get border => isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0);
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF0F172A);
  Color get textSecondary => isDark ? const Color(0xFF8E8E93) : const Color(0xFF475569);
  Color get textMuted => isDark ? const Color(0xFF48484A) : const Color(0xFF64748B); // Upgraded from 0xFF94A3B8 in light mode for better contrast
  Color get bottomNavBg => isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);
  Color get inputBg => isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);
  Color get primary => const Color(0xFF5CED73);

  // High-contrast accent color for text, borders and icons
  Color get activeAccent => isDark ? const Color(0xFF5CED73) : const Color(0xFF2BA84A);

  // High-contrast colors for buttons and gradients
  List<Color> get primaryGradient => isDark
      ? const [Color(0xFF5CED73), Color(0xFF3ED65C)]
      : const [Color(0xFF2BA84A), Color(0xFF228B3A)];

  Color get primaryButtonText => isDark ? const Color(0xFF121212) : Colors.white;
}