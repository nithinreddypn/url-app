DateTime parseStoredDateTime(String value) {
  final hasTimezone =
      value.endsWith('Z') ||
      RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(value) ||
      RegExp(r'[+-]\d{4}$').hasMatch(value);

  if (!hasTimezone) {
    final normalized = value.replaceAll(' ', 'T');
    return DateTime.parse('${normalized}Z').toLocal();
  }

  return DateTime.parse(value).toLocal();
}
