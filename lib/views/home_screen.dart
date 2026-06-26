import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/supabase_config.dart';
import '../services/url_scan_service.dart';
import '../models/url_scan_model.dart';
import '../models/user_model.dart';
import '../models/plan_model.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToScan;
  final VoidCallback? onNavigateToAlerts;
  final VoidCallback? onNavigateToSettings;

  const HomeScreen({
    super.key,
    this.onNavigateToScan,
    this.onNavigateToAlerts,
    this.onNavigateToSettings,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
  Color get _bgColor => context.bg;
  Color get _cardColor => context.cardBg;
  Color get _surfaceColor => context.border;
  Color get _primaryGreen => context.activeAccent;
  Color get _amber => context.isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706);
  Color get _red => context.isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626);
  Color get _textPrimary => context.textPrimary;
  Color get _textSecondary => context.textSecondary;
  Color get _textMuted => context.textMuted;

  // Header background: Deep teal/green in light mode, Dark charcoal in dark mode
  Color get _headerBgColor => context.isDark ? const Color(0xFF1E1E1E) : const Color(0xFF0B4C44);

  final _scanService = UrlScanService();

  bool _isLoading = true;
  List<UrlScanModel> _recentScans = [];

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadDashboardData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  String _getFirstName(UserModel? user) {
    if (user != null && user.username.trim().isNotEmpty) {
      return user.username.trim().split(' ').first;
    }
    final email = user?.email ?? SupabaseConfig.client.auth.currentUser?.email ?? '';
    if (email.isNotEmpty) {
      final emailName = email.split('@').first;
      if (emailName.isNotEmpty) {
        final namePart = emailName.split(RegExp(r'[._-]')).first;
        return namePart.substring(0, 1).toUpperCase() + namePart.substring(1);
      }
    }
    return 'Defender';
  }

  String _getAvatarInitial(UserModel? user) {
    final firstName = _getFirstName(user);
    if (firstName.isNotEmpty && firstName != 'Defender') {
      return firstName[0].toUpperCase();
    }
    final email = user?.email ?? SupabaseConfig.client.auth.currentUser?.email ?? '';
    if (email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return 'D';
  }

  void _onAvatarTap() {
    widget.onNavigateToSettings?.call();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;

      final recentScans = userId != null
          ? await _scanService.getRecentScans(userId: userId, limit: 5)
          : <UrlScanModel>[];

      if (!mounted) return;

      setState(() {
        _recentScans = recentScans;
        _isLoading = false;
      });
      _fadeController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _fadeController.forward();
    }
  }


  String _timeAgo(DateTime? dateTime) {
    if (dateTime == null) return '';
    final diff = DateTime.now().difference(dateTime);
    if (diff.isNegative || diff.inSeconds < 5) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: RefreshIndicator(
        color: _primaryGreen,
        backgroundColor: _cardColor,
        onRefresh: _loadDashboardData,
        child: _isLoading ? _buildLoadingState() : _buildContent(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          height: 360,
          decoration: BoxDecoration(
            color: _headerBgColor,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _shimmerBox(width: 140, height: 40, isHeader: true),
                  Row(
                    children: [
                      _shimmerBox(width: 40, height: 40, isHeader: true),
                      const SizedBox(width: 10),
                      _shimmerBox(width: 40, height: 40, isHeader: true),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _shimmerBox(height: 50, isHeader: true),
              const SizedBox(height: 24),
              Expanded(child: _shimmerBox(height: 120, isHeader: true)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shimmerBox(width: 150, height: 22),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _shimmerBox(height: 70)),
                  const SizedBox(width: 12),
                  Expanded(child: _shimmerBox(height: 70)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _shimmerBox(height: 70)),
                  const SizedBox(width: 12),
                  Expanded(child: _shimmerBox(height: 70)),
                ],
              ),
              const SizedBox(height: 32),
              _shimmerBox(width: 180, height: 22),
              const SizedBox(height: 16),
              SizedBox(
                height: 170,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _shimmerBox(width: 220, height: 170),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _shimmerBox({double? width, double height = 20, bool isHeader = false}) {
    final baseColor = isHeader
        ? Colors.white.withValues(alpha: 0.12)
        : _cardColor;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  bool get _hasUnreadNotifications => _recentScans.any((scan) => !scan.isSafe);

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good Morning,';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon,';
    } else {
      return 'Good Evening,';
    }
  }

  void _showQuickNavSheet(BuildContext ctx) {
    final isDark = ctx.isDark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary = isDark ? const Color(0xFF8E8E93) : const Color(0xFF475569);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);
    final primaryGreen = const Color(0xFF1A7A3A);

    final navItems = [
      _NavItem('Quick Scan', 'Scan any URL for threats', Icons.qr_code_scanner_rounded, primaryGreen, () {
        Navigator.pop(ctx);
        widget.onNavigateToScan?.call();
      }),
      _NavItem('Threat Alerts', 'View dangerous URL detections', Icons.notifications_active_outlined, const Color(0xFFF59E0B), () {
        Navigator.pop(ctx);
        widget.onNavigateToAlerts?.call();
      }),
      _NavItem('Scan History', 'Browse all previous scans', Icons.history_rounded, const Color(0xFF6366F1), () {
        Navigator.pop(ctx);
        ctx.push('/history');
      }),
      _NavItem('Blocked URLs', 'Manage blocked domains', Icons.block_rounded, const Color(0xFFEF4444), () {
        Navigator.pop(ctx);
        ctx.push('/blocked_list');
      }),
      _NavItem('Settings', 'App preferences & profile', Icons.settings_rounded, const Color(0xFF8B5CF6), () {
        Navigator.pop(ctx);
        widget.onNavigateToSettings?.call();
      }),
      _NavItem('Premium', 'Upgrade for unlimited scans', Icons.workspace_premium_rounded, const Color(0xFFFFD700), () {
        Navigator.pop(ctx);
        ctx.push('/premium');
      }),
    ];

    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Row(
                  children: [
                    Icon(Icons.explore_rounded, color: primaryGreen, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Quick Navigate',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              ...navItems.map((item) => _buildNavTile(item, textPrimary, textSecondary, borderColor)),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavTile(_NavItem item, Color textPrimary, Color textSecondary, Color borderColor) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: textSecondary.withValues(alpha: 0.4),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeroHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQuickToolsSection(),
                const SizedBox(height: 32),
                _buildRecentScansSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _headerBgColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Consumer(
            builder: (context, ref, child) {
              final user = ref.watch(userProvider);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _UserAvatar(
                    user: user,
                    onTap: _onAvatarTap,
                    getAvatarInitial: _getAvatarInitial,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getTimeBasedGreeting(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getFirstName(user).toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _NotificationButton(
                    onTap: widget.onNavigateToAlerts,
                    hasBadge: _hasUnreadNotifications,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _AnimatedSearchBar(
            isDark: context.isDark,
            onTap: () => _showQuickNavSheet(context),
          ),
          const SizedBox(height: 24),
          const SubscriptionDashboardCard(),
        ],
      ),
    );
  }

  Widget _buildQuickToolsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Tools',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _QuickToolCard(
                title: 'Quick Scan',
                icon: Icons.qr_code_scanner_rounded,
                iconBg: _primaryGreen.withValues(alpha: 0.12),
                iconColor: _primaryGreen,
                onTap: () => widget.onNavigateToScan?.call(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickToolCard(
                title: 'Threat Alerts',
                icon: Icons.notifications_active_outlined,
                iconBg: _amber.withValues(alpha: 0.12),
                iconColor: _amber,
                onTap: () => widget.onNavigateToAlerts?.call(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickToolCard(
                title: 'Blocked List',
                icon: Icons.block_rounded,
                iconBg: _red.withValues(alpha: 0.12),
                iconColor: _red,
                onTap: () => context.push('/blocked_list'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickToolCard(
                title: 'Premium Upgrade',
                icon: Icons.star_rounded,
                iconBg: const Color(0xFFFBBF24).withValues(alpha: 0.12),
                iconColor: const Color(0xFFF59E0B),
                onTap: () => context.push('/premium'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentScansSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Security Checks',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            GestureDetector(
              onTap: () => context.push('/history'),
              child: Row(
                children: [
                  Text(
                    'View all',
                    style: TextStyle(
                      color: _primaryGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: _primaryGreen,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _recentScans.isEmpty ? _buildHorizontalEmptyState() : _buildHorizontalRecentList(),
      ],
    );
  }

  Widget _buildHorizontalEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _surfaceColor),
      ),
      child: Column(
        children: [
          Icon(Icons.shield_outlined, size: 48, color: _textMuted),
          const SizedBox(height: 12),
          Text(
            'No Scans Yet',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Click Scan Tab to analyze your first URL.',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalRecentList() {
    return SizedBox(
      height: 175,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _recentScans.length,
        itemBuilder: (context, index) {
          final scan = _recentScans[index];
          final isSafe = scan.isSafe;
          final resultColor = isSafe ? _primaryGreen : _red;
          final riskScore = scan.riskScore ?? 0;

          return Container(
            width: 220,
            margin: const EdgeInsets.only(right: 14, bottom: 4),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _surfaceColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 75,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isSafe
                          ? [const Color(0xFF0B4C44).withValues(alpha: 0.85), const Color(0xFF064E3B).withValues(alpha: 0.7)]
                          : [const Color(0xFF7F1D1D).withValues(alpha: 0.85), const Color(0xFF991B1B).withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSafe ? Icons.gpp_good_rounded : Icons.gpp_maybe_rounded,
                              size: 12,
                              color: isSafe ? const Color(0xFF5CED73) : const Color(0xFFFF4D4D),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Risk: $riskScore%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isSafe ? Icons.verified_user_rounded : Icons.warning_rounded,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 22,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scan.scannedUrl,
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: resultColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isSafe ? 'Safe' : 'Threat',
                              style: TextStyle(
                                color: resultColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            _timeAgo(scan.scannedAt),
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuickToolCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;

  const _QuickToolCard({
    required this.title,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = context.cardBg;
    final textPrimary = context.textPrimary;
    final textMuted = context.textMuted;
    final border = context.border;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: textMuted.withValues(alpha: 0.6),
              size: 12,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserAvatar extends StatefulWidget {
  final UserModel? user;
  final VoidCallback onTap;
  final String Function(UserModel?) getAvatarInitial;

  const _UserAvatar({
    required this.user,
    required this.onTap,
    required this.getAvatarInitial,
  });

  @override
  State<_UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<_UserAvatar> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _scale = 0.9;
        });
      },
      onTapUp: (_) {
        setState(() {
          _scale = 1.0;
        });
      },
      onTapCancel: () {
        setState(() {
          _scale = 1.0;
        });
      },
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1A7A3A),
                Color(0xFF1B5E20),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
                spreadRadius: 1,
              ),
              BoxShadow(
                color: const Color(0xFF1A7A3A).withValues(alpha: 0.3),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: Stack(
              children: [
                Positioned(
                  top: -15,
                  left: -15,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    widget.getAvatarInitial(widget.user).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
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

class _NotificationButton extends StatefulWidget {
  final VoidCallback? onTap;
  final bool hasBadge;

  const _NotificationButton({this.onTap, required this.hasBadge});

  @override
  State<_NotificationButton> createState() => _NotificationButtonState();
}

class _NotificationButtonState extends State<_NotificationButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _scale = 0.92;
        });
      },
      onTapUp: (_) {
        setState(() {
          _scale = 1.0;
        });
      },
      onTapCancel: () {
        setState(() {
          _scale = 1.0;
        });
      },
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            if (widget.hasBadge)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A7A3A),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SubscriptionDashboardCard extends ConsumerStatefulWidget {
  const SubscriptionDashboardCard({super.key});

  @override
  ConsumerState<SubscriptionDashboardCard> createState() => _SubscriptionDashboardCardState();
}

class _SubscriptionDashboardCardState extends ConsumerState<SubscriptionDashboardCard> {
  Timer? _timer;
  bool _isDowngrading = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkSubscriptionStatus();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSubscriptionStatus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _checkSubscriptionStatus() {
    if (!mounted) return;
    final user = ref.read(userProvider);
    if (user != null && user.isPremium && !_isDowngrading) {
      final subscription = ref.read(subscriptionProvider).valueOrNull;
      if (subscription != null && subscription.expiryDate != null) {
        final difference = subscription.expiryDate!.difference(DateTime.now());
        if (difference.isNegative || difference.inSeconds <= 0) {
          _isDowngrading = true;
          _handleDowngrade(user.userId);
        } else {
          setState(() {});
        }
      }
    }
  }

  Future<void> _handleDowngrade(String userId) async {
    try {
      final userService = ref.read(userServiceProvider);
      await userService.updateUser(userId, {'is_premium': false});
      await SupabaseConfig.client
          .from('subscriptions')
          .update({'status': 'expired'})
          .eq('user_id', userId)
          .eq('status', 'active');
      await ref.read(userProvider.notifier).refreshUser();
      ref.invalidate(subscriptionProvider);
      ref.invalidate(scanLimitProvider);
      if (mounted) {
        setState(() {
          _isDowngrading = false;
        });
      }
    } catch (e) {
      debugPrint('Error downgrading: $e');
      if (mounted) {
        setState(() {
          _isDowngrading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UserModel?>(userProvider, (previous, next) {
      if (next != null && next.isPremium && !(previous?.isPremium ?? false)) {
        setState(() {
          _isDowngrading = false;
        });
      }
    });

    final user = ref.watch(userProvider);
    final subscriptionAsync = ref.watch(subscriptionProvider);
    final scanLimitAsync = ref.watch(scanLimitProvider);
    // Weekly scan limit is hardcoded to 1 (no longer fetched from settings)
    final plansAsync = ref.watch(planProvider);

    final isPremium = user?.isPremium ?? false;
    final remainingScans = scanLimitAsync.valueOrNull ?? 0;
    final lifetimeScans = user?.lifetimeScanCount ?? 0;
    final isInitialPhase = lifetimeScans < 15;

    if (user != null && isPremium) {
      subscriptionAsync.whenData((subscription) {
        if (subscription == null && !_isDowngrading) {
          _isDowngrading = true;
          _handleDowngrade(user.userId);
        }
      });
    }

    String planName = isPremium ? 'PLUS' : 'FREE PLAN';
    String planTier = 'free'; // 'free', 'monthly', 'yearly'
    final subscription = subscriptionAsync.valueOrNull;
    if (isPremium && subscription != null) {
      final plans = plansAsync.valueOrNull ?? [];
      final activePlan = plans.firstWhere(
        (p) => p.planId == subscription.planId,
        orElse: () => PlanModel(planId: '', name: 'PLUS', durationMonths: 0, price: 0),
      );
      planName = activePlan.name.toUpperCase();
      // Determine tier based on plan name
      if (activePlan.name.toLowerCase().contains('year')) {
        planTier = 'yearly';
      } else {
        planTier = 'monthly';
      }
    }

    String daysStr = '00';
    String hoursStr = '00';
    String minutesStr = '00';
    String secondsStr = '00';
    bool showExpiryWarning = false;

    if (isPremium && subscription != null && subscription.expiryDate != null) {
      final difference = subscription.expiryDate!.difference(DateTime.now());
      if (!difference.isNegative) {
        final days = difference.inDays;
        final hours = difference.inHours % 24;
        final minutes = difference.inMinutes % 60;
        final seconds = difference.inSeconds % 60;

        daysStr = days.toString().padLeft(2, '0');
        hoursStr = hours.toString().padLeft(2, '0');
        minutesStr = minutes.toString().padLeft(2, '0');
        secondsStr = seconds.toString().padLeft(2, '0');

        // Only show expiry warning when within 2 days
        showExpiryWarning = difference.inDays <= 2;
      }
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          if (isPremium)
            BoxShadow(
              color: const Color(0xFF1A7A3A).withValues(alpha: 0.16),
              blurRadius: 36,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF141614).withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1.2,
              ),
            ),
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A7A3A).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF1A7A3A).withValues(alpha: 0.7),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1A7A3A).withValues(alpha: 0.12),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  size: 13,
                                  color: Color(0xFF5CED73),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'SHIELD ACTIVE',
                                  style: TextStyle(
                                    color: Color(0xFF5CED73),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'URL DEFENDER',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  planName,
                                  style: TextStyle(
                                    color: isPremium ? const Color(0xFF5CED73) : Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isPremium) ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A7A3A).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFF5CED73).withValues(alpha: 0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '👑',
                                        style: TextStyle(fontSize: 10),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'PREMIUM',
                                        style: TextStyle(
                                          color: Color(0xFF5CED73),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.04),
                                  border: Border.all(
                                    color: const Color(0xFF1A7A3A).withValues(alpha: 0.25),
                                    width: 1.2,
                                  ),
                                ),
                                child: Icon(
                                  isPremium ? Icons.all_inclusive_rounded : Icons.donut_large_rounded,
                                  color: const Color(0xFF5CED73),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Remaining Scans',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.45),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 300),
                                      transitionBuilder: (child, animation) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: SlideTransition(
                                            position: Tween<Offset>(
                                              begin: const Offset(0.0, 0.25),
                                              end: Offset.zero,
                                            ).animate(animation),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: Text(
                                        isPremium
                                            ? '∞ Unlimited'
                                            : (isInitialPhase
                                                ? '$remainingScans / 15 remaining'
                                                : '$remainingScans / 1 weekly'),
                                        key: ValueKey<String>(isPremium
                                            ? 'unlim'
                                            : (isInitialPhase
                                                ? '$remainingScans-initial'
                                                : '$remainingScans-weekly')),
                                        style: TextStyle(
                                          color: isPremium ? const Color(0xFF5CED73) : Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    if (!isPremium && isInitialPhase) ...[
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(2),
                                        child: SizedBox(
                                          width: 100,
                                          child: LinearProgressIndicator(
                                            value: (remainingScans / 15.0).clamp(0.0, 1.0),
                                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5CED73)),
                                            minHeight: 4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (isPremium && showExpiryWarning) ...[
                            const SizedBox(height: 18),
                            Container(
                              height: 1,
                              width: double.infinity,
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Subscription Expires In',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildCountdownCard(daysStr, 'Days'),
                                _buildColonSeparator(),
                                _buildCountdownCard(hoursStr, 'Hours'),
                                _buildColonSeparator(),
                                _buildCountdownCard(minutesStr, 'Minutes'),
                                _buildColonSeparator(),
                                _buildCountdownCard(secondsStr, 'Seconds'),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _RenewButton(
                              onTap: () {
                                context.push('/premium');
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          const SizedBox(height: 24),
                          DynamicSubscriptionArtwork(planTier: planTier),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFeatureItem(Icons.gpp_good_rounded, 'Unlimited\nProtection'),
                      _buildVerticalDivider(),
                      _buildFeatureItem(Icons.bolt_rounded, 'Real-time\nScanning'),
                      _buildVerticalDivider(),
                      _buildFeatureItem(Icons.lock_rounded, 'Advanced\nSecurity'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownCard(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF1A7A3A).withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A7A3A).withValues(alpha: 0.05),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: animation,
                  child: child,
                ),
              );
            },
            child: Text(
              value,
              key: ValueKey<String>(value),
              style: const TextStyle(
                color: Color(0xFF5CED73),
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildColonSeparator() {
    return const Padding(
      padding: EdgeInsets.only(left: 4, right: 4, bottom: 12),
      child: Text(
        ':',
        style: TextStyle(
          color: Colors.white24,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF5CED73)),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 20,
      width: 1,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}

class _RenewButton extends StatefulWidget {
  final VoidCallback onTap;
  const _RenewButton({required this.onTap});

  @override
  State<_RenewButton> createState() => _RenewButtonState();
}

class _RenewButtonState extends State<_RenewButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1A7A3A),
                Color(0xFF1B5E20),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A7A3A).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: const [
              Text(
                '👑',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(width: 12),
              Text(
                'RENEW NOW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              Spacer(),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DynamicSubscriptionArtwork extends StatefulWidget {
  final String planTier; // 'free', 'monthly', 'yearly'
  const DynamicSubscriptionArtwork({super.key, required this.planTier});

  bool get isPremium => planTier != 'free';

  // Tier-based colors
  // Bronze (free): warm brownish tone
  // Silver (monthly): cool silver/grey metallic
  // Gold (yearly): rich gold
  Color get tierColor {
    switch (planTier) {
      case 'yearly':
        return const Color(0xFFFFD700); // Gold
      case 'monthly':
        return const Color(0xFFC0C0C0); // Silver
      default:
        return const Color(0xFFCD7F32); // Bronze
    }
  }

  Color get tierColorDark {
    switch (planTier) {
      case 'yearly':
        return const Color(0xFFB8860B); // Dark gold
      case 'monthly':
        return const Color(0xFF808080); // Dark silver
      default:
        return const Color(0xFF8B4513); // Dark bronze
    }
  }

  Color get tierGlowColor {
    switch (planTier) {
      case 'yearly':
        return const Color(0xFFFFD700);
      case 'monthly':
        return const Color(0xFFB0C4DE);
      default:
        return const Color(0xFF1A7A3A);
    }
  }

  @override
  State<DynamicSubscriptionArtwork> createState() => _DynamicSubscriptionArtworkState();
}

class _DynamicSubscriptionArtworkState extends State<DynamicSubscriptionArtwork> with TickerProviderStateMixin {
  late final AnimationController _floatingController;
  late final AnimationController _rotatingController;

  @override
  void initState() {
    super.initState();
    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _rotatingController = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _floatingController.dispose();
    _rotatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final yOffsetAnimation = Tween<double>(begin: -5, end: 5).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );

    return AnimatedBuilder(
      animation: _rotatingController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            CustomPaint(
              size: const Size(130, 130),
              painter: _HolographicRingPainter(
                planTier: widget.planTier,
                animationValue: _rotatingController.value,
              ),
            ),
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.isPremium
                        ? widget.tierGlowColor.withValues(alpha: 0.45)
                        : const Color(0xFF1A7A3A).withValues(alpha: 0.2),
                    blurRadius: widget.isPremium ? 36 : 22,
                    spreadRadius: widget.isPremium ? 10 : 2,
                  ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _floatingController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, yOffsetAnimation.value),
                  child: child,
                );
              },
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  CustomPaint(
                    size: const Size(80, 92),
                    painter: _ShieldPainter(planTier: widget.planTier),
                  ),
                  Positioned(
                    top: 22,
                    child: Icon(
                      Icons.workspace_premium_rounded,
                      size: 40,
                      color: widget.tierColor,
                      shadows: [
                        Shadow(
                          color: widget.tierGlowColor.withValues(alpha: 0.6),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                  if (widget.isPremium) ...[
                    Positioned(
                      top: -18,
                      child: Transform.rotate(
                        angle: 0.05,
                        child: AnimatedBuilder(
                          animation: _floatingController,
                          builder: (context, child) {
                            final crownOffset = math.sin(_floatingController.value * math.pi) * 2;
                            return Transform.translate(
                              offset: Offset(0, crownOffset),
                              child: child,
                            );
                          },
                          child: Text(
                            '👑',
                            style: TextStyle(
                              fontSize: 28,
                              shadows: [
                                Shadow(
                                  color: widget.tierGlowColor,
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (!widget.isPremium) ...[
                    Positioned(
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A7A3A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF5CED73),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1A7A3A).withValues(alpha: 0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Text(
                          'FREE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ShieldPainter extends CustomPainter {
  final String planTier;
  const _ShieldPainter({required this.planTier});

  bool get isPremium => planTier != 'free';

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(w / 2, 0);
    path.quadraticBezierTo(w * 0.75, h * 0.05, w, h * 0.15);
    path.quadraticBezierTo(w * 0.95, h * 0.65, w / 2, h);
    path.quadraticBezierTo(w * 0.05, h * 0.65, 0, h * 0.15);
    path.quadraticBezierTo(w * 0.25, h * 0.05, w / 2, 0);
    path.close();

    if (isPremium) {
      paint.shader = RadialGradient(
        colors: [
          const Color(0xFF1B5E20),
          const Color(0xFF0F3214),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

      // Use tier-specific border colors
      if (planTier == 'yearly') {
        // Gold metallic border
        borderPaint.shader = LinearGradient(
          colors: [
            const Color(0xFFFFD700),
            const Color(0xFFB8860B),
            const Color(0xFFFFD700),
            const Color(0xFFDAA520),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0, 0, w, h));
      } else {
        // Silver metallic border
        borderPaint.shader = LinearGradient(
          colors: [
            Colors.white,
            Colors.grey.shade400,
            Colors.white,
            Colors.grey.shade600,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0, 0, w, h));
      }
    } else {
      paint.color = const Color(0xFF141614);
      borderPaint.color = const Color(0xFFCD7F32); // Bronze border for free
    }

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HolographicRingPainter extends CustomPainter {
  final String planTier;
  final double animationValue;

  const _HolographicRingPainter({
    required this.planTier,
    required this.animationValue,
  });

  bool get isPremium => planTier != 'free';

  Color get _ringColor {
    switch (planTier) {
      case 'yearly':
        return const Color(0xFFFFD700); // Gold
      case 'monthly':
        return const Color(0xFFC0C0C0); // Silver
      default:
        return const Color(0xFF1A7A3A); // Green for free
    }
  }

  Color get _particleColor {
    switch (planTier) {
      case 'yearly':
        return const Color(0xFFFFD700);
      case 'monthly':
        return const Color(0xFFB0C4DE);
      default:
        return const Color(0xFF5CED73);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    if (isPremium) {
      paint.color = _ringColor.withValues(alpha: 0.25);
      canvas.drawCircle(center, w / 2, paint);

      paint.color = _ringColor.withValues(alpha: 0.35);
      paint.strokeWidth = 1.5;
      final double radius = w / 2.3;
      const int segments = 40;
      final double segmentAngle = (2 * math.pi) / segments;
      
      final double rotationOffset = animationValue * 2 * math.pi;

      for (int i = 0; i < segments; i++) {
        if (i % 2 == 0) {
          final double startAngle = i * segmentAngle + rotationOffset;
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: radius),
            startAngle,
            segmentAngle,
            false,
            paint,
          );
        }
      }

      final dotPaint = Paint()..style = PaintingStyle.fill;
      final List<double> particleAngles = [0.2, 1.0, 1.8, 2.6, 3.4, 4.2, 5.0, 5.8];
      final List<double> particleSpeeds = [1.2, 0.8, 1.5, 1.0, 1.3, 0.9, 1.4, 1.1];
      final List<double> particleRadii = [2.2, 1.5, 2.5, 1.8, 2.2, 1.6, 2.4, 1.7];

      for (int i = 0; i < particleAngles.length; i++) {
        final double progress = (animationValue * particleSpeeds[i]) % 1.0;
        final double currentRadius = radius + (w / 2 - radius) * progress;
        final double angle = particleAngles[i] + (animationValue * 0.4);
        
        final double x = center.dx + currentRadius * math.cos(angle);
        final double y = center.dy + currentRadius * math.sin(angle);
        
        final double opacity = (1.0 - progress) * 0.7;
        dotPaint.color = _particleColor.withValues(alpha: opacity);
        
        canvas.drawCircle(Offset(x, y), particleRadii[i], dotPaint);
      }
    } else {
      paint.color = const Color(0xFFCD7F32).withValues(alpha: 0.2);
      canvas.drawCircle(center, w / 2.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HolographicRingPainter oldDelegate) {
    return oldDelegate.planTier != planTier || oldDelegate.animationValue != animationValue;
  }
}

// ─────────────────── Navigation Item Model ───────────────────

class _NavItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _NavItem(this.title, this.subtitle, this.icon, this.color, this.onTap);
}

// ─────────────────── Animated Search Bar ───────────────────

class _AnimatedSearchBar extends StatefulWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _AnimatedSearchBar({required this.isDark, required this.onTap});

  @override
  State<_AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<_AnimatedSearchBar> with SingleTickerProviderStateMixin {
  static const _hints = [
    'Search Quick Scan...',
    'Search Threat Alerts...',
    'Search Settings...',
    'Search Blocked URLs...',
    'Search Scan History...',
    'Search Premium Plans...',
  ];

  int _currentIndex = 0;
  late final AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<double> _fadeOut;
  late Animation<Offset> _slideIn;
  late Animation<Offset> _slideOut;
  Timer? _rotateTimer;

  @override
  void initState() {
    super.initState();
    // Randomize starting index
    _currentIndex = math.Random().nextInt(_hints.length);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.5, 1.0, curve: Curves.easeIn)),
    );
    _slideIn = Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _slideOut = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -0.6)).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.5, 1.0, curve: Curves.easeIn)),
    );

    _rotateTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      _animController.forward().then((_) {
        if (!mounted) return;
        setState(() {
          _currentIndex = (_currentIndex + 1) % _hints.length;
        });
        _animController.reset();
      });
    });
  }

  @override
  void dispose() {
    _rotateTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hintColor = widget.isDark ? const Color(0xFF8E8E93) : const Color(0xFF475569).withValues(alpha: 0.7);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: widget.isDark ? const Color(0xFF8E8E93) : const Color(0xFF475569),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  final isFirstHalf = _animController.value <= 0.5;
                  return FractionalTranslation(
                    translation: isFirstHalf ? _slideOut.value : _slideIn.value,
                    child: Opacity(
                      opacity: isFirstHalf ? _fadeOut.value : _fadeIn.value,
                      child: Text(
                        isFirstHalf
                            ? _hints[_currentIndex]
                            : _hints[(_currentIndex + 1) % _hints.length],
                        style: TextStyle(
                          color: hintColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: widget.isDark ? const Color(0xFF8E8E93).withValues(alpha: 0.5) : const Color(0xFF475569).withValues(alpha: 0.3),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}