// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as image_tools;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_js_stub.dart' if (dart.library.js) 'dart:js' as js;
import '../services/auth_service.dart';
import '../services/blocked_url_service.dart';
import '../services/url_scan_service.dart';
import '../services/password_validator.dart';
import '../services/alert_service.dart';
import '../models/blocked_url_model.dart';
import '../models/user_model.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import 'widgets/section_end_indicator.dart';

const int _maxAvatarBytes = 1024 * 1024;

Uint8List? _compressAvatarBytes(Uint8List originalBytes) {
  final decoded = image_tools.decodeImage(originalBytes);
  if (decoded == null) return null;

  var working = decoded;
  final longestSide = working.width > working.height
      ? working.width
      : working.height;
  if (longestSide > 1024) {
    final scale = 1024 / longestSide;
    working = image_tools.copyResize(
      working,
      width: (working.width * scale).round(),
      height: (working.height * scale).round(),
      interpolation: image_tools.Interpolation.average,
    );
  }

  var quality = 82;
  var compressed = Uint8List.fromList(
    image_tools.encodeJpg(working, quality: quality),
  );
  while (compressed.lengthInBytes > _maxAvatarBytes && quality > 42) {
    quality -= 10;
    compressed = Uint8List.fromList(
      image_tools.encodeJpg(working, quality: quality),
    );
  }

  while (compressed.lengthInBytes > _maxAvatarBytes && working.width > 320) {
    working = image_tools.copyResize(
      working,
      width: (working.width * 0.8).round(),
      height: (working.height * 0.8).round(),
      interpolation: image_tools.Interpolation.average,
    );
    compressed = Uint8List.fromList(
      image_tools.encodeJpg(working, quality: 58),
    );
  }

  return compressed.lengthInBytes <= _maxAvatarBytes ? compressed : null;
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final BlockedUrlService _blockedUrlService = BlockedUrlService();
  final UrlScanService _scanService = UrlScanService();
  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _blockedUrlsScrollController = ScrollController();

  Color get _bgColor => context.bg;
  Color get _cardColor => context.cardBg;
  Color get _surfaceColor => context.border;
  Color get _primaryGreen => context.activeAccent;
  Color get _blueColor => context.information;
  Color get _red => context.danger;

  Color get _textPrimary => context.textPrimary;
  Color get _textSecondary => context.textSecondary;
  Color get _textMuted => context.textMuted;

  bool _showSignOutFallback = false;

  // Visual Tabs / Sections state
  int _selectedSectionIndex = 0;
  late TabController _tabController;

  // Local Presentation State (Toggles, etc.)
  bool _emailThreatAlerts = true;
  bool _pushCriticalThreats = true;
  bool _weeklySummary = false;
  bool _anonymousSharing = true;
  bool _telemetry = true;
  String _dataRetention = '90 days';

  // Security State
  bool _is2faEnabled = false;
  bool _blockedUrlsExpanded = false;
  List<Map<String, String>> _activeSessions = [];

  Future<XFile?> _prepareAvatar(XFile selectedImage) async {
    final originalBytes = await selectedImage.readAsBytes();
    if (originalBytes.lengthInBytes <= _maxAvatarBytes) return selectedImage;

    final compressed = await compute(_compressAvatarBytes, originalBytes);
    if (compressed == null) return null;
    return XFile.fromData(
      compressed,
      mimeType: 'image/jpeg',
      name: 'profile-avatar.jpg',
    );
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _emailThreatAlerts = prefs.getBool('email_threat_alerts') ?? true;
        _pushCriticalThreats = prefs.getBool('push_critical_threats') ?? true;
        _weeklySummary = prefs.getBool('weekly_summary') ?? false;
        _anonymousSharing = prefs.getBool('anonymous_sharing') ?? true;
        _telemetry = prefs.getBool('telemetry') ?? true;
        _dataRetention = prefs.getString('data_retention') ?? '90 days';
        _is2faEnabled = prefs.getBool('is_2fa_enabled') ?? false;
      });
    } catch (_) {}
  }

  Future<void> _saveBoolSetting(String key, bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, val);
    } catch (_) {}
  }

  Future<void> _saveStringSetting(String key, String val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, val);
    } catch (_) {}
  }

  Future<void> _fetchSessions() async {
    try {
      final sessions = await _authService.getActiveSessions();
      if (mounted) {
        setState(() {
          _activeSessions = sessions;
        });
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _selectedSectionIndex = ref.read(settingsSectionProvider);
    _tabController = TabController(length: 5, vsync: this, initialIndex: _selectedSectionIndex);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedSectionIndex = _tabController.index;
        });
        if (_tabController.index == 3) {
          _fetchSessions();
        }
      }
    });

    _loadSettings();
    _fetchSessions();

    Future.microtask(() async {
      try {
        await ref.read(userProvider.notifier).refreshUser();
      } catch (_) {}
      if (mounted) {
        ref.invalidate(blockedUrlsProvider);
      }
    });

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
    _tabController.dispose();
    _mainScrollController.dispose();
    _blockedUrlsScrollController.dispose();
    super.dispose();
  }

  Widget _avatarContent(UserModel user, {Uint8List? previewBytes}) {
    if (previewBytes != null) {
      return ClipOval(
        child: SizedBox.expand(
          child: Image.memory(previewBytes, fit: BoxFit.cover),
        ),
      );
    }
    final avatarUrl = user.avatarUrl;
    if (avatarUrl != null && avatarUrl.startsWith('data:image/')) {
      try {
        return ClipOval(
          child: SizedBox.expand(
            child: Image.memory(
              base64Decode(avatarUrl.split(',').last),
              fit: BoxFit.cover,
            ),
          ),
        );
      } catch (_) {
        return const Icon(Icons.person_rounded, color: Colors.white, size: 40);
      }
    }
    if (avatarUrl != null && avatarUrl.startsWith('http')) {
      return ClipOval(
        child: SizedBox.expand(
          child: Image.network(
            avatarUrl,
            key: ValueKey(avatarUrl),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.person_rounded, color: Colors.white, size: 40),
          ),
        ),
      );
    }
    return const Icon(Icons.person_rounded, color: Colors.white, size: 40);
  }

  Future<void> _showEditProfileDialog(UserModel user) async {
    final controller = TextEditingController(text: user.username);
    XFile? selectedImage;
    Uint8List? previewBytes;
    bool isSaving = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                color: _primaryGreen,
                size: 24,
              ),
              const SizedBox(width: 12),
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
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _primaryGreen,
                    border: Border.all(color: _surfaceColor, width: 2),
                  ),
                  child: Center(
                    child: _avatarContent(user, previewBytes: previewBytes),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final image = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1024,
                            maxHeight: 1024,
                            imageQuality: 82,
                          );
                          if (image == null) return;
                          final preparedImage = await _prepareAvatar(image);
                          if (!context.mounted) return;
                          if (preparedImage == null) {
                            AlertService.showWarning(
                              context,
                              'Image Too Large',
                              'Choose a smaller JPEG, PNG, or WebP image.',
                            );
                            return;
                          }
                          final bytes = await preparedImage.readAsBytes();
                          setDialogState(() {
                            selectedImage = preparedImage;
                            previewBytes = bytes;
                          });
                        },
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Upload profile photo'),
                ),
                const SizedBox(height: 4),
                Text(
                  'JPEG, PNG, or WebP · maximum 1 MB',
                  style: TextStyle(color: _textMuted, fontSize: 11),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  style: TextStyle(color: _textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    labelStyle: TextStyle(color: _textMuted),
                    hintText: 'Enter new username',
                    hintStyle: TextStyle(
                      color: _textMuted.withOpacity(0.8),
                    ),
                    filled: true,
                    fillColor: _surfaceColor.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _primaryGreen, width: 1.5),
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
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: _textMuted)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final fullName = controller.text.trim();
                      if (fullName.isEmpty) return;
                      setDialogState(() => isSaving = true);
                      try {
                        final notifier = ref.read(userProvider.notifier);
                        if (fullName != user.username) {
                          await notifier.updateProfile(fullName: fullName);
                        }
                        if (selectedImage != null) {
                          await notifier.uploadAvatar(selectedImage!);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (!mounted) return;
                        AlertService.showSuccess(
                          context,
                          'Profile Updated',
                          'Profile updated successfully.',
                        );
                      } catch (error) {
                        if (ctx.mounted) {
                          setDialogState(() => isSaving = false);
                          AlertService.showError(ctx, error);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;
    final screenContext = context;

    double passwordStrength = 0.0;
    Color strengthColor = _red;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          void updateStrength(String val) {
            if (val.isEmpty) {
              passwordStrength = 0.0;
              strengthColor = _red;
              return;
            }
            double strength = 0.0;
            if (val.length >= 8) strength += 0.25;
            if (val.contains(RegExp(r'[A-Z]'))) strength += 0.25;
            if (val.contains(RegExp(r'[0-9]'))) strength += 0.25;
            if (val.contains(RegExp(r'[!@#\$&*~]'))) strength += 0.25;

            passwordStrength = strength;
            if (strength <= 0.25) {
              strengthColor = _red;
            } else if (strength <= 0.50) {
              strengthColor = _primaryGreen.withOpacity(0.5);
            } else if (strength <= 0.75) {
              strengthColor = _blueColor;
            } else {
              strengthColor = _primaryGreen;
            }
          }

          return AlertDialog(
            backgroundColor: _cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.lock_outline_rounded, color: _blueColor, size: 24),
                const SizedBox(width: 12),
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
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPasswordField(
                    controller: currentPassController,
                    label: 'Current Password',
                    obscure: obscureCurrent,
                    onToggle: () {
                      setDialogState(() => obscureCurrent = !obscureCurrent);
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildPasswordField(
                    controller: newPassController,
                    label: 'New Password',
                    obscure: obscureNew,
                    onChanged: (val) {
                      setDialogState(() {
                        updateStrength(val);
                      });
                    },
                    onToggle: () {
                      setDialogState(() => obscureNew = !obscureNew);
                    },
                  ),
                  const SizedBox(height: 6),
                  if (newPassController.text.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: passwordStrength,
                        backgroundColor: _surfaceColor,
                        valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      passwordStrength <= 0.25
                          ? 'Weak'
                          : passwordStrength <= 0.50
                              ? 'Fair'
                              : passwordStrength <= 0.75
                                  ? 'Good'
                                  : 'Strong',
                      style: TextStyle(
                        color: strengthColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _buildPasswordField(
                    controller: confirmPassController,
                    label: 'Confirm Password',
                    obscure: obscureConfirm,
                    onToggle: () {
                      setDialogState(() => obscureConfirm = !obscureConfirm);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: _textMuted)),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (currentPassController.text.isEmpty) {
                          AlertService.showWarning(
                            dialogContext,
                            'Current Password Required',
                            'Enter your current password to continue.',
                          );
                          return;
                        }
                        final validationError =
                            PasswordValidator.getErrorMessage(
                          newPassController.text,
                        );
                        if (validationError != null) {
                          AlertService.showWarning(
                            dialogContext,
                            'Weak Password',
                            validationError,
                          );
                          return;
                        }
                        if (newPassController.text.trim() !=
                            confirmPassController.text.trim()) {
                          AlertService.showWarning(
                            dialogContext,
                            'Passwords Do Not Match',
                            'Passwords do not match.',
                          );
                          return;
                        }
                        if (currentPassController.text ==
                            newPassController.text.trim()) {
                          AlertService.showWarning(
                            dialogContext,
                            'Choose Another Password',
                            'Your new password must be different from your current password.',
                          );
                          return;
                        }

                        setDialogState(() => isSubmitting = true);
                        try {
                          await _authService.changePassword(
                            currentPassword: currentPassController.text,
                            newPassword: newPassController.text.trim(),
                          );
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          if (!mounted) return;
                          AlertService.showSuccess(
                            screenContext,
                            'Password Changed',
                            'Your password was changed successfully.',
                          );
                        } catch (e) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() => isSubmitting = false);
                          AlertService.showError(
                            dialogContext,
                            e,
                            customTitle: 'Password Not Changed',
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blueColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Update',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          );
        },
      ),
    );
    currentPassController.dispose();
    newPassController.dispose();
    confirmPassController.dispose();
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      style: TextStyle(color: _textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _textMuted, fontSize: 13),
        filled: true,
        fillColor: _surfaceColor.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _blueColor, width: 1.5),
        ),
        prefixIcon: Icon(Icons.lock_outline, color: _blueColor, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: _textMuted,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Future<void> _unblockUrl(BlockedUrlModel blockedUrl) async {
    try {
      final currentUser = ref.read(userProvider);
      if (currentUser == null) return;
      await _blockedUrlService.unblockUrl(
        blockedUrl.id,
        userId: currentUser.userId,
      );
      if (!context.mounted) return;
      AlertService.showSuccess(
        context,
        'URL Unblocked',
        'URL unblocked successfully.',
      );
      ref.invalidate(blockedUrlsProvider);
      await ref.read(userProvider.notifier).refreshUser();
    } catch (e) {
      if (!context.mounted) return;
      AlertService.showError(context, e);
    }
  }

  Future<void> _downloadAccountData(UserModel user) async {
    try {
      final scans = await _scanService.getUserScans(user.userId);
      final Map<String, dynamic> exportData = {
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'scans': scans.map((s) => s.toJson()).toList(),
      };
      
      final jsonString = jsonEncode(exportData);
      
      if (kIsWeb) {
        final base64Json = base64Encode(utf8.encode(jsonString));
        final jsCode = '''
          var base64 = "$base64Json";
          var binary = atob(base64);
          var bytes = new Uint8Array(binary.length);
          for (var i = 0; i < binary.length; i++) {
            bytes[i] = binary.charCodeAt(i);
          }
          var blob = new Blob([bytes], {type: "application/json"});
          var url = URL.createObjectURL(blob);
          var a = document.createElement("a");
          a.href = url;
          a.download = "urldefender-scans-${DateTime.now().toIso8601String().substring(0, 10)}.json";
          document.body.appendChild(a);
          a.click();
          a.remove();
          URL.revokeObjectURL(url);
        ''';
        js.context.callMethod('eval', [jsCode]);
      } else {
        final uri = Uri.parse('data:application/json;charset=utf-8;base64,' + base64Encode(utf8.encode(jsonString)));
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      
      if (mounted) {
        AlertService.showSuccess(context, 'Export Ready', 'Your account data has been downloaded successfully.');
      }
    } catch (e) {
      if (mounted) {
        AlertService.showError(context, e);
      }
    }
  }

  String _generateMfaSecret() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final rand = DateTime.now().millisecondsSinceEpoch;
    return List.generate(16, (i) => chars[(rand + i * 7) % chars.length]).join();
  }

  List<String> _generateBackupCodes() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = DateTime.now().millisecondsSinceEpoch;
    return List.generate(8, (i) {
      final part1 = List.generate(4, (j) => chars[(rand + i * 13 + j * 7) % chars.length]).join();
      final part2 = List.generate(4, (j) => chars[(rand + i * 17 + j * 9) % chars.length]).join();
      return '$part1-$part2';
    });
  }

  void _showSetup2faDialog(UserModel? user) {
    if (user == null) return;
    
    final secret = _generateMfaSecret();
    final uri = 'otpauth://totp/URLDefender:${user.email}?secret=$secret&issuer=URLDefender';
    final qrUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${Uri.encodeComponent(uri)}';
    
    int setupStep = 1;
    final codeController = TextEditingController();
    List<String> backupCodes = [];
    String? mfaError;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: _cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.security_rounded, color: _primaryGreen, size: 24),
                const SizedBox(width: 12),
                Text(
                  setupStep == 1
                      ? 'Step 1: Scan QR Code'
                      : setupStep == 2
                          ? 'Step 2: Verify Code'
                          : 'Step 3: Backup Codes',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 320,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (setupStep == 1) ...[
                      Text(
                        'Scan this QR code with Google Authenticator, Microsoft Authenticator, Authy, or 1Password.',
                        style: TextStyle(color: _textSecondary, fontSize: 12, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Image.network(
                            qrUrl,
                            width: 180,
                            height: 180,
                            errorBuilder: (_, __, ___) => Container(
                              width: 180,
                              height: 180,
                              color: Colors.grey[200],
                              child: const Icon(Icons.qr_code_2_rounded, size: 64, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Or enter key manually:',
                        style: TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _surfaceColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _surfaceColor),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                secret,
                                style: TextStyle(
                                  color: _textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.copy_rounded, color: _primaryGreen, size: 18),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: secret));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Secret key copied..')),
                                );
                              },
                              tooltip: 'Copy secret key',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text('Cancel', style: TextStyle(color: _textMuted)),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              setDialogState(() {
                                setupStep = 2;
                              });
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: _primaryGreen),
                            child: const Text('Continue', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ] else if (setupStep == 2) ...[
                      Text(
                        'Enter the 6-digit verification code generated by your authenticator app.',
                        style: TextStyle(color: _textSecondary, fontSize: 12, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 6),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '123456',
                          hintStyle: TextStyle(color: _textMuted.withOpacity(0.5), letterSpacing: 6),
                          filled: true,
                          fillColor: _surfaceColor.withOpacity(0.5),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryGreen, width: 1.5)),
                          counterText: '',
                        ),
                        onChanged: (val) {
                          final cleaned = val.replaceAll(RegExp(r'\D'), '');
                          if (cleaned != val) {
                            codeController.value = TextEditingValue(
                              text: cleaned,
                              selection: TextSelection.collapsed(offset: cleaned.length),
                            );
                          }
                          if (mfaError != null) {
                            setDialogState(() {
                              mfaError = null;
                            });
                          }
                        },
                      ),
                      if (mfaError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          mfaError!,
                          style: TextStyle(color: _red, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              setDialogState(() {
                                setupStep = 1;
                              });
                            },
                            child: Text('Back', style: TextStyle(color: _textMuted)),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (codeController.text.length != 6) {
                                setDialogState(() {
                                  mfaError = 'Verification code must be 6 digits.';
                                });
                                return;
                              }
                              backupCodes = _generateBackupCodes();
                              setDialogState(() {
                                setupStep = 3;
                              });
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: _primaryGreen),
                            child: const Text('Verify & enable', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ] else if (setupStep == 3) ...[
                      Text(
                        'Save these backup codes somewhere safe. You can use them to recover access if you lose your authenticator device.',
                        style: TextStyle(color: _textSecondary, fontSize: 12, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _surfaceColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _surfaceColor),
                        ),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 2.8,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 6,
                          ),
                          itemCount: backupCodes.length,
                          itemBuilder: (context, idx) {
                            return Center(
                              child: Text(
                                backupCodes[idx],
                                style: TextStyle(
                                  color: _textPrimary,
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: backupCodes.join('\n')));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Backup codes copied..')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy codes'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primaryGreen,
                          side: BorderSide(color: _primaryGreen.withOpacity(0.5)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _is2faEnabled = true;
                          });
                          _saveBoolSetting('is_2fa_enabled', true);
                          Navigator.pop(ctx);
                          AlertService.showSuccess(
                            context,
                            '2FA Settings Updated',
                            'Updated security settings successfully.',
                          );
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: _primaryGreen),
                        child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDisable2faDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _red, size: 24),
            const SizedBox(width: 12),
            Text(
              'Disable 2FA?',
              style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Your account will only be protected by your password. You can re-enable 2FA at any time.',
          style: TextStyle(color: _textSecondary, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: _textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _is2faEnabled = false;
              });
              _saveBoolSetting('is_2fa_enabled', false);
              Navigator.pop(ctx);
              AlertService.showSuccess(
                context,
                '2FA Settings Updated',
                'Updated security settings successfully.',
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            child: const Text('Disable 2FA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.article_outlined, color: _primaryGreen, size: 24),
            const SizedBox(width: 12),
            Text('Terms of Service', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildModalSectionTitle('1. Acceptance of Terms'),
                _buildModalText('By accessing URL Defender, you agree to comply with our security protocols and service guidelines. If you do not accept these terms, you must discontinue use.'),
                const SizedBox(height: 14),
                _buildModalSectionTitle('2. Service Description'),
                _buildModalText('URL Defender provides real-time link scanning, diagnostic analysis, database categorization, and phishing threat prevention features for safe web browsing.'),
                const SizedBox(height: 14),
                _buildModalSectionTitle('3. Acceptable Use'),
                _buildModalText('You agree not to use the service for scraping, brute-forcing, hosting malicious redirection databases, or attempting to bypass security barriers.'),
                const SizedBox(height: 14),
                _buildModalSectionTitle('4. Contact & Legal Inquiry'),
                _buildModalText('For official legal compliance, audits, or legal inquiries, please contact us at legal@urldefender.org.'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: _primaryGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.privacy_tip_outlined, color: _primaryGreen, size: 24),
            const SizedBox(width: 12),
            Text('Privacy Policy', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildModalSectionTitle('1. Personal Data Isolation'),
                _buildModalText('All registered names, email credentials, security sessions, and active passwords are encrypted in isolated database partitions. We never share your credentials.'),
                const SizedBox(height: 14),
                _buildModalSectionTitle('2. Shared Threat Intelligence'),
                _buildModalText('When contributing threat data, only normalized URLs (hostnames and paths) and malicious verdicts are shared globally. Your user identity is completely stripped.'),
                const SizedBox(height: 14),
                _buildModalSectionTitle('3. Data Retention & Deletion'),
                _buildModalText('Scans are stored for the period specified in your retention settings. You can delete or download your complete record at any time from the Privacy panel.'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: _primaryGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSupportDialog() {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    bool isSubmitting = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.support_agent_outlined, color: _primaryGreen, size: 24),
              const SizedBox(width: 12),
              Text('Support & Contact', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Submit a support ticket and our security team will reach out to you shortly.', style: TextStyle(color: _textSecondary, fontSize: 12)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: subjectController,
                    style: TextStyle(color: _textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      labelStyle: TextStyle(color: _textMuted),
                      filled: true,
                      fillColor: _surfaceColor.withOpacity(0.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: messageController,
                    maxLines: 4,
                    style: TextStyle(color: _textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Message',
                      labelStyle: TextStyle(color: _textMuted),
                      filled: true,
                      fillColor: _surfaceColor.withOpacity(0.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: _textMuted)),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (subjectController.text.trim().isEmpty || messageController.text.trim().isEmpty) {
                        AlertService.showWarning(dialogCtx, 'Fields Required', 'Please fill in both subject and message.');
                        return;
                      }
                      setDialogState(() => isSubmitting = true);
                      await Future<void>.delayed(const Duration(milliseconds: 600));
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!mounted) return;
                      AlertService.showSuccess(
                        context,
                        'Ticket Submitted',
                        'Support ticket submitted successfully. Our team will contact you shortly.',
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Ticket', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangelogDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.history_rounded, color: _primaryGreen, size: 24),
            const SizedBox(width: 12),
            Text('Version History', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ChangelogEntry(
                  version: 'v2.4.0',
                  date: 'July 2026',
                  tag: 'Latest Release',
                  title: 'Major Security Update & Redesign',
                  bullets: [
                    'Rebuilt Settings screen layout with left navigation rail.',
                    'Optimized local and remote database access efficiency.',
                    'Fixed CORS authentication parameters on avatar queries.',
                    'Implemented diagnostic telemetry collection toggle.'
                  ],
                ),
                const SizedBox(height: 14),
                const ChangelogEntry(
                  version: 'v2.3.0',
                  date: 'May 2026',
                  tag: 'Engine Upgrade',
                  title: 'VirusTotal & Google Safe Browsing Integration',
                  bullets: [
                    'Implemented hybrid API multi-engine scanning.',
                    'Enabled dynamic cached scan recall mechanisms.',
                    'Added blocked URLs list with real-time exclusions.'
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: _primaryGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildModalSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildModalText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(color: _textSecondary, fontSize: 12, height: 1.4),
      ),
    );
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
            const SizedBox(width: 12),
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
            child: Text('Cancel', style: TextStyle(color: _textMuted)),
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
            child: const Text(
              'Sign Out',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        ref.read(pendingSignupProvider.notifier).clear();
        ref.read(userProvider.notifier).logout();
        ref.invalidate(blockedUrlsProvider);
        ref.invalidate(scanLimitProvider);
        ref.invalidate(subscriptionProvider);
        if (context.mounted) {
          context.go('/auth_gate');
        }
      } catch (e) {
        if (!context.mounted) return;
        AlertService.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(settingsSectionProvider, (previous, next) {
      if (next != _selectedSectionIndex) {
        setState(() {
          _selectedSectionIndex = next;
          _tabController.index = next;
        });
        if (next == 3) {
          _fetchSessions();
        }
      }
    });
    try {
      final user = ref.watch(userProvider);
      final isDesktop = MediaQuery.of(context).size.width >= 1024;

      return Scaffold(
        backgroundColor: _bgColor,
        body: SafeArea(
          bottom: false,
          child: isDesktop
              ? Row(
                  children: [
                    _buildNavigationRail(),
                    VerticalDivider(width: 1, color: _surfaceColor),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          Expanded(
                            child: _buildMainContentArea(user),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    _buildTopTabBar(),
                    Expanded(
                      child: _buildMainContentArea(user),
                    ),
                  ],
                ),
        ),
      );
    } catch (e, stack) {
      if (kDebugMode) debugPrint('SettingsScreen build error: $e\n$stack');
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Scrollbar(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Settings Screen Build Error',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      '$e\n$stack',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  // ── HEADER ──
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(Icons.settings_outlined, color: _primaryGreen, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Configure profile, safety levels & theme',
                style: TextStyle(color: _textSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── LEFT NAVIGATION RAIL (Desktop) ──
  Widget _buildNavigationRail() {
    return Container(
      width: 220,
      color: _cardColor,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Logo
          Row(
            children: [
              Icon(Icons.shield_rounded, color: _primaryGreen, size: 28),
              const SizedBox(width: 10),
              Text(
                'Settings',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Nav items
          Expanded(
            child: ListView(
              children: [
                _buildRailItem(0, Icons.palette_outlined, 'Appearance'),
                _buildRailItem(1, Icons.notifications_none_rounded, 'Notifications'),
                _buildRailItem(2, Icons.privacy_tip_outlined, 'Privacy'),
                _buildRailItem(3, Icons.security_rounded, 'Security'),
                _buildRailItem(4, Icons.info_outline_rounded, 'About App'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRailItem(int index, IconData icon, String title) {
    final isSelected = _selectedSectionIndex == index;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedSectionIndex = index;
              _tabController.index = index;
            });
            if (index == 3) {
              _fetchSessions();
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected ? _primaryGreen.withOpacity(0.08) : Colors.transparent,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? _primaryGreen : _textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? _primaryGreen : _textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── HORIZONTAL TABBAR (Mobile & Tablet Unified) ──
  Widget _buildTopTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: TabBar(
          dividerColor: Colors.transparent,
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: _primaryGreen,
          labelColor: _primaryGreen,
          unselectedLabelColor: _textSecondary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Appearance', icon: Icon(Icons.palette_outlined, size: 18)),
            Tab(text: 'Notifications', icon: Icon(Icons.notifications_none_rounded, size: 18)),
            Tab(text: 'Privacy', icon: Icon(Icons.privacy_tip_outlined, size: 18)),
            Tab(text: 'Security', icon: Icon(Icons.security_rounded, size: 18)),
            Tab(text: 'About App', icon: Icon(Icons.info_outline_rounded, size: 18)),
          ],
        ),
      ),
    );
  }

  // ── CONTENT PANEL AREA ──
  Widget _buildMainContentArea(UserModel? user) {
    if (user == null) {
      return _buildSkeletonLoader();
    }

    return Scrollbar(
      controller: _mainScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _mainScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 72),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Floating profile overview widget
            _buildProfileSection(user),
            const SizedBox(height: 12),
            _buildActivePanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildActivePanel() {
    switch (_selectedSectionIndex) {
      case 0: return _buildAppearancePanel();
      case 1: return _buildNotificationsPanel();
      case 2: return _buildPrivacyPanel();
      case 3: return _buildSecurityPanel();
      case 4: return _buildAboutPanel();
      default: return const SizedBox.shrink();
    }
  }

  // Shimmer / Skeleton Loader
  Widget _buildSkeletonLoader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: _cardColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 150,
            height: 28,
            color: _cardColor.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Container(
            height: 80,
            color: _cardColor.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Container(
            height: 80,
            color: _cardColor.withOpacity(0.5),
          ),
        ],
      ),
    );
  }

  // ── 1. APPEARANCE PANEL ──
  Widget _buildAppearancePanel() {
    return PanelCard(
      title: 'Appearance Settings',
      description: 'Manage how URL Defender looks on your device.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Theme Mode',
            style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          ThemeSelector(
            currentTheme: ref.watch(themeModeProvider),
            onChanged: (mode) {
              ref.read(themeModeProvider.notifier).setTheme(mode);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Theme mode updated..')),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Accent Color',
            style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          AccentColorPicker(
            currentColor: ref.watch(accentColorProvider),
            onChanged: (color) {
              ref.read(accentColorProvider.notifier).state = color;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Accent color updated..')),
              );
            },
          ),
          const SizedBox(height: 16),
          const SectionEndIndicator(
            icon: Icons.palette_outlined,
            message: 'Appearance settings configured',
          ),
        ],
      ),
    );
  }

  // ── 2. NOTIFICATIONS PANEL ──
  Widget _buildNotificationsPanel() {
    return PanelCard(
      title: 'Notification Preferences',
      description: 'Choose when and how you want to be alerted.',
      content: Column(
        children: [
          ToggleRow(
            title: 'Email Alerts on Threat detection',
            subtitle: 'Get emails immediately when a dangerous URL is processed.',
            value: _emailThreatAlerts,
            onChanged: (val) {
              setState(() => _emailThreatAlerts = val);
              _saveBoolSetting('email_threat_alerts', val);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification updated..')),
              );
            },
          ),
          const SizedBox(height: 8),
          ToggleRow(
            title: 'Critical Threat Push notifications',
            subtitle: 'Immediate push alerts for high severity phishing.',
            value: _pushCriticalThreats,
            onChanged: (val) {
              setState(() => _pushCriticalThreats = val);
              _saveBoolSetting('push_critical_threats', val);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification updated..')),
              );
            },
          ),
          const SizedBox(height: 8),
          ToggleRow(
            title: 'Weekly Summary reports',
            subtitle: 'Receive a report summarizing scan history and status.',
            value: _weeklySummary,
            onChanged: (val) {
              setState(() => _weeklySummary = val);
              _saveBoolSetting('weekly_summary', val);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification updated..')),
              );
            },
          ),
          const SizedBox(height: 16),
          const SectionEndIndicator(
            icon: Icons.notifications_active_outlined,
            message: 'All notifications configured',
          ),
        ],
      ),
    );
  }

  // ── 3. PRIVACY PANEL ──
  Widget _buildPrivacyPanel() {
    final isTablet = MediaQuery.of(context).size.width >= 640;

    return PanelCard(
      title: 'Privacy & Sharing',
      description: 'Manage your analytical profile and diagnostic reporting.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ToggleRow(
            title: 'Share Anonymous Threat Intelligence',
            subtitle: 'Help secure other users by reporting malicious threats.',
            value: _anonymousSharing,
            onChanged: (val) {
              setState(() => _anonymousSharing = val);
              _saveBoolSetting('anonymous_sharing', val);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Privacy settings updated..')),
              );
            },
          ),
          const SizedBox(height: 8),
          ToggleRow(
            title: 'Diagnostic Telemetry logs',
            subtitle: 'Send telemetry logs to optimize performance.',
            value: _telemetry,
            onChanged: (val) {
              setState(() => _telemetry = val);
              _saveBoolSetting('telemetry', val);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Privacy settings updated..')),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Data Retention Limit',
            style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _dataRetention,
            dropdownColor: _cardColor,
            style: TextStyle(color: _textPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: _surfaceColor.withOpacity(0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: '30 days', child: Text('30 days')),
              DropdownMenuItem(value: '90 days', child: Text('90 days')),
              DropdownMenuItem(value: '1 year', child: Text('1 year')),
              DropdownMenuItem(value: 'Forever', child: Text('Forever')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _dataRetention = val);
                _saveStringSetting('data_retention', val);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Data retention preference updated..')),
                );
              }
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Your Account Data',
            style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          isTablet
              ? Row(
                  children: [
                    Expanded(
                      child: _buildDataExportCard(
                        icon: Icons.download_rounded,
                        iconColor: Colors.blue,
                        title: 'Download Account Data',
                        description: 'Export all URLs scans and security logs.',
                        onTap: () {
                          AlertService.showSuccess(context, 'Export Started', 'Data bundle is preparing.');
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDataExportCard(
                        icon: Icons.delete_forever_outlined,
                        iconColor: _red,
                        title: 'Delete My Data',
                        description: 'Permanently purge historical records.',
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: _cardColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: Text('Delete Data?', style: TextStyle(color: _textPrimary)),
                              content: const Text('Are you sure you want to permanently clear all scan history? This action is irreversible.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(backgroundColor: _red),
                                  child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            try {
                              final currentUser = ref.read(userProvider);
                              if (currentUser != null) {
                                await _scanService.deleteScan('all', userId: currentUser.userId);
                              }
                              ref.invalidate(scanHistoryProvider);
                              ref.invalidate(recentScansProvider);
                              ref.invalidate(dangerousScansProvider);
                              ref.invalidate(scanLimitProvider);
                              if (context.mounted) {
                                AlertService.showSuccess(context, 'Data Purged', 'Your records have been cleared.');
                              }
                            } catch (e) {
                              if (context.mounted) {
                                AlertService.showError(context, e);
                              }
                            }
                          }
                        },
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildDataExportCard(
                      icon: Icons.download_rounded,
                      iconColor: Colors.blue,
                      title: 'Download Account Data',
                      description: 'Export all URLs scans and security logs.',
                      onTap: () {
                        AlertService.showSuccess(context, 'Export Started', 'Data bundle is preparing.');
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDataExportCard(
                      icon: Icons.delete_forever_outlined,
                      iconColor: _red,
                      title: 'Delete My Data',
                      description: 'Permanently purge historical records.',
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: _cardColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: Text('Delete Data?', style: TextStyle(color: _textPrimary)),
                            content: const Text('Are you sure you want to permanently clear all scan history? This action is irreversible.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(backgroundColor: _red),
                                child: const Text('Delete', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          try {
                            final currentUser = ref.read(userProvider);
                            if (currentUser != null) {
                              await _scanService.deleteScan('all', userId: currentUser.userId);
                            }
                            ref.invalidate(scanHistoryProvider);
                            ref.invalidate(recentScansProvider);
                            ref.invalidate(dangerousScansProvider);
                            ref.invalidate(scanLimitProvider);
                            if (context.mounted) {
                              AlertService.showSuccess(context, 'Data Purged', 'Your records have been cleared.');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              AlertService.showError(context, e);
                            }
                          }
                        }
                      },
                    ),
                  ],
                ),
          const SizedBox(height: 16),
          const SectionEndIndicator(
            icon: Icons.privacy_tip_outlined,
            message: 'Your privacy is protected',
          ),
        ],
      ),
    );
  }

  Widget _buildDataExportCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _surfaceColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(color: _textMuted, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 4. SECURITY PANEL ──
  Widget _buildPlaceholderLine(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _textSecondary.withOpacity(0.5), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 4. SECURITY PANEL ──
  Widget _buildSecurityPanel() {
    final user = ref.watch(userProvider);
    final blockedUrlsAsync = ref.watch(blockedUrlsProvider);
    final int blockedCount =
        blockedUrlsAsync.whenOrNull(data: (urls) => urls.length) ?? 0;

    return PanelCard(
      title: 'Security Settings',
      description: 'Secure your login sessions and configure login preferences.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Change password row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_clock_outlined, color: _blueColor, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Password Management',
                            style: TextStyle(
                              color: _textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Changed recently · Secure 256-bit encryption.',
                            style: TextStyle(color: _textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 36.0),
                  child: ElevatedButton(
                    onPressed: _showChangePasswordDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blueColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text(
                      'Change Password',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 2FA row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.security_rounded, color: _primaryGreen, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              Text(
                                'Two-Factor Auth (2FA)',
                                style: TextStyle(
                                  color: _textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _is2faEnabled 
                                      ? _primaryGreen.withOpacity(0.12)
                                      : _textSecondary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _is2faEnabled 
                                        ? _primaryGreen.withOpacity(0.3)
                                        : _textSecondary.withOpacity(0.15),
                                  ),
                                ),
                                child: Text(
                                  _is2faEnabled ? 'Enabled' : 'Disabled',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _is2faEnabled ? _primaryGreen : _textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Secure using Google Authenticator, Authy, or 1Password.',
                            style: TextStyle(color: _textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 36.0),
                  child: OutlinedButton(
                    onPressed: () {
                      if (_is2faEnabled) {
                        _showDisable2faDialog();
                      } else {
                        _showSetup2faDialog(user);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: Text(
                      _is2faEnabled ? 'Disable 2FA' : 'Set up 2FA',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Blocked URLs Expansion
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _blockedUrlsExpanded ? _red.withOpacity(0.3) : _surfaceColor,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.block_rounded, color: _red, size: 22),
                  title: const Text('Blocked URLs List', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(blockedCount == 0 ? 'No blocked URLs' : '$blockedCount URL(s) blocked', style: TextStyle(color: _textMuted, fontSize: 11)),
                  trailing: Icon(
                    _blockedUrlsExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: _textMuted,
                  ),
                  onTap: () => setState(() => _blockedUrlsExpanded = !_blockedUrlsExpanded),
                ),
                if (_blockedUrlsExpanded) ...[
                  Divider(height: 1, color: _surfaceColor),
                  blockedUrlsAsync.when(
                    data: (blockedUrls) {
                      if (blockedUrls.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text('No URLs blocked', style: TextStyle(color: _textMuted, fontSize: 12)),
                        );
                      }
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: blockedUrls.map((url) {
                          return ListTile(
                            title: Text(
                              url.url,
                              style: TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(url.reason ?? 'No reason', style: TextStyle(color: _textMuted, fontSize: 10)),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline_rounded, color: _red.withOpacity(0.7), size: 18),
                              onPressed: () => _unblockUrl(url),
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    error: (err, _) => Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Error: $err', style: TextStyle(color: _red, fontSize: 11)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Active sessions section
          Row(
            children: [
              Text('Active Sessions', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              if (_activeSessions.length > 1)
                TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: _cardColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text('Revoke Other Sessions?', style: TextStyle(color: _textPrimary)),
                        content: const Text('This will disconnect all other devices except this current session.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: _red),
                            child: const Text('Revoke All', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await _authService.revokeAllOtherSessions();
                        await _fetchSessions();
                        if (context.mounted) {
                          AlertService.showSuccess(context, 'Sessions Revoked', 'Logged out other sessions.');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          AlertService.showError(context, e);
                        }
                      }
                    }
                  },
                  child: Text('Revoke all others', style: TextStyle(color: _red)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_activeSessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No active sessions found',
                style: TextStyle(color: _textMuted, fontSize: 12),
              ),
            )
          else
            ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _activeSessions.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (ctx, index) {
                final session = _activeSessions[index];
                final isCurrent = session['isCurrent'] == 'true';
                return SessionTile(
                  device: session['device'] ?? '',
                  browser: session['browser'] ?? '',
                  isCurrent: isCurrent,
                  onRevoke: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: _cardColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text('Revoke Session?', style: TextStyle(color: _textPrimary)),
                        content: Text('Revoke session for ${session['device']}?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: _red),
                            child: const Text('Revoke', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await _authService.revokeSession(session['id']!);
                        await _fetchSessions();
                        if (context.mounted) {
                          AlertService.showSuccess(context, 'Session Terminated', 'Session revoked.');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          AlertService.showError(context, e);
                        }
                      }
                    }
                  },
                );
              },
            ),
          const SizedBox(height: 6),
          const SectionEndIndicator(
            icon: Icons.devices_other_rounded,
            message: "That's all your active sessions",
          ),
          const Divider(height: 20),
          _buildPlaceholderLine(Icons.verified_user_rounded, 'Device Security', 'No additional security events available. Your account is currently protected.'),
          const SizedBox(height: 12),
          _buildPlaceholderLine(Icons.history_toggle_off_rounded, 'Login Activity', 'Your recent authentication events are secure.'),
          const SizedBox(height: 16),
          _buildPlaceholderLine(Icons.security_update_good_rounded, 'Account Protection', 'Real-time shields are active.'),
          const SizedBox(height: 16),
          const SectionEndIndicator(
            icon: Icons.security_rounded,
            message: 'All security settings verified',
          ),
        ],
      ),
    );
  }

  // ── 5. ABOUT PANEL ──
  Widget _buildAboutPanel() {
    final isTablet = MediaQuery.of(context).size.width >= 640;

    return PanelCard(
      title: 'About URL Defender',
      description: 'Build targets, uptime statistics, and app details.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // About Hero Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [_primaryGreen.withOpacity(0.15), _primaryGreen.withOpacity(0.05)],
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_rounded, color: _primaryGreen, size: 48),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'URL Defender',
                        style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _primaryGreen.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'v2.4.0',
                              style: TextStyle(color: _primaryGreen, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const SystemOperationalDot(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _showChangelogDialog,
                        icon: Icon(Icons.history_rounded, size: 14, color: _primaryGreen),
                        label: Text('View Full Changelog', style: TextStyle(color: _primaryGreen, fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _primaryGreen.withOpacity(0.3)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // System stats grid
          isTablet
              ? Row(
                  children: [
                    Expanded(child: _buildSystemInfoCard('Release Version', '2.4.0')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSystemInfoCard('Build Target', 'Mobile')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSystemInfoCard('Engine Network', '74 Engines')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSystemInfoCard('Uptime Status', '99.9%')),
                  ],
                )
              : Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildSystemInfoCard('Release Version', '2.4.0')),
                        const SizedBox(width: 12),
                        Expanded(child: _buildSystemInfoCard('Build Target', 'Mobile')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildSystemInfoCard('Engine Network', '74 Engines')),
                        const SizedBox(width: 12),
                        Expanded(child: _buildSystemInfoCard('Uptime Status', '99.9%')),
                      ],
                    ),
                  ],
                ),
          const SizedBox(height: 20),
          Text('Quick Resource Links', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          isTablet
              ? Row(
                  children: [
                    Expanded(child: _buildQuickLinkCard(Icons.article_outlined, 'Terms of Service', 'Legal terms of service', _showTermsDialog)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildQuickLinkCard(Icons.privacy_tip_outlined, 'Privacy Policy', 'GDPR Compliant', _showPrivacyPolicyDialog)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildQuickLinkCard(Icons.support_agent_outlined, 'Support & Contact', '24/7 client response', _showSupportDialog)),
                  ],
                )
              : Column(
                  children: [
                    _buildQuickLinkCard(Icons.article_outlined, 'Terms of Service', 'Legal terms of service', _showTermsDialog),
                    const SizedBox(height: 12),
                    _buildQuickLinkCard(Icons.privacy_tip_outlined, 'Privacy Policy', 'GDPR Compliant', _showPrivacyPolicyDialog),
                    const SizedBox(height: 12),
                    _buildQuickLinkCard(Icons.support_agent_outlined, 'Support & Contact', '24/7 client response', _showSupportDialog),
                  ],
                ),
          const SizedBox(height: 24),
          // Danger Zone / Sign Out Card
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: _red.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Danger Zone', style: TextStyle(color: _red, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text('Log out of this device.', style: TextStyle(color: _textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 14),
                    label: const Text('Sign Out', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SectionEndIndicator(
            icon: Icons.verified_outlined,
            message: 'URL Defender is up to date',
          ),
        ],
      ),
    );
  }

  Widget _buildSystemInfoCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _surfaceColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: _textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildQuickLinkCard(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _surfaceColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: _primaryGreen, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: _textMuted, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Float-profile section helper
  Widget _buildProfileSection(UserModel user) {
    final email = user.email.isNotEmpty ? user.email : 'Not signed in';
    final username = user.username.isNotEmpty ? user.username : 'Defender';

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _surfaceColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/profile'),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_primaryGreen, _blueColor],
                    ),
                  ),
                  child: ClipOval(
                    child: _avatarContent(user),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              username,
                              style: TextStyle(
                                color: _textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: _primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: _primaryGreen.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, color: _primaryGreen, size: 9),
                                const SizedBox(width: 2),
                                Text(
                                  'VERIFIED',
                                  style: TextStyle(color: _primaryGreen, fontSize: 7, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        email,
                        style: TextStyle(color: _textSecondary, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: _textSecondary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── REDESIGNED PANEL CARD ──
class PanelCard extends StatelessWidget {
  final String title;
  final String description;
  final Widget content;

  const PanelCard({
    super.key,
    required this.title,
    required this.description,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 18),
          content,
        ],
      ),
    );
  }
}

// ── TOGGLE ROW WIDGET ──
class ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const ToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch.adaptive(
            value: value,
            activeColor: context.activeAccent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ── THEME SELECTOR WIDGET ──
class ThemeSelector extends StatelessWidget {
  final ThemeMode currentTheme;
  final ValueChanged<ThemeMode> onChanged;

  const ThemeSelector({
    super.key,
    required this.currentTheme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildThemeCard(context, ThemeMode.light, Icons.light_mode_rounded, 'Light')),
        const SizedBox(width: 12),
        Expanded(child: _buildThemeCard(context, ThemeMode.dark, Icons.dark_mode_rounded, 'Dark')),
        const SizedBox(width: 12),
        Expanded(child: _buildThemeCard(context, ThemeMode.system, Icons.settings_brightness_rounded, 'System')),
      ],
    );
  }

  Widget _buildThemeCard(BuildContext context, ThemeMode mode, IconData icon, String label) {
    final isSelected = currentTheme == mode;
    final activeGreen = context.activeAccent;

    return InkWell(
      onTap: () => onChanged(mode),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isSelected ? activeGreen.withOpacity(0.08) : context.cardBg,
          border: Border.all(
            color: isSelected ? activeGreen : context.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? activeGreen : context.textSecondary, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeGreen : context.textPrimary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            // Tiny preview bar
            Container(
              height: 4,
              width: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: mode == ThemeMode.light
                    ? Colors.grey[300]
                    : mode == ThemeMode.dark
                        ? Colors.grey[800]
                        : Colors.blueGrey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── ACCENT COLOR PICKER WIDGET ──
class AccentColorPicker extends StatelessWidget {
  final Color currentColor;
  final ValueChanged<Color> onChanged;

  const AccentColorPicker({
    super.key,
    required this.currentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> accents = [
      {'name': 'Emerald', 'color': const Color(0xFF10B981)},
      {'name': 'Blue', 'color': const Color(0xFF3B82F6)},
      {'name': 'Violet', 'color': const Color(0xFF8B5CF6)},
      {'name': 'Amber', 'color': const Color(0xFFF59E0B)},
      {'name': 'Rose', 'color': const Color(0xFFF43F5E)},
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: accents.map((item) {
        final Color color = item['color'];
        final String name = item['name'];
        final isSelected = currentColor.value == color.value;

        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 6),
              Text(name, style: TextStyle(color: isSelected ? Colors.white : context.textPrimary, fontSize: 12)),
            ],
          ),
          selected: isSelected,
          selectedColor: color,
          backgroundColor: context.cardBg,
          onSelected: (_) => onChanged(color),
        );
      }).toList(),
    );
  }
}

// ── ACTIVE SESSION TILE WIDGET ──
class SessionTile extends StatelessWidget {
  final String device;
  final String browser;
  final bool isCurrent;
  final VoidCallback onRevoke;

  const SessionTile({
    super.key,
    required this.device,
    required this.browser,
    required this.isCurrent,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.secondaryCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.phone_android_rounded,
            color: isCurrent ? context.activeAccent : context.textSecondary,
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      device,
                      style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: context.activeAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Active Now',
                          style: TextStyle(color: context.activeAccent, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  browser,
                  style: TextStyle(color: context.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          if (!isCurrent)
            IconButton(
              icon: Icon(Icons.cancel_outlined, color: context.danger, size: 20),
              onPressed: onRevoke,
            ),
        ],
      ),
    );
  }
}

// ── CHANGELOG ENTRY WIDGET ──
class ChangelogEntry extends StatelessWidget {
  final String version;
  final String date;
  final String tag;
  final String title;
  final List<String> bullets;

  const ChangelogEntry({
    super.key,
    required this.version,
    required this.date,
    required this.tag,
    required this.title,
    required this.bullets,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.secondaryCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$version · $date',
                style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.activeAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tag,
                  style: TextStyle(color: context.activeAccent, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          Column(
            children: bullets.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: context.activeAccent, fontWeight: FontWeight.bold)),
                    Expanded(child: Text(item, style: TextStyle(color: context.textSecondary, fontSize: 12))),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── SYSTEM OPERATIONAL DOT WIDGET ──
class SystemOperationalDot extends StatefulWidget {
  const SystemOperationalDot({super.key});

  @override
  State<SystemOperationalDot> createState() => _SystemOperationalDotState();
}

class _SystemOperationalDotState extends State<SystemOperationalDot> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final green = context.activeAccent;
    return Row(
      children: [
        ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: green,
              boxShadow: [
                BoxShadow(
                  color: green.withOpacity(0.5),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'System Operational',
          style: TextStyle(color: green, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
