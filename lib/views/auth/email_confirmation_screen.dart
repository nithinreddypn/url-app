import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../services/alert_service.dart';
import '../../services/exception_mapper.dart';
import '../../services/supabase_config.dart';
import '../../services/user_service.dart';

class EmailConfirmationScreen extends ConsumerStatefulWidget {
  final String email;
  final String? username;

  const EmailConfirmationScreen({
    super.key,
    required this.email,
    this.username,
  });

  @override
  ConsumerState<EmailConfirmationScreen> createState() => _EmailConfirmationScreenState();
}

class _EmailConfirmationScreenState extends ConsumerState<EmailConfirmationScreen>
    with SingleTickerProviderStateMixin {
  Timer? _pollingTimer;
  bool _isChecking = false;
  bool _isResending = false;

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

    // Start polling automatically every 3 seconds to check confirmation state
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkVerificationStatus(isManual: false);
    });
  }

  Future<void> _checkVerificationStatus({required bool isManual}) async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    try {
      final session = SupabaseConfig.client.auth.currentSession;

      // If there is no active session on the client, check the public DB
      if (session == null) {
        final profile = await UserService().getUserByEmail(widget.email);
        if (profile != null) {
          _pollingTimer?.cancel();
          if (!mounted) return;

          AlertService.showSuccess(
            context,
            'Email Verified',
            'Your email has been verified! Please go back to the login screen and sign in.',
          );
          context.go('/login');
          return;
        }

        if (isManual && mounted) {
          AlertService.showAlert(
            context,
            type: AlertType.info,
            title: 'Not Verified Yet',
            description: 'We haven\'t received confirmation yet. Please open the email and click the confirmation link to activate your account.',
          );
        }
        return;
      }

      // If a session exists, retrieve fresh user state from Supabase server safely
      final response = await SupabaseConfig.client.auth.getUser();
      final user = response.user;

      if (user != null && user.emailConfirmedAt != null) {
        _pollingTimer?.cancel();
        
        // Clear pending signup states
        ref.read(pendingSignupProvider.notifier).clear();

        // Invalidate cache and user providers
        ref.invalidate(userProvider);
        ref.invalidate(blockedUrlsProvider);
        ref.invalidate(scanLimitProvider);
        ref.invalidate(subscriptionProvider);

        // Force a refresh of the user StateNotifier
        await ref.read(userProvider.notifier).refreshUser();

        if (!mounted) return;

        AlertService.showSuccess(
          context,
          'Account Activated',
          'Your email has been verified. Welcome to URL Defender!',
        );

        context.go('/dashboard');
        return;
      }

      if (isManual && mounted) {
        AlertService.showAlert(
          context,
          type: AlertType.info,
          title: 'Not Verified Yet',
          description: 'We haven\'t received confirmation yet. Please open the email and click the confirmation link to activate your account.',
        );
      }
    } catch (e) {
      if (isManual && mounted) {
        final mappedException = ExceptionMapper.map(e);
        AlertService.showAlert(
          context,
          type: AlertType.error,
          title: 'Check Failed',
          description: mappedException.description,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _openMailApp() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
    );
    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
        if (!mounted) return;
        AlertService.showAlert(
          context,
          type: AlertType.info,
          title: 'Open Email',
          description: 'Please check your preferred email client manually.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      AlertService.showAlert(
        context,
        type: AlertType.info,
        title: 'Open Email',
        description: 'Please check your preferred email client manually.',
      );
    }
  }

  Future<void> _resendEmail() async {
    final cooldown = ref.read(cooldownTimerProvider);
    if (cooldown > 0 || _isResending) return;

    setState(() => _isResending = true);

    try {
      // 1. Check if user already exists in the public users table (indicates they are already verified)
      try {
        final profile = await UserService().getUserByEmail(widget.email);
        if (profile != null) {
          if (!mounted) return;
          AlertService.showSuccess(
            context,
            'Already Verified',
            'Your email has already been verified.',
          );
          return;
        }
      } catch (dbError) {
        assert(() {
          debugPrint('Checked profile by email failed: $dbError');
          return true;
        }());
      }

      // 2. Trigger resend
      await SupabaseConfig.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );

      ref.read(cooldownTimerProvider.notifier).start();

      if (!mounted) return;

      AlertService.showSuccess(
        context,
        'Confirmation Sent',
        'A new verification email has been sent.',
      );
    } catch (e) {
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('already confirmed') || errorMsg.contains('already verified')) {
        if (!mounted) return;
        AlertService.showSuccess(
          context,
          'Already Verified',
          'Your email has already been verified.',
        );
        return;
      }

      assert(() {
        debugPrint('Resend verification email failed: $e');
        return true;
      }());

      if (!mounted) return;

      final mappedException = ExceptionMapper.map(e);
      AlertService.showAlert(
        context,
        type: AlertType.error,
        title: 'Resend Failed',
        description: mappedException.description,
      );
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _backToLogin() {
    ref.read(pendingSignupProvider.notifier).clear();
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final cooldownSeconds = ref.watch(cooldownTimerProvider);

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Animated Logo ──
                AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, child) {
                    return Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: 0.08 + 0.07 * _glowAnimation.value),
                            blurRadius: 20 + 10 * _glowAnimation.value,
                            spreadRadius: 2 * _glowAnimation.value,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(50),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // ── Screen Title ──
                Text(
                  'Verify Your Email',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                
                // ── Text Explainer ──
                Text(
                  'We\'ve sent a confirmation email to:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.email,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.activeAccent,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Please open the email and click the verification link to activate your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 40),

                // ── Open Email App Button ──
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _openMailApp,
                    icon: const Icon(Icons.mail_outline),
                    label: const Text(
                      'Open Email App',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.activeAccent,
                      foregroundColor: context.primaryButtonText,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── I've Verified My Email Button ──
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _isChecking ? null : () => _checkVerificationStatus(isManual: true),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.activeAccent, width: 1.5),
                      foregroundColor: context.activeAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isChecking
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.activeAccent,
                            ),
                          )
                        : const Text(
                            'I\'ve Verified My Email',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Resend & Back Actions ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _backToLogin,
                      child: Text(
                        'Back to Login',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    cooldownSeconds > 0
                        ? Text(
                            'Resend in ${cooldownSeconds}s',
                            style: TextStyle(
                              fontSize: 14,
                              color: context.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : TextButton(
                            onPressed: _isResending ? null : _resendEmail,
                            child: Text(
                              'Resend Email',
                              style: TextStyle(
                                fontSize: 14,
                                color: context.activeAccent,
                                fontWeight: FontWeight.bold,
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
    );
  }
}
