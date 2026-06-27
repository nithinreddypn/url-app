import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/blocked_url_service.dart';
import '../services/supabase_config.dart';
import '../services/password_validator.dart';
import '../services/alert_service.dart';
import '../models/blocked_url_model.dart';
import '../models/user_model.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final BlockedUrlService _blockedUrlService = BlockedUrlService();
  final ScrollController _blockedUrlsScrollController = ScrollController();

  Color get _bgColor => context.bg;
  Color get _cardColor => context.cardBg;
  Color get _surfaceColor => context.border;
  Color get _primaryGreen => context.activeAccent;
  Color get _amber => context.isDark ? Color(0xFFF59E0B) : Color(0xFFD97706);
  Color get _red => context.isDark ? Color(0xFFEF4444) : Color(0xFFDC2626);

  Color get _textPrimary => context.textPrimary;
  Color get _textSecondary => context.textSecondary;
  Color get _textMuted => context.textMuted;

  bool _showSignOutFallback = false;
  bool _blockedUrlsExpanded = false;

  @override
  void initState() {
    super.initState();
    // Eagerly ensure user profile is loaded
    Future.microtask(() async {
      try {
        await ref.read(userProvider.notifier).refreshUser();
      } catch (_) {}
      if (mounted) {
        ref.invalidate(blockedUrlsProvider);
      }
    });
    // If profile is still null after 5 seconds, show sign-out fallback
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && ref.read(userProvider) == null) {
        setState(() {
          _showSignOutFallback = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _blockedUrlsScrollController.dispose();
    super.dispose();
  }

  String _getUserInitial(UserModel? user) {
    if (user != null && user.username.isNotEmpty) {
      return user.username[0].toUpperCase();
    }
    final email = user?.email ?? SupabaseConfig.client.auth.currentUser?.email;
    if (email != null && email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return 'U';
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AlertService.showAlert(
        context,
        type: AlertType.error,
        title: 'Action Failed',
        description: message,
      );
    } else {
      AlertService.showAlert(
        context,
        type: AlertType.success,
        title: 'Success',
        description: message,
      );
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.isNegative || diff.inSeconds < 5) return 'Just now';
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showEditProfileDialog(UserModel user) {
    final controller = TextEditingController(text: user.username);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.person_outline_rounded, color: _primaryGreen, size: 24),
            SizedBox(width: 12),
            Text(
              'Edit Profile',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              style: TextStyle(color: _textPrimary),
              decoration: InputDecoration(
                labelText: 'Username',
                labelStyle: TextStyle(color: _textMuted),
                hintText: 'Enter new username',
                hintStyle: TextStyle(color: _textMuted.withValues(alpha: 0.8)),
                filled: true,
                fillColor: _surfaceColor.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: _primaryGreen, width: 1.5),
                ),
                prefixIcon: Icon(
                  Icons.edit_outlined,
                  color: _primaryGreen,
                  size: 20,
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
              style: TextStyle(color: _textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _userService.updateUser(
                  user.userId,
                  {'username': controller.text.trim()},
                );
                // Refresh user state immediately
                await ref.read(userProvider.notifier).refreshUser();
                if (!mounted) return;
                AlertService.showSuccess(
                  context,
                  'Profile Updated',
                  'Profile updated successfully.',
                );
              } catch (e) {
                if (!mounted) return;
                AlertService.showError(context, e);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Save',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: _cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.lock_outline_rounded,
                    color: _amber, size: 24),
                SizedBox(width: 12),
                Text(
                  'Change Password',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPasswordField(
                  controller: currentPassController,
                  label: 'Current Password',
                  obscure: obscureCurrent,
                  onToggle: () {
                    setDialogState(
                        () => obscureCurrent = !obscureCurrent);
                  },
                ),
                SizedBox(height: 14),
                _buildPasswordField(
                  controller: newPassController,
                  label: 'New Password',
                  obscure: obscureNew,
                  onToggle: () {
                    setDialogState(() => obscureNew = !obscureNew);
                  },
                ),
                SizedBox(height: 14),
                _buildPasswordField(
                  controller: confirmPassController,
                  label: 'Confirm Password',
                  obscure: obscureConfirm,
                  onToggle: () {
                    setDialogState(
                        () => obscureConfirm = !obscureConfirm);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: _textMuted),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final validationError = PasswordValidator.getErrorMessage(newPassController.text);
                  if (validationError != null) {
                    AlertService.showWarning(
                      context,
                      'Weak Password',
                      validationError,
                    );
                    return;
                  }
                  if (newPassController.text.trim() != confirmPassController.text.trim()) {
                    AlertService.showWarning(
                      context,
                      'Weak Password',
                      'Passwords do not match.',
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    await _authService.updatePassword(
                      newPassController.text.trim(),
                    );
                    if (!mounted) return;
                    AlertService.showSuccess(
                      context,
                      'Password Changed',
                      'Password changed successfully.',
                    );
                  } catch (e) {
                    if (!mounted) return;
                    AlertService.showError(context, e);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _amber,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Update',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: _textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _textMuted, fontSize: 13),
        filled: true,
        fillColor: _surfaceColor.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _amber, width: 1.5),
        ),
        prefixIcon:
            Icon(Icons.lock_outline, color: _amber, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: _textMuted,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }



  Future<void> _unblockUrl(BlockedUrlModel blockedUrl) async {
    try {
      final currentUser = ref.read(userProvider);
      if (currentUser == null) return;
      await _blockedUrlService.unblockUrl(blockedUrl.id, userId: currentUser.userId);
      if (!mounted) return;
      AlertService.showSuccess(
        context,
        'URL Unblocked',
        'URL unblocked successfully.',
      );
      ref.invalidate(blockedUrlsProvider);
      await ref.read(userProvider.notifier).refreshUser();
    } catch (e) {
      if (!mounted) return;
      AlertService.showError(context, e);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: _red, size: 24),
            SizedBox(width: 12),
            Text(
              'Sign Out',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: _textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: _textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Sign Out',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        ref.read(pendingSignupProvider.notifier).clear();
        ref.invalidate(userProvider);
        ref.invalidate(blockedUrlsProvider);
        ref.invalidate(scanLimitProvider);
        ref.invalidate(subscriptionProvider);
        await _authService.signOut();
        if (mounted) {
          context.go('/auth_gate');
        }
      } catch (e) {
        if (!mounted) return;
        AlertService.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final user = ref.watch(userProvider);
      debugPrint('SettingsScreen build called: userIsNull=${user == null}, showSignOutFallback=$_showSignOutFallback');

      return Scaffold(
        backgroundColor: _bgColor,
        body: ListView(
          padding: EdgeInsets.fromLTRB(16, 60, 16, 120),
          children: [
              // ── Profile Section ──
              if (user != null)
                _buildProfileSection(user)
              else
                _buildProfileLoadingSection(),
              SizedBox(height: 28),

              // ── Blocked URLs (only if user loaded) ──
              if (user != null) ...[
                _buildBlockedUrlsSection(user),
                SizedBox(height: 28),
              ],

              // ── Security ──
              _buildSectionHeader('Security'),
              SizedBox(height: 12),
              _buildSecuritySection(),
              SizedBox(height: 28),

              // ── Preferences ──
              _buildSectionHeader('Preferences'),
              SizedBox(height: 12),
              _buildThemeSection(),
              SizedBox(height: 28),

              // ── About ──
              _buildSectionHeader('About'),
              SizedBox(height: 12),
              _buildAboutSection(),
              SizedBox(height: 36),

              // ── Sign Out ──
              _buildSignOutButton(),
            ],
          ),
        );
    } catch (e, stack) {
      debugPrint('SettingsScreen build error: $e\n$stack');
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 48),
                SizedBox(height: 16),
                Text(
                  'Screen Load Error',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "We're having trouble displaying this screen. Please try again in a few moments.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  /// Shows a loading placeholder for the profile section when user data hasn't loaded yet.
  Widget _buildProfileLoadingSection() {
    final email = SupabaseConfig.client.auth.currentUser?.email ?? 'Loading...';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'U';

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _cardColor,
            _cardColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _primaryGreen.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _primaryGreen,
                  _primaryGreen.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryGreen.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
          // Email
          Text(
            email,
            style: TextStyle(
              color: _textPrimary.withValues(alpha: 0.5),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 12),
          // Loading indicator
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: _primaryGreen,
              strokeWidth: 2,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Loading profile...',
            style: TextStyle(
              color: _textMuted,
              fontSize: 12,
            ),
          ),
          if (_showSignOutFallback) ...[
            SizedBox(height: 16),
            Text(
              'Profile is taking longer than expected.',
              style: TextStyle(color: _textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: _primaryGreen,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: _primaryGreen.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: _surfaceColor.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection(UserModel user) {
    final email = user.email.isNotEmpty
        ? user.email
        : (SupabaseConfig.client.auth.currentUser?.email ?? 'Not signed in');
    final username = user.username.isNotEmpty ? user.username : 'Defender';
    final userInitial = _getUserInitial(user);

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _cardColor,
            _cardColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _primaryGreen.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _primaryGreen,
                  _primaryGreen.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryGreen.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                userInitial,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
          // Username
          Text(
            username,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: 4),
          // Email
          Text(
            email,
            style: TextStyle(
              color: _textPrimary.withValues(alpha: 0.5),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 12),
          // Role badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: user.role.toLowerCase() == 'admin'
                  ? _amber.withValues(alpha: 0.15)
                  : _primaryGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: user.role.toLowerCase() == 'admin'
                    ? _amber.withValues(alpha: 0.4)
                    : _primaryGreen.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  user.role.toLowerCase() == 'admin'
                      ? Icons.admin_panel_settings_rounded
                      : Icons.person_rounded,
                  size: 14,
                  color: user.role.toLowerCase() == 'admin'
                      ? _amber
                      : _primaryGreen,
                ),
                SizedBox(width: 6),
                Text(
                  user.role.substring(0, 1).toUpperCase() +
                      user.role.substring(1),
                  style: TextStyle(
                    color: user.role.toLowerCase() == 'admin'
                        ? _amber
                        : _primaryGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 18),
          // Edit Profile button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showEditProfileDialog(user),
              icon: Icon(Icons.edit_outlined, size: 18),
              label: Text(
                'Edit Profile',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryGreen,
                side: BorderSide(
                  color: _primaryGreen.withValues(alpha: 0.4),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedUrlsSection(UserModel user) {
    final blockedUrlsAsync = ref.watch(blockedUrlsProvider);
    final int blockedCount = blockedUrlsAsync.whenOrNull(
      data: (urls) => urls.length,
    ) ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _blockedUrlsExpanded
              ? _red.withValues(alpha: 0.3)
              : _surfaceColor.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Dropdown Header ──
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _blockedUrlsExpanded = !_blockedUrlsExpanded;
                });
              },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.block_rounded,
                        color: _red,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Blocked URLs',
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            blockedCount == 0
                                ? 'No URLs blocked'
                                : '$blockedCount URL${blockedCount == 1 ? '' : 's'} blocked',
                            style: TextStyle(
                              color: _textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _blockedUrlsExpanded ? 0.5 : 0,
                      duration: Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _textMuted,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Expandable Content ──
          AnimatedCrossFade(
            firstChild: SizedBox.shrink(),
            secondChild: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Divider(
                  height: 1,
                  color: _surfaceColor.withValues(alpha: 0.3),
                ),
                blockedUrlsAsync.when(
                  data: (blockedUrls) {
                    if (blockedUrls.isEmpty) {
                      return Padding(
                        padding: EdgeInsets.all(28),
                        child: Column(
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 36,
                              color: _primaryGreen.withValues(alpha: 0.4),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'No blocked URLs',
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'URLs you block will appear here',
                              style: TextStyle(
                                color: _textPrimary.withValues(alpha: 0.3),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(blockedUrls.length, (index) {
                        final url = blockedUrls[index];
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (index > 0)
                              Divider(
                                height: 1,
                                color: _surfaceColor.withValues(alpha: 0.2),
                                indent: 56,
                                endIndent: 16,
                              ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _red.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.link_off_rounded,
                                      color: _red.withValues(alpha: 0.7),
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          url.url,
                                          style: TextStyle(
                                            color: _textPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            if (url.reason != null &&
                                                url.reason!.isNotEmpty) ...[
                                              Flexible(
                                                child: Text(
                                                  url.reason!,
                                                  style: TextStyle(
                                                    color: _textPrimary.withValues(
                                                        alpha: 0.4),
                                                    fontSize: 11,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Text(
                                                ' · ',
                                                style: TextStyle(
                                                  color: _textPrimary.withValues(
                                                      alpha: 0.3),
                                                ),
                                              ),
                                            ],
                                            Text(
                                              _formatDate(url.blockedAt),
                                              style: TextStyle(
                                                color: _textPrimary.withValues(
                                                    alpha: 0.3),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (url.userId == user.userId)
                                    IconButton(
                                      onPressed: () => _unblockUrl(url),
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        color: _red.withValues(alpha: 0.6),
                                        size: 18,
                                      ),
                                      tooltip: 'Unblock',
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    );
                  },
                  loading: () => Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: _primaryGreen,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                  error: (e, _) => Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Failed to load: $e',
                      style: TextStyle(color: _red, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            crossFadeState: _blockedUrlsExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: Duration(milliseconds: 300),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _surfaceColor.withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showChangePasswordDialog,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    color: _amber,
                    size: 20,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Change Password',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Update your account password',
                        style: TextStyle(
                          color: _textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _textPrimary.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSection() {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _surfaceColor.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: _primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dark Mode',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Switch(
              value: isDark,
              activeThumbColor: const Color(0xFF5CED73),
              onChanged: (_) {
                ref.read(themeModeProvider.notifier).toggleTheme();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _surfaceColor.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _primaryGreen.withValues(alpha: 0.15),
                    _amber.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.shield_rounded,
                color: _primaryGreen,
                size: 20,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'URL Defender',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'v1.0.0',
                    style: TextStyle(
                      color: _textPrimary.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: _primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Latest',
                style: TextStyle(
                  color: _primaryGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOutButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _red.withValues(alpha: 0.4),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _signOut,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _red.withValues(alpha: 0.08),
                  _red.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: _red, size: 20),
                SizedBox(width: 10),
                Text(
                  'Sign Out',
                  style: TextStyle(
                    color: _red,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}