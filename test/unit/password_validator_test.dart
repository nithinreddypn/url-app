import 'package:flutter_test/flutter_test.dart';
import 'package:url_defender/services/password_validator.dart';

void main() {
  group('PasswordValidator Tests', () {
    test('Valid password should pass validation', () {
      final state = PasswordValidator.validate('Password123!');
      expect(state.isValid, isTrue);
      expect(PasswordValidator.getErrorMessage('Password123!'), isNull);
    });

    test('Short password should fail', () {
      final state = PasswordValidator.validate('Pass1!');
      expect(state.isValid, isFalse);
      expect(state.hasMinLength, isFalse);
      expect(PasswordValidator.getErrorMessage('Pass1!'),
          contains('at least 8 characters'));
    });

    test('Long password > 64 chars should fail', () {
      final longPassword = 'P' * 65 + '1!';
      final state = PasswordValidator.validate(longPassword);
      expect(state.isValid, isFalse);
      expect(state.hasMaxLength, isFalse);
      expect(PasswordValidator.getErrorMessage(longPassword),
          contains('at most 64 characters'));
    });

    test('Missing uppercase letter should fail', () {
      final state = PasswordValidator.validate('password123!');
      expect(state.isValid, isFalse);
      expect(state.hasUppercase, isFalse);
      expect(PasswordValidator.getErrorMessage('password123!'),
          contains('one uppercase letter'));
    });

    test('Missing lowercase letter should fail', () {
      final state = PasswordValidator.validate('PASSWORD123!');
      expect(state.isValid, isFalse);
      expect(state.hasLowercase, isFalse);
      expect(PasswordValidator.getErrorMessage('PASSWORD123!'),
          contains('one lowercase letter'));
    });

    test('Missing number should fail', () {
      final state = PasswordValidator.validate('Password!!!');
      expect(state.isValid, isFalse);
      expect(state.hasNumber, isFalse);
      expect(PasswordValidator.getErrorMessage('Password!!!'),
          contains('one number'));
    });

    test('Missing special character should fail', () {
      final state = PasswordValidator.validate('Password123');
      expect(state.isValid, isFalse);
      expect(state.hasSpecial, isFalse);
      expect(PasswordValidator.getErrorMessage('Password123'),
          contains('one special character'));
    });

    test('Password containing spaces should fail', () {
      final state = PasswordValidator.validate('Password 123!');
      expect(state.isValid, isFalse);
      expect(state.hasNoSpace, isFalse);
      expect(PasswordValidator.getErrorMessage('Password 123!'),
          contains('must not contain spaces'));
    });

    test('Trimming whitespace before validation', () {
      // The validator should trim leading/trailing whitespace
      // "  Password123!  " should become "Password123!" and be valid.
      final state = PasswordValidator.validate('  Password123!  ');
      expect(state.isValid, isTrue);
      expect(PasswordValidator.getErrorMessage('  Password123!  '), isNull);
    });

    group('Strength Score Tests', () {
      test('Empty password should be 0', () {
        expect(PasswordValidator.getStrengthScore(''), equals(0));
      });

      test('Space inside should be 0', () {
        expect(PasswordValidator.getStrengthScore('Password 123!'), equals(0));
      });

      test('Weak password (only 1 criteria met) -> 1', () {
        // met: lowercase
        expect(PasswordValidator.getStrengthScore('aaaaaaab'), equals(1));
        expect(PasswordValidator.getStrengthScore('password'), equals(1));
      });

      test('Medium password (2 complexity criteria met) -> 2', () {
        // met: lowercase, numbers
        expect(PasswordValidator.getStrengthScore('password123'), equals(2));
      });

      test('Strong password (3 complexity criteria met) -> 3', () {
        // met: lowercase, uppercase, numbers
        expect(PasswordValidator.getStrengthScore('Password123'), equals(3));
      });

      test('Very Strong password (all 4 complexity criteria met) -> 4', () {
        // met: lowercase, uppercase, numbers, special
        expect(PasswordValidator.getStrengthScore('Password123!'), equals(4));
      });
    });
  });
}
