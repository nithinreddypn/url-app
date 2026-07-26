import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../providers/app_providers.dart';
import '../../../models/user_model.dart';
import '../../../services/alert_service.dart';

class ProfileHeader extends ConsumerWidget {
  final UserModel user;

  const ProfileHeader({super.key, required this.user});

  String _formatMemberSince(DateTime? date) {
    if (date == null) return 'JULY 2026';
    final months = [
      'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'UD';
    if (parts.length == 1) {
      final s = parts[0];
      return s.substring(0, s.length >= 2 ? 2 : 1).toUpperCase();
    }
    final first = parts[0][0];
    final second = parts[1][0];
    return (first + second).toUpperCase();
  }

  Future<void> _pickAndUploadImage(BuildContext context, WidgetRef ref) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      // Check size limit: 1 MB = 1,048,576 bytes
      final bytes = await image.readAsBytes();
      if (bytes.lengthInBytes > 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image too large — keep it under 1 MB'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await ref.read(userProvider.notifier).uploadAvatar(image);
      AlertService.showSuccess(context, 'Avatar Updated', 'Your profile picture has been updated.');
    } catch (e) {
      AlertService.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final primaryGreen = const Color(0xFF10B981);
    final primaryBlue = const Color(0xFF3B82F6);

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 640;

    final hasAvatar = user.avatarUrl != null && user.avatarUrl!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Stack(
        children: [
          // Remove button (top-right of header section)
          if (hasAvatar)
            Positioned(
              top: 0,
              right: 0,
              child: TextButton.icon(
                onPressed: () async {
                  try {
                    await ref.read(userProvider.notifier).removeAvatar();
                    AlertService.showSuccess(context, 'Avatar Removed', 'Your profile picture has been removed.');
                  } catch (e) {
                    AlertService.showError(context, e);
                  }
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                label: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ),
          
          Flex(
            direction: isMobile ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with camera edit button
              Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [primaryGreen, primaryBlue],
                      ),
                    ),
                    child: hasAvatar
                        ? ClipOval(
                            child: Image.network(
                              user.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  _getInitials(user.username),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              _getInitials(user.username),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: () => _pickAndUploadImage(context, ref),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryBlue,
                          border: Border.all(color: surfaceColor, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24, height: 16),
              
              // User Info
              Expanded(
                flex: isMobile ? 0 : 1,
                child: Column(
                  crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                  children: [
                    // Name and verified badge
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          user.username,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: primaryGreen.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline_rounded, color: primaryGreen, size: 10),
                              const SizedBox(width: 2),
                              Text(
                                'VERIFIED',
                                style: TextStyle(
                                  color: primaryGreen,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Contact Info
                    Column(
                      crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.mail_outline_rounded, color: textSecondary, size: 14),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                user.email,
                                style: TextStyle(color: textSecondary, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.business_rounded, color: textSecondary, size: 14),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Enterprise URL Defender',
                                style: TextStyle(color: textSecondary, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'MEMBER SINCE ${_formatMemberSince(user.createdAt)}',
                          style: TextStyle(
                            color: textSecondary.withOpacity(0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
