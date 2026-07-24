import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/app_providers.dart';
import '../../../models/user_model.dart';
import '../../../services/alert_service.dart';

class DeleteAccountDialog extends ConsumerStatefulWidget {
  final UserModel user;

  const DeleteAccountDialog({super.key, required this.user});

  @override
  ConsumerState<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<DeleteAccountDialog> {
  final _confirmController = TextEditingController();
  bool _isValid = false;
  bool _isDeleting = false;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  void _onConfirmTextChanged(String text) {
    setState(() {
      _isValid = text == 'DELETE';
    });
  }

  Future<void> _deleteAccount() async {
    if (!_isValid) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(userProvider.notifier).deleteAccount();
      if (mounted) {
        Navigator.pop(context);
        context.go('/login');
        AlertService.showSuccess(
          context,
          'Account Deleted',
          'Your account has been deleted successfully. We are sorry to see you go.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        AlertService.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputFill = isDark ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFFF1F5F9);
    final redDestructive = Colors.red;

    return AlertDialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: redDestructive, size: 24),
          const SizedBox(width: 12),
          Text(
            'Delete Account?',
            style: TextStyle(
              color: redDestructive,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Warning box: red-tinted background/border
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(color: redDestructive, fontSize: 12, height: 1.4),
                    children: const [
                      TextSpan(text: 'Warning: This action is irreversible. Type '),
                      TextSpan(
                        text: 'DELETE',
                        style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 13),
                      ),
                      TextSpan(text: ' below to confirm.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'This permanently removes your profile, scan history, and activity log. This action cannot be undone.',
                style: TextStyle(color: textSecondary, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 20),

              // Monospace type field
              TextField(
                controller: _confirmController,
                onChanged: _onConfirmTextChanged,
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'DELETE',
                  hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
                  filled: true,
                  fillColor: inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: redDestructive, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: textSecondary)),
        ),
        ElevatedButton(
          onPressed: (_isValid && !_isDeleting) ? _deleteAccount : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: redDestructive,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: _isDeleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Delete account', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
