import 'dart:ui';
import 'package:flutter/material.dart';

/// Design tokens for the Scan page — no new font dependencies.
abstract final class ScanTokens {
  // Radii
  static const double cardRadius = 16.0;
  static const double innerRadius = 12.0;
  static const double inputRadius = 8.0;
  static const double badgeRadius = 999.0;

  // Verdict palette
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldLight = Color(0xFF34D399);
  static const Color emeraldBg = Color(0x1A10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberLight = Color(0xFFFBBF24);
  static const Color amberBg = Color(0x1AF59E0B);
  static const Color rose = Color(0xFFEF4444);
  static const Color roseLight = Color(0xFFF87171);
  static const Color roseBg = Color(0x1AEF4444);
  static const Color gray = Color(0xFF9CA3AF);
  static const Color grayLight = Color(0xFFD1D5DB);
  static const Color grayBg = Color(0x1A9CA3AF);

  // Progress gradient
  static const List<Color> progressGradient = [
    Color(0xFF10B981), // emerald
    Color(0xFF3B82F6), // blue
    Color(0xFF8B5CF6), // violet
  ];

  // Focus/glow
  static const Color focusBlue = Color(0xFF3B82F6);
  static const Color focusBlueBg = Color(0x1A3B82F6);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color errorRedBg = Color(0x1AEF4444);

  /// Monospace text style using system monospace + tabular figures.
  static TextStyle mono({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: 'monospace',
      fontFeatures: const [FontFeature.tabularFigures()],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  /// Returns verdict-appropriate color triple.
  static ({Color accent, Color bg, Color light}) verdictColors(String? verdict) {
    switch (verdict?.toLowerCase()) {
      case 'dangerous':
        return (accent: rose, bg: roseBg, light: roseLight);
      case 'suspicious':
        return (accent: amber, bg: amberBg, light: amberLight);
      case 'pending':
      case 'error':
        return (accent: gray, bg: grayBg, light: grayLight);
      default:
        return (accent: emerald, bg: emeraldBg, light: emeraldLight);
    }
  }
}
