import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/alert_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'auth_widgets.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _codeController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      AlertService.showWarning(
        context,
        'Invalid Code',
        'Enter the six-digit verification code.',
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await _authService.verifyEmail(email: widget.email, code: code);
      if (!mounted) return;
      AlertService.showSuccess(
        context,
        'Email Verified',
        'You can now sign in.',
      );
      context.go('/login');
    } catch (error) {
      if (mounted) {
        AlertService.showError(
          context,
          error,
          actionLabel: 'Resend Code',
          onAction: _resend,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      await _authService.resendVerification(widget.email);
      if (mounted) {
        AlertService.showSuccess(
          context,
          'Code Sent',
          'A new verification code has been sent.',
        );
      }
    } catch (error) {
      if (mounted) AlertService.showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    topSection: Column(
      children: [
        Icon(
          Icons.mark_email_read_outlined,
          size: 52,
          color: context.activeAccent,
        ),
        const SizedBox(height: 18),
        Text(
          'Verify your email',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the code sent to ${widget.email}',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.textSecondary),
        ),
      ],
    ),
    child: AuthCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            autofillHints: const [AutofillHints.oneTimeCode],
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 22,
              letterSpacing: 12,
            ),
            decoration: const InputDecoration(
              counterText: '',
              hintText: '000000',
              suffixText: '\u200e', // LTR mark to balance trailing letter spacing
              suffixStyle: TextStyle(fontSize: 22, letterSpacing: 12),
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
            onSubmitted: (_) {
              if (!_loading) _verify();
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _verify,
              child: Text(_loading ? 'Verifying...' : 'Verify Email'),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _loading ? null : _resend,
            child: const Text('Resend code'),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Wrong email?',
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: _loading ? null : () => context.go('/login'),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Back to Sign In',
                  style: TextStyle(
                    color: context.activeAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
