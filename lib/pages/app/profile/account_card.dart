import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/app_providers.dart';
import '../../../models/user_model.dart';
import 'edit_profile_dialog.dart';
import 'change_password_dialog.dart';
import 'delete_account_dialog.dart';

class AccountCard extends ConsumerWidget {
  final UserModel user;

  const AccountCard({super.key, required this.user});

  void _showEditProfile(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EditProfileDialog(user: user),
    );
  }

  void _showChangePassword(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const ChangePasswordDialog(),
    );
  }

  void _showDeleteAccount(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DeleteAccountDialog(user: user),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final hoverColor = isDark ? const Color(0xFF334155).withOpacity(0.4) : const Color(0xFFF1F5F9);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Account Management',
            style: TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // 1. Edit Profile Row
          AccountActionRow(
            icon: Icons.edit_outlined,
            title: 'Edit profile',
            description: 'Name, email, company',
            hoverColor: hoverColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onTap: () => _showEditProfile(context),
          ),
          const SizedBox(height: 8),

          // 2. Change Password Row
          AccountActionRow(
            icon: Icons.key_rounded,
            title: 'Change password',
            description: 'Update your sign-in password',
            hoverColor: hoverColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onTap: () => _showChangePassword(context),
          ),
          const SizedBox(height: 8),

          // 3. Enable MFA Row
          AccountActionRow(
            icon: Icons.shield_outlined,
            title: 'Enable MFA',
            description: 'Add a second factor',
            hoverColor: hoverColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onTap: () {
              ref.read(tabIndexProvider.notifier).state = 3; // Settings tab
              ref.read(settingsSectionProvider.notifier).state = 3; // Security sub-tab
              // Close profile page to show MainScreen (which has the updated tabs)
              context.pop();
            },
          ),
          const SizedBox(height: 8),

          // 4. Log out Row
          AccountActionRow(
            icon: Icons.logout_rounded,
            title: 'Log out',
            description: 'End this session',
            hoverColor: hoverColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: surfaceColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Text('Sign Out?', style: TextStyle(color: textPrimary)),
                  content: Text('Are you sure you want to end your current login session?', style: TextStyle(color: textSecondary)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: textSecondary))),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                ref.read(userProvider.notifier).logout();
                if (context.mounted) {
                  context.go('/login');
                }
              }
            },
          ),
          const SizedBox(height: 8),

          // 5. Delete Account Row (Destructive red)
          AccountActionRow(
            icon: Icons.delete_forever_rounded,
            title: 'Delete account',
            description: 'Irreversible — removes all data',
            hoverColor: Colors.red.withOpacity(0.08),
            textPrimary: Colors.red,
            textSecondary: Colors.red.withOpacity(0.7),
            isDestructive: true,
            onTap: () => _showDeleteAccount(context),
          ),
        ],
      ),
    );
  }
}

class AccountActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color hoverColor;
  final Color textPrimary;
  final Color textSecondary;
  final bool isDestructive;
  final VoidCallback onTap;

  const AccountActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.hoverColor,
    required this.textPrimary,
    required this.textSecondary,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: hoverColor,
        splashColor: hoverColor,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.transparent),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive ? Colors.red : textPrimary.withOpacity(0.8),
                size: 20,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDestructive ? Colors.red.withOpacity(0.5) : textSecondary.withOpacity(0.5),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
