import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_defender/theme/app_theme.dart';

void main() {
  group('AppTheme palette', () {
    test('uses the approved light palette', () {
      final theme = AppTheme.lightTheme;

      expect(theme.scaffoldBackgroundColor, const Color(0xFFF8FAFC));
      expect(theme.cardColor, const Color(0xFFFFFFFF));
      expect(theme.colorScheme.primary, const Color(0xFF16A34A));
      expect(theme.colorScheme.secondary, const Color(0xFF2563EB));
      expect(theme.colorScheme.error, const Color(0xFFDC2626));
      expect(theme.colorScheme.tertiary, const Color(0xFFD97706));
      expect(theme.colorScheme.onSurface, const Color(0xFF0F172A));
      expect(theme.colorScheme.outline, const Color(0xFFE2E8F0));
    });

    test('uses the approved dark palette', () {
      final theme = AppTheme.darkTheme;

      expect(theme.scaffoldBackgroundColor, const Color(0xFF09090B));
      expect(theme.cardColor, const Color(0xFF18181B));
      expect(theme.colorScheme.surface, const Color(0xFF111827));
      expect(theme.colorScheme.primary, const Color(0xFF22C55E));
      expect(theme.colorScheme.secondary, const Color(0xFF3B82F6));
      expect(theme.colorScheme.error, const Color(0xFFEF4444));
      expect(theme.colorScheme.tertiary, const Color(0xFFFACC15));
      expect(theme.colorScheme.onSurface, const Color(0xFFFFFFFF));
      expect(
        theme.colorScheme.outline,
        const Color.fromRGBO(255, 255, 255, 0.06),
      );
    });
  });
}
