class PasswordValidationState {
  final bool hasMinLength;
  final bool hasMaxLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumber;
  final bool hasSpecial;
  final bool hasNoSpace;

  PasswordValidationState({
    required this.hasMinLength,
    required this.hasMaxLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumber,
    required this.hasSpecial,
    required this.hasNoSpace,
  });

  bool get isValid =>
      hasMinLength &&
      hasMaxLength &&
      hasUppercase &&
      hasLowercase &&
      hasNumber &&
      hasSpecial &&
      hasNoSpace;
}

class PasswordValidator {
  static const String specialChars = r'!@#\$%\^&\*\(\)_\+\-=\[\]\{\}\|;:,\.<>\?\/';

  /// Validates a password and returns a state object with the status of each rule.
  static PasswordValidationState validate(String password) {
    // Trim leading/trailing whitespace before validation as per security requirements
    final trimmed = password.trim();

    final hasMinLength = trimmed.length >= 8;
    final hasMaxLength = trimmed.length <= 64;
    final hasUppercase = trimmed.contains(RegExp(r'[A-Z]'));
    final hasLowercase = trimmed.contains(RegExp(r'[a-z]'));
    final hasNumber = trimmed.contains(RegExp(r'[0-9]'));
    final hasSpecial = trimmed.contains(RegExp('[$specialChars]'));
    final hasNoSpace = !trimmed.contains(' '); // Spaces check is on the trimmed password

    return PasswordValidationState(
      hasMinLength: hasMinLength,
      hasMaxLength: hasMaxLength,
      hasUppercase: hasUppercase,
      hasLowercase: hasLowercase,
      hasNumber: hasNumber,
      hasSpecial: hasSpecial,
      hasNoSpace: hasNoSpace,
    );
  }

  /// Calculates the strength score (1 to 4) of a password.
  static int getStrengthScore(String password) {
    final trimmed = password.trim();
    if (trimmed.isEmpty) return 0;

    final state = validate(password);
    if (!state.hasNoSpace) return 0; // Invalid if it contains spaces after trimming

    // If it's less than 8 characters, it is always Weak (1)
    if (trimmed.length < 8) return 1;

    int complexityCount = 0;
    if (state.hasUppercase) complexityCount++;
    if (state.hasLowercase) complexityCount++;
    if (state.hasNumber) complexityCount++;
    if (state.hasSpecial) complexityCount++;

    if (complexityCount <= 1) {
      return 1; // Weak
    } else if (complexityCount == 2) {
      return 2; // Medium
    } else if (complexityCount == 3) {
      return 3; // Strong
    } else {
      return 4; // Very Strong (complexityCount == 4)
    }
  }

  /// Returns the first validation error message, or null if all rules are satisfied.
  static String? getErrorMessage(String password) {
    final trimmed = password.trim();
    
    if (trimmed.contains(' ')) {
      return 'Password must not contain spaces.';
    }

    final state = validate(password);

    if (!state.hasMinLength) {
      return 'Password must contain at least 8 characters.';
    }
    if (!state.hasMaxLength) {
      return 'Password must be at most 64 characters.';
    }
    if (!state.hasUppercase) {
      return 'Password must include one uppercase letter.';
    }
    if (!state.hasLowercase) {
      return 'Password must include one lowercase letter.';
    }
    if (!state.hasNumber) {
      return 'Password must include one number.';
    }
    if (!state.hasSpecial) {
      return 'Password must include one special character.';
    }

    return null;
  }
}
