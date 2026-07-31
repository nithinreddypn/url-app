import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../services/alert_service.dart';
import '../../services/login_error_handler.dart';
import '../../providers/app_providers.dart';
import 'auth_widgets.dart';
import '../../services/api_client.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _rememberMe = false;
  LoginUiError? _loginError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _loginError = null;
    });

    try {
      final session = await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await ref.read(userProvider.notifier).loginWithSession(session);

      if (!mounted) return;

      context.go('/main');
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _loginError = LoginErrorHandler.fromException(error, stackTrace);
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn(String idToken) async {
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    setState(() {
      _isGoogleLoading = true;
      _loginError = null;
    });

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
      setState(() {
        _loginError = LoginErrorHandler.fromGoogleException(error, stackTrace);
      });
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
    setState(() {
      _loginError = LoginErrorHandler.fromGoogleException(error, stackTrace);
    });
  }

  void _handleLoginErrorAction(LoginErrorAction action) {
    switch (action) {
      case LoginErrorAction.retry:
        _handleLogin();
        return;
      case LoginErrorAction.reviewCredentials:
        setState(() => _loginError = null);
        _passwordFocusNode.requestFocus();
        return;
      case LoginErrorAction.createAccount:
        context.go('/signup');
        return;
      case LoginErrorAction.verifyEmail:
        context.push(
          '/verify-email?email=${Uri.encodeComponent(_emailController.text.trim())}',
        );
        return;
      case LoginErrorAction.dismiss:
        setState(() => _loginError = null);
        return;
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.lock_reset, color: context.activeAccent, size: 24),
            SizedBox(width: 10),
            Text(
              'Reset Password',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
              style: TextStyle(color: context.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: resetEmailController,
              style: TextStyle(color: context.textPrimary),
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Email address',
                hintStyle: TextStyle(color: context.textMuted),
                prefixIcon: Icon(
                  Icons.email_outlined,
                  color: context.textMuted,
                ),
                filled: true,
                fillColor: context.inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.activeAccent),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isEmpty) return;
              try {
                await _authService.resetPassword(email);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                AlertService.showSuccess(
                  context,
                  'Password Reset Sent',
                  'A password reset link has been sent to your email address.',
                );
              } catch (e) {
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                AlertService.showError(
                  context,
                  e,
                  customTitle: 'Unable to reset password',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.activeAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Send Link',
              style: TextStyle(color: context.primaryButtonText),
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

    return AuthScaffold(
      topSection: const SectionTitle(
        title: 'Welcome Back',
        subtitle: 'Sign in to continue protecting your links.',
        trustIndicatorText: '🛡 Privacy First',
      ),
      child: AuthCard(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Login error display
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) => SizeTransition(
                  sizeFactor: animation,
                  alignment: Alignment.topCenter,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: _loginError == null
                    ? const SizedBox(key: ValueKey('no-login-error'))
                    : Padding(
                        key: const ValueKey('login-error'),
                        padding: const EdgeInsets.only(bottom: 20),
                        child: ValidationMessage(
                          text:
                              '${_loginError!.title}: ${_loginError!.description}',
                          actionLabel: _loginError!.actionLabel,
                          onRetry: () =>
                              _handleLoginErrorAction(_loginError!.action),
                          isRetrying: _isLoading,
                        ),
                      ),
              ),

              // Google Sign-in Button
              GoogleButton(
                isLoading: _isGoogleLoading,
                onGoogleIdToken: _handleGoogleSignIn,
                onGoogleError: _handleGoogleSignInError,
              ),
              const SizedBox(height: 24),

              // Divider "or continue with email"
              Row(
                children: [
                  Expanded(child: Divider(color: dividerColor)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or continue with email',
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

              // Email Field
              CustomTextField(
                controller: _emailController,
                labelText: 'Email address',
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

              // Password Field
              PasswordField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                labelText: 'Password',
                hintText: 'Your password',
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your password';
                  }
                  if (val.trim().length < 8) {
                    return 'Password must be at least 8 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),

              // Remember Me & Forgot Password
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: (val) {
                        setState(() {
                          _rememberMe = val ?? false;
                        });
                      },
                      activeColor: accentGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      side: BorderSide(color: dividerColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _rememberMe = !_rememberMe;
                      });
                    },
                    child: Text(
                      'Remember me',
                      style: TextStyle(
                        color: textSec,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _showForgotPasswordDialog,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: accentGreen,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Sign In Button
              PrimaryButton(
                text: 'Sign In',
                onPressed: _handleLogin,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 24),

              // Footer
              Center(
                child: AuthFooter(
                  text: "New to URL Defender? ",
                  actionText: "Create Account",
                  onTap: () => context.go('/signup'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'API: ${ApiClient.baseUrl}',
                  style: TextStyle(color: textSec.withOpacity(0.5), fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
