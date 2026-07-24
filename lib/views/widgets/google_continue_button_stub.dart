import 'package:flutter/material.dart';

import '../../services/google_sign_in_service.dart';

/// Native Google entry point. The platform plugin opens the Google account
/// picker, then [onIdToken] sends the returned token to the URL Defender API.
class GoogleContinueButton extends StatelessWidget {
  const GoogleContinueButton({
    required this.isLoading,
    required this.onIdToken,
    required this.onError,
    super.key,
  });

  final bool isLoading;
  final Future<void> Function(String idToken) onIdToken;
  final void Function(Object error, StackTrace stackTrace) onError;

  Future<void> _continueWithGoogle() async {
    try {
      final idToken = await GoogleSignInService.instance
          .signInOnNativePlatform();
      await onIdToken(idToken);
    } catch (error, stackTrace) {
      onError(error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : _continueWithGoogle,
        icon: const _GoogleMark(),
        label: const Text(
          'Continue with Google',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          backgroundColor: Theme.of(context).colorScheme.surface,
          side: BorderSide(color: Theme.of(context).dividerColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
