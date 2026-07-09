import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import '../../services/password_validator.dart';
import '../../services/alert_service.dart';
import '../widgets/password_validation_checklist.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final emailVal = _emailController.text.trim();
      final usernameVal = _usernameController.text.trim();
      
      // Perform client-side fake auth
      ref.read(userProvider.notifier).login(emailVal, usernameVal.isNotEmpty ? usernameVal : emailVal.split('@').first);

      if (!mounted) return;

      AlertService.showSuccess(
        context,
        'Account Created',
        'Welcome to URL Defender!',
      );

      context.go('/dashboard');
    } catch (e, stack) {
      _logSupabaseError(e, stack);

      if (!mounted) return;

      AlertService.showError(
        context,
        e,
        customTitle: 'Unable to create account',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
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
        borderSide: BorderSide(color: Color(0xFFEF4444), width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      errorStyle: TextStyle(color: Color(0xFFEF4444), fontSize: 12),
    );
  }

  Widget _buildConfirmPasswordMatchIndicator() {
    final confirmText = _confirmPasswordController.text;
    if (confirmText.isEmpty) return const SizedBox.shrink();

    final matches = confirmText.trim() == _passwordController.text.trim();
    
    // If passwords match but the password is weak, do not show success indicator
    if (matches && PasswordValidator.getErrorMessage(_passwordController.text) != null) {
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
    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Shield Icon with Glow ──
                  AnimatedBuilder(
                    animation: _glowController,
                    builder: (context, child) {
                      return Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: 0.08 + 0.07 * _glowAnimation.value),
                              blurRadius: 18 + 10 * _glowAnimation.value,
                              spreadRadius: 2 * _glowAnimation.value,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(45),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // ── Title ──
                  Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Join the URL Defender community',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: context.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ── Glass Card ──
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: context.isDark ? const Color(0xFF1E1E1E).withValues(alpha: 0.5) : const Color(0xFFFFFFFF).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: context.border.withValues(alpha: 0.6),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // ── Username Field ──
                        TextFormField(
                          controller: _usernameController,
                          onChanged: (val) => setState(() {}),
                          style: TextStyle(
                              color: context.textPrimary, fontSize: 14),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter a username';
                            }
                            if (val.trim().length < 3) {
                              return 'Username must be at least 3 characters';
                            }
                            return null;
                          },
                          decoration: _buildInputDecoration(
                            hint: 'Username',
                            prefixIcon: Icons.person_outline,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Email Field ──
                        TextFormField(
                          controller: _emailController,
                          onChanged: (val) => setState(() {}),
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(
                              color: context.textPrimary, fontSize: 14),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(val.trim())) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                          decoration: _buildInputDecoration(
                            hint: 'Email address',
                            prefixIcon: Icons.email_outlined,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Password Field ──
                        TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          onChanged: (val) => setState(() {}),
                          obscureText: _obscurePassword,
                          style: TextStyle(
                              color: context.textPrimary, fontSize: 14),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter a password';
                            }
                            return null;
                          },
                          decoration: _buildInputDecoration(
                            hint: 'Password',
                            prefixIcon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              icon: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                transitionBuilder: (child, animation) {
                                  return ScaleTransition(
                                    scale: animation,
                                    child: RotationTransition(
                                      turns: animation,
                                      child: child,
                                    ),
                                  );
                                },
                                child: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  key: ValueKey<bool>(_obscurePassword),
                                  color: context.textMuted,
                                  size: 20,
                                ),
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),

                        // ── Password Validation Checklist ──
                        PasswordValidationChecklist(
                          password: _passwordController.text,
                        ),

                        const SizedBox(height: 16),

                        // ── Confirm Password Field ──
                        TextFormField(
                          controller: _confirmPasswordController,
                          onChanged: (val) => setState(() {}),
                          obscureText: _obscureConfirmPassword,
                          style: TextStyle(
                              color: context.textPrimary, fontSize: 14),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (val.trim() !=
                                _passwordController.text.trim()) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                          decoration: _buildInputDecoration(
                            hint: 'Confirm password',
                            prefixIcon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              icon: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                transitionBuilder: (child, animation) {
                                  return ScaleTransition(
                                    scale: animation,
                                    child: RotationTransition(
                                      turns: animation,
                                      child: child,
                                    ),
                                  );
                                },
                                child: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  key: ValueKey<bool>(_obscureConfirmPassword),
                                  color: context.textMuted,
                                  size: 20,
                                ),
                              ),
                              onPressed: () => setState(() =>
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword),
                            ),
                          ),
                        ),

                        // ── Real-Time Confirm Password Match Indicator ──
                        _buildConfirmPasswordMatchIndicator(),

                        const SizedBox(height: 28),

                        // ── Sign Up Button ──
                        Builder(
                          builder: (context) {
                            final bool isFormValid = _usernameController.text.trim().length >= 3 &&
                                RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_emailController.text.trim()) &&
                                PasswordValidator.getErrorMessage(_passwordController.text) == null &&
                                _confirmPasswordController.text.trim() == _passwordController.text.trim() &&
                                _confirmPasswordController.text.isNotEmpty;

                            final isBtnEnabled = isFormValid && !_isLoading;

                            final boxDecoration = isBtnEnabled
                                ? BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        context.activeAccent,
                                        const Color(0xFF3ED65C),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: context.activeAccent.withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  )
                                : BoxDecoration(
                                    color: context.border,
                                    borderRadius: BorderRadius.circular(14),
                                  );

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: double.infinity,
                              height: 54,
                              decoration: boxDecoration,
                              child: ElevatedButton(
                                onPressed: isBtnEnabled ? _handleSignup : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: context.primaryButtonText,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        'Sign Up',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: isBtnEnabled
                                              ? context.primaryButtonText
                                              : context.textMuted,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            );
                          }
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Sign In Link ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Text(
                          'Sign In',
                          style: TextStyle(
                            color: context.activeAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _logSupabaseError(dynamic e, StackTrace stack) {
  debugPrint('Auth Error:');
  final errStr = e.toString();
  if (errStr.contains('AuthException') || errStr.contains('AuthApiException')) {
    debugPrint('Message: $errStr');
  } else if (errStr.contains('PostgrestException')) {
    debugPrint('Message: $errStr');
  } else {
    debugPrint('Message: $errStr');
  }
  debugPrint('Stack Trace:\n$stack');
}


