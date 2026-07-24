import 'dart:convert';

import 'date_time_parser.dart';

/// Normalizes values returned by PHP/MySQL before they reach application
/// models. MySQL drivers may serialize numbers and booleans as strings, so
/// model factories should not rely on runtime casts for API values.
String apiString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  return value.toString();
}

String? apiNullableString(dynamic value) {
  if (value == null) return null;
  final normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

int apiInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double apiDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

bool apiBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  switch (value?.toString().trim().toLowerCase()) {
    case '1':
    case 'true':
    case 'yes':
    case 'on':
      return true;
    case '0':
    case 'false':
    case 'no':
    case 'off':
      return false;
    default:
      return fallback;
  }
}

DateTime? apiDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final normalized = value.toString().trim();
  if (normalized.isEmpty) return null;
  try {
    return parseStoredDateTime(normalized);
  } on FormatException {
    return null;
  }
}

List<String> apiStringList(dynamic value) {
  dynamic normalized = value;
  if (normalized is String && normalized.trim().isNotEmpty) {
    try {
      normalized = jsonDecode(normalized);
    } on FormatException {
      return const [];
    }
  }
  if (normalized is! Iterable) return const [];
  return normalized
      .where((item) => item != null)
      .map((item) => item.toString())
      .toList(growable: false);
}

Map<String, dynamic>? apiMap(dynamic value) {
  if (value is! Map) return null;
  return Map<String, dynamic>.from(value);
}
