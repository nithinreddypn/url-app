import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/password_validator.dart';

class PasswordValidationChecklist extends StatelessWidget {
  final String password;

  const PasswordValidationChecklist({
    super.key,
    required this.password,
  });

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final state = PasswordValidator.validate(password);

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: state.isValid
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              child: Row(
                children: [
                  Text(
                    '✔ Strong Password',
                    style: TextStyle(
                      color: context.activeAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Password must contain:',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildRuleItem(
                    context,
                    'Minimum 8 characters',
                    !(state.hasMinLength && state.hasMaxLength),
                  ),
                  _buildRuleItem(
                    context,
                    'One uppercase letter',
                    !state.hasUppercase,
                  ),
                  _buildRuleItem(
                    context,
                    'One lowercase letter',
                    !state.hasLowercase,
                  ),
                  _buildRuleItem(
                    context,
                    'One number',
                    !state.hasNumber,
                  ),
                  _buildRuleItem(
                    context,
                    'One special character',
                    !state.hasSpecial,
                  ),
                  _buildRuleItem(
                    context,
                    'No spaces',
                    !state.hasNoSpace,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildRuleItem(BuildContext context, String text, bool isVisible) {
    final bulletColor = context.isDark ? Colors.orange : Colors.deepOrange;

    return AnimatedCrossFade(
      firstChild: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: bulletColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      secondChild: const SizedBox.shrink(),
      crossFadeState: isVisible ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      duration: const Duration(milliseconds: 250),
    );
  }
}
