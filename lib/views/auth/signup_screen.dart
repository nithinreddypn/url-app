import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:go_router/go_router.dart';
import '../../services/api_client.dart';
import '../../services/password_validator.dart';
import '../../services/alert_service.dart';
import '../../services/auth_service.dart';
import '../../services/login_error_handler.dart';
import '../../providers/app_providers.dart';
import 'auth_widgets.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _acceptTerms = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final emailVal = _emailController.text.trim();
      final usernameVal = _usernameController.text.trim();

      await _authService.signUp(
        email: emailVal,
        password: _passwordController.text,
        username: usernameVal,
      );

      if (!mounted) return;

      AlertService.showSuccess(
        context,
        'Verification Required',
        'Enter the verification code sent to your email.',
      );

      context.go('/verify-email?email=${Uri.encodeComponent(emailVal)}');
    } catch (e, stack) {
      _logAuthError(e, stack);

      if (!mounted) return;

      if (e is ApiException && e.kind == ApiFailureKind.conflict) {
        AlertService.showAlert(
          context,
          type: AlertType.warning,
          title: 'Account Already Exists',
          description: 'This email is already registered. Sign in to continue.',
          actionLabel: 'Sign In',
          onAction: () => context.go('/auth_gate'),
        );
        return;
      }

      AlertService.showError(
        context,
        e,
        customTitle: 'Unable to create account',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn(String idToken) async {
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    setState(() => _isGoogleLoading = true);

    try {
      final session = await _authService.signInWithGoogle(idToken: idToken);
      await ref.read(userProvider.notifier).loginWithSession(session);
      if (!mounted) return;
      context.go('/main');
    } catch (error, stackTrace) {
      if (!mounted) return;
      if (error is GoogleVerificationPendingException) {
        AlertService.showAlert(
          context,
          type: AlertType.success,
          title: 'Verification Link Sent',
          description: error.message,
        );
        return;
      }
      final safe = LoginErrorHandler.fromGoogleException(error, stackTrace);
      AlertService.showAlert(
        context,
        type: AlertType.error,
        title: safe.title,
        description: safe.description,
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  void _handleGoogleSignInError(Object error, StackTrace stackTrace) {
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    if (error is GoogleVerificationPendingException) {
      AlertService.showAlert(
        context,
        type: AlertType.success,
        title: 'Verification Link Sent',
        description: error.message,
      );
      return;
    }
    final safe = LoginErrorHandler.fromGoogleException(error, stackTrace);
    AlertService.showAlert(
      context,
      type: AlertType.error,
      title: safe.title,
      description: safe.description,
    );
  }

  Widget _buildConfirmPasswordMatchIndicator() {
    final confirmText = _confirmPasswordController.text;
    if (confirmText.isEmpty) return const SizedBox.shrink();

    final matches = confirmText.trim() == _passwordController.text.trim();

    // If passwords match but the password is weak, do not show success indicator
    if (matches &&
        PasswordValidator.getErrorMessage(_passwordController.text) != null) {
      return const SizedBox.shrink();
    }

    final color = matches ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final text = matches ? '✓ Passwords match' : '✗ Passwords do not match';

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? Colors.white.withOpacity(0.06)
        : const Color(0xFFE2E8F0);
    final textSec = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    final accentGreen = isDark
        ? const Color(0xFF22C55E)
        : const Color(0xFF16A34A);

    final String passwordText = _passwordController.text;
    final int strengthScore = PasswordValidator.getStrengthScore(passwordText);
    final String strengthLabel = passwordText.trim().isEmpty
        ? 'Very Weak'
        : (strengthScore == 1
              ? 'Weak'
              : (strengthScore == 2
                    ? 'Medium'
                    : (strengthScore == 3 ? 'Strong' : 'Excellent')));

    return AuthScaffold(
      topSection: const SectionTitle(
        title: 'Create Your Account',
        subtitle:
            'Start protecting your links with intelligent threat detection.',
        trustIndicatorText: '🔒 Secure Authentication',
      ),
      child: AuthCard(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Google Sign-up Button
              GoogleButton(
                isLoading: _isGoogleLoading,
                onGoogleIdToken: _handleGoogleSignIn,
                onGoogleError: _handleGoogleSignInError,
              ),
              const SizedBox(height: 24),

              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: dividerColor)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or sign up with email',
                      style: TextStyle(
                        color: textSec,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: dividerColor)),
                ],
              ),
              const SizedBox(height: 24),

              // Full Name field
              CustomTextField(
                controller: _usernameController,
                labelText: 'Full Name',
                hintText: 'Alex Morgan',
                prefixIcon: Icons.person_outline_rounded,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your full name';
                  }
                  if (val.trim().length < 3) {
                    return 'Name must be at least 3 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Email Address field
              CustomTextField(
                controller: _emailController,
                labelText: 'Email Address',
                hintText: 'you@company.com',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(
                    r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(val.trim())) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Password field
              PasswordField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                labelText: 'Password',
                hintText: 'At least 8 characters',
                onChanged: (_) => setState(() {}),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your password';
                  }
                  final err = PasswordValidator.getErrorMessage(val);
                  if (err != null) return err;
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Password strength meter
              PasswordStrengthIndicator(
                strength: passwordText.trim().isEmpty ? 0 : strengthScore,
                label: strengthLabel,
              ),
              const SizedBox(height: 20),

              // Confirm Password field
              PasswordField(
                controller: _confirmPasswordController,
                labelText: 'Confirm Password',
                hintText: 'Type it again',
                onChanged: (_) => setState(() {}),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (val.trim() != _passwordController.text.trim()) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),

              // Confirm password match indicator
              _buildConfirmPasswordMatchIndicator(),
              const SizedBox(height: 20),

              // Terms & Privacy Policy Checkbox
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _acceptTerms,
                      onChanged: (val) {
                        setState(() {
                          _acceptTerms = val ?? false;
                        });
                      },
                      activeColor: accentGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      side: BorderSide(color: dividerColor),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'I agree to the ',
                        style: TextStyle(
                          color: textSec,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        children: [
                          TextSpan(
                            text: 'Terms',
                            style: TextStyle(
                              color: accentGreen,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color: accentGreen,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Create Account Button
              Builder(
                builder: (context) {
                  final bool isFormValid =
                      _usernameController.text.trim().length >= 3 &&
                      RegExp(
                        r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(_emailController.text.trim()) &&
                      PasswordValidator.getErrorMessage(
                            _passwordController.text,
                          ) ==
                          null &&
                      _confirmPasswordController.text.trim() ==
                          _passwordController.text.trim() &&
                      _confirmPasswordController.text.isNotEmpty &&
                      _acceptTerms;

                  final isBtnEnabled = isFormValid && !_isLoading;

                  return PrimaryButton(
                    text: 'Create Account',
                    onPressed: isBtnEnabled ? _handleSignup : null,
                    isLoading: _isLoading,
                  );
                },
              ),
              const SizedBox(height: 24),

              // Footer
              Center(
                child: AuthFooter(
                  text: 'Already have an account? ',
                  actionText: 'Sign In',
                  onTap: () => context.go('/auth_gate'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _logAuthError(dynamic e, StackTrace stack) {
  if (!kDebugMode) return;
  debugPrint('Auth Error:');
  final errStr = e.toString();
  if (errStr.contains('AuthException') || errStr.contains('AuthApiException')) {
    debugPrint('Message: $errStr');
  } else {
    debugPrint('Message: $errStr');
  }
  debugPrint('Stack Trace:\n$stack');
}
