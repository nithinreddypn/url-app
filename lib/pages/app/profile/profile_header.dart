import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../providers/app_providers.dart';
import '../../../models/user_model.dart';
import '../../../services/alert_service.dart';
import '../../../theme/app_theme.dart';

/// Redesigned premium profile card inspired by Apple, Google Material 3, and Fluent designs.
class ProfileHeader extends ConsumerStatefulWidget {
  final UserModel user;

  const ProfileHeader({super.key, required this.user});

  @override
  ConsumerState<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends ConsumerState<ProfileHeader> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isCameraHovered = false;
  bool _isRemoveHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _formatMemberSince(DateTime? date) {
    if (date == null) return 'July 2026';
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
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
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final surfaceColor = context.cardBg;
    final borderCol = context.isDark ? context.border : const Color(0xFFE5E7EB);
    
    final hasAvatar = widget.user.avatarUrl != null && widget.user.avatarUrl!.isNotEmpty;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderCol),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Top-right compact outlined remove button (pill shape, soft red background)
              if (hasAvatar)
                Positioned(
                  top: 0,
                  right: 0,
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _isRemoveHovered = true),
                    onExit: (_) => setState(() => _isRemoveHovered = false),
                    child: AnimatedScale(
                      scale: _isRemoveHovered ? 1.03 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await ref.read(userProvider.notifier).removeAvatar();
                            AlertService.showSuccess(context, 'Avatar Removed', 'Your profile picture has been removed.');
                          } catch (e) {
                            AlertService.showError(context, e);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _isRemoveHovered 
                              ? Colors.red.withOpacity(0.12)
                              : Colors.red.withOpacity(0.06),
                          side: BorderSide(
                            color: Colors.red.withOpacity(0.3),
                            width: 1.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          foregroundColor: Colors.red,
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                        label: const Text(
                          'Remove', 
                          style: TextStyle(
                            color: Colors.red, 
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Reduced top white space by aligning and placing avatar top center
                  const SizedBox(height: 12),
                  
                  // Circular profile picture center aligned with border and blue glow
                  Center(
                    child: MouseRegion(
                      onEnter: (_) => setState(() => _isCameraHovered = true),
                      onExit: (_) => setState(() => _isCameraHovered = false),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 125,
                            height: 125,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? context.secondaryCardBg : Colors.white,
                              border: Border.all(
                                color: isDark ? context.cardBg : Colors.white,
                                width: 3.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF3B82F6).withOpacity(isDark ? 0.28 : 0.18),
                                  blurRadius: 24,
                                  spreadRadius: 3,
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Hero(
                              tag: 'profile_avatar',
                              child: ClipOval(
                                child: hasAvatar
                                    ? Image.network(
                                        widget.user.avatarUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _buildPlaceholderAvatar(context),
                                      )
                                    : _buildPlaceholderAvatar(context),
                              ),
                            ),
                          ),
                          
                          // Camera upload button bottom-right overlapping
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: AnimatedScale(
                              scale: _isCameraHovered ? 1.08 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _pickAndUploadImage(context, ref),
                                  borderRadius: BorderRadius.circular(22),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF3B82F6),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF3B82F6).withOpacity(0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: isDark ? context.cardBg : Colors.white,
                                        width: 3,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20), // Spacing: Avatar -> Username
                  
                  // Username directly under avatar with Verified Badge beside it
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Text(
                        widget.user.username,
                        style: TextStyle(
                          fontSize: 31,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      
                      // Animated Verified Badge
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _fadeAnimation.value,
                            child: Transform.translate(
                              offset: Offset(0, (1 - _fadeAnimation.value) * 8),
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withOpacity(0.24),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded, 
                                color: Colors.white, 
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'VERIFIED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24), // Spacing: Username -> Information
                  
                  // Email information card
                  _buildInfoCard(
                    context,
                    icon: Icons.mail_outline_rounded,
                    label: 'EMAIL',
                    value: widget.user.email,
                  ),
                  const SizedBox(height: 16),
                  
                  // Enterprise information card
                  _buildInfoCard(
                    context,
                    icon: Icons.business_outlined,
                    label: 'ENTERPRISE',
                    value: 'URL Defender Enterprise',
                  ),
                  const SizedBox(height: 16),
                  
                  // Premium Enterprise Role Badge
                  _buildEnterpriseBadgeCard(context),
                  
                  const SizedBox(height: 28), // Spacing: Badge -> Footer
                  
                  // Member since footer
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Icon(
                          Icons.calendar_month_rounded,
                          color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                          size: 18,
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      Text(
                        'MEMBER SINCE',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatMemberSince(widget.user.createdAt),
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderAvatar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _getInitials(widget.user.username),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final cardColor = context.isDark ? context.secondaryCardBg : const Color(0xFFF8FAFC);
    final borderCol = context.isDark ? context.border : const Color(0xFFF1F5F9);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.isDark ? Colors.white.withOpacity(0.06) : Colors.white,
              border: Border.all(
                color: context.isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Icon(
              icon,
              color: context.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: context.isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnterpriseBadgeCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.24),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.12),
            ),
            child: const Icon(
              Icons.apartment_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ROLE',
                  style: TextStyle(
                    color: Color(0xFFBFDBFE),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Enterprise User',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.star_border_rounded,
            color: Colors.white.withOpacity(0.6),
            size: 24,
          ),
        ],
      ),
      );
    }
  }
