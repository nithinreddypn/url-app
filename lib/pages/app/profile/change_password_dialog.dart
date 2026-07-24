import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/app_providers.dart';
import '../../../services/password_validator.dart';
import '../../../services/alert_service.dart';

class ChangePasswordDialog extends ConsumerStatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  ConsumerState<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isUpdating = false;
  int _strengthScore = 0;
  String? _strengthLabel;
  Color _strengthColor = Colors.grey;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged(String val) {
    final score = PasswordValidator.getStrengthScore(val);
    String label;
    Color color;

    switch (score) {
      case 0:
        label = 'Too Weak';
        color = Colors.grey;
        break;
      case 1:
        label = 'Weak';
        color = Colors.red;
        break;
      case 2:
        label = 'Fair';
        color = Colors.amber;
        break;
      case 3:
        label = 'Strong';
        color = Colors.green;
        break;
      case 4:
        label = 'Very Strong';
        color = const Color(0xFF10B981);
        break;
      default:
        label = 'Weak';
        color = Colors.grey;
    }

    setState(() {
      _strengthScore = score;
      _strengthLabel = label;
      _strengthColor = color;
    });
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_strengthScore < 3) {
      AlertService.showWarning(context, 'Weak Password', 'Please choose a stronger password.');
      return;
    }

    setState(() => _isUpdating = true);
    try {
      final currentPwd = _currentPasswordController.text;
      final newPwd = _newPasswordController.text;

      final authService = ref.read(authServiceProvider);
      await authService.changePassword(
        currentPassword: currentPwd,
        newPassword: newPwd,
      );

      if (mounted) {
        Navigator.pop(context);
        AlertService.showSuccess(
          context,
          'Password Updated',
          'Your password has been changed successfully.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        AlertService.showError(context, e);
      }
    }
  }

  Widget _buildStrengthSegment(int index) {
    final filled = _strengthScore >= index;
    return Expanded(
      child: Container(
        height: 4,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: filled ? _strengthColor : Colors.grey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputFill = isDark ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFFF1F5F9);
    final primaryBlue = const Color(0xFF3B82F6);

    return AlertDialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.key_rounded, color: primaryBlue, size: 24),
          const SizedBox(width: 12),
          Text(
            'Change Password',
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Update your account security password.',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 20),

                // Current Password
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: true,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Current password',
                    labelStyle: TextStyle(color: textSecondary),
                    prefixIcon: Icon(Icons.lock_open_rounded, color: textSecondary, size: 18),
                    filled: true,
                    fillColor: inputFill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your current password.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // New Password
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: true,
                  style: TextStyle(color: textPrimary),
                  onChanged: _onPasswordChanged,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    labelStyle: TextStyle(color: textSecondary),
                    prefixIcon: Icon(Icons.lock_outline_rounded, color: textSecondary, size: 18),
                    filled: true,
                    fillColor: inputFill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 8) {
                      return 'Password must be at least 8 characters.';
                    }
                    return null;
                  },
                ),
                
                // Strength indicator segment bar
                if (_newPasswordController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStrengthSegment(1),
                      _buildStrengthSegment(2),
                      _buildStrengthSegment(3),
                      _buildStrengthSegment(4),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _strengthLabel ?? '',
                        style: TextStyle(
                          color: _strengthColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),

                // Confirm Password
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Confirm new password',
                    labelStyle: TextStyle(color: textSecondary),
                    prefixIcon: Icon(Icons.lock_rounded, color: textSecondary, size: 18),
                    filled: true,
                    fillColor: inputFill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value != _newPasswordController.text) {
                      return 'Passwords do not match.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUpdating ? null : () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: textSecondary)),
        ),
        ElevatedButton(
          onPressed: _isUpdating ? null : _updatePassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: _isUpdating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Update password', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
