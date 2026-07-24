import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

InputDecoration buildAuthInputDecoration(
  BuildContext context, {
  required String hint,
  required IconData prefixIcon,
  Widget? suffixIcon,
}) {
  const errorColor = Color(0xFFEF4444);

  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      color: context.textMuted,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    ),
    prefixIcon: Icon(prefixIcon, color: context.textMuted, size: 20),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: context.inputBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: context.border, width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: context.border, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: context.activeAccent, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: errorColor, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: errorColor, width: 1.5),
    ),
    errorStyle: const TextStyle(color: errorColor, fontSize: 12),
  );
}
