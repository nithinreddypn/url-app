import 'package:flutter/material.dart';
import 'scan_theme.dart';

/// Small colored circle indicating a scan verdict.
class VerdictDot extends StatelessWidget {
  final String? verdict;
  final double size;

  const VerdictDot({super.key, this.verdict, this.size = 10});

  @override
  Widget build(BuildContext context) {
    final colors = ScanTokens.verdictColors(verdict);
    return Semantics(
      label: _semanticLabel,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colors.accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: colors.accent.withOpacity(0.4),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }

  String get _semanticLabel {
    switch (verdict?.toLowerCase()) {
      case 'dangerous':
        return 'Dangerous';
      case 'suspicious':
        return 'Suspicious';
      case 'pending':
        return 'Pending';
      case 'error':
        return 'Error';
      default:
        return 'Safe';
    }
  }
}
