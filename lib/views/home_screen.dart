import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/url_scan_service.dart';
import '../models/url_scan_model.dart';
import '../models/user_model.dart';
import '../models/plan_model.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app/notification_bell.dart';
import 'premium_screen.dart';

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

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  Color get _bgColor => context.bg;
  Color get _cardColor => context.cardBg;
  Color get _surfaceColor => context.border;
  Color get _primaryGreen => context.activeAccent;
  Color get _amber => context.warning;
  Color get _red => context.danger;
  Color get _textPrimary => context.textPrimary;
  Color get _textSecondary => context.textSecondary;
  Color get _textMuted => context.textMuted;

  // Header background: Deep teal/green in light mode, Dark charcoal in dark mode
  Color get _headerBgColor =>
      context.isDark ? const Color(0xFF1E1E1E) : const Color(0xFF0B4C44);

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
    final email = user?.email ?? ref.read(userProvider)?.email ?? '';
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
    final email = user?.email ?? ref.read(userProvider)?.email ?? '';
    if (email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return 'D';
  }

  void _onAvatarTap() {
    context.push('/profile');
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final userId = ref.read(userProvider)?.userId;

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
    ref.watch(recentScansProvider).whenData((scans) {
      _recentScans = scans;
    });

    return Scaffold(
      backgroundColor: _bgColor,
      body: RefreshIndicator(
        color: _primaryGreen,
        backgroundColor: _cardColor,
        onRefresh: () async {
          ref.invalidate(recentScansProvider);
          await _loadDashboardData();
        },
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

  Widget _shimmerBox({
    double? width,
    double height = 20,
    bool isHeader = false,
  }) {
    final baseColor = isHeader
        ? Colors.white.withOpacity(0.12)
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
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final borderColor = context.border;
    final primaryGreen = context.activeAccent;

    final navItems = [
      _NavItem(
        'Quick Scan',
        'Scan any URL for threats',
        Icons.qr_code_scanner_rounded,
        primaryGreen,
        () {
          Navigator.pop(ctx);
          widget.onNavigateToScan?.call();
        },
      ),
      _NavItem(
        'Threat Alerts',
        'View dangerous URL detections',
        Icons.notifications_active_outlined,
        context.warning,
        () {
          Navigator.pop(ctx);
          ref.read(alertsTabProvider.notifier).state = 0;
          widget.onNavigateToAlerts?.call();
        },
      ),
      _NavItem(
        'Scan History',
        'Browse all previous scans',
        Icons.history_rounded,
        context.information,
        () {
          Navigator.pop(ctx);
          ref.read(alertsTabProvider.notifier).state = 1;
          widget.onNavigateToAlerts?.call();
        },
      ),
      _NavItem(
        'Blocked URLs',
        'Manage blocked domains',
        Icons.block_rounded,
        const Color(0xFFEF4444),
        () {
          Navigator.pop(ctx);
          ctx.push('/blocked_list');
        },
      ),
      _NavItem(
        'Settings',
        'App preferences & profile',
        Icons.settings_rounded,
        const Color(0xFF8B5CF6),
        () {
          Navigator.pop(ctx);
          widget.onNavigateToSettings?.call();
        },
      ),
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
                color: Colors.black.withOpacity(0.15),
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
                  color: textSecondary.withOpacity(0.3),
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
              ...navItems.map(
                (item) => _buildNavTile(
                  item,
                  textPrimary,
                  textSecondary,
                  borderColor,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavTile(
    _NavItem item,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
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
                  color: item.color.withOpacity(0.12),
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
                color: textSecondary.withOpacity(0.4),
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
        padding: const EdgeInsets.fromLTRB(24, 56, 24, 126),
        children: [
          _buildHeroHeader(),
          const SizedBox(height: 24),
          _buildQuickToolsSection(),
          const SizedBox(height: 24),
          _buildRecentScansSection(),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Consumer(
          builder: (context, ref, child) {
            final user = ref.watch(userProvider);
            final displayName = user?.username.trim() ?? 'Nexabot';
            final rawFirstName = displayName.split(' ').first;
            String firstName = '';
            if (rawFirstName.isNotEmpty) {
              firstName = rawFirstName[0].toUpperCase() + rawFirstName.substring(1).toLowerCase();
            }
            firstName = '$firstName..';
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _UserAvatar(
                  user: user,
                  onTap: _onAvatarTap,
                  getAvatarInitial: _getAvatarInitial,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getTimeBasedGreeting(),
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        firstName,
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const NotificationBell(),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        _AnimatedSearchBar(
          isDark: context.isDark,
          onTap: () => _showQuickNavSheet(context),
        ),
        const SizedBox(height: 20),
        const _DashboardSecurityCard(),
      ],
    );
  }

  Widget _buildQuickToolsSection() {
    final isDark = context.isDark;

    Widget toolsContent;
    if (isDark) {
      // Dark Mode Layout: Stacked vertically
      toolsContent = Column(
        children: [
          _QuickToolCard(
            title: 'Quick Scan',
            icon: Icons.qr_code_scanner_rounded,
            iconBg: _primaryGreen.withOpacity(0.12),
            iconColor: _primaryGreen,
            onTap: () => widget.onNavigateToScan?.call(),
          ),
          const SizedBox(height: 12),
          _QuickToolCard(
            title: 'Threat Alerts',
            icon: Icons.notifications_active_outlined,
            iconBg: _amber.withOpacity(0.12),
            iconColor: _amber,
            onTap: () {
              ref.read(alertsTabProvider.notifier).state = 0;
              widget.onNavigateToAlerts?.call();
            },
          ),
          const SizedBox(height: 12),
          _QuickToolCard(
            title: 'Blocked List',
            icon: Icons.block_rounded,
            iconBg: _red.withOpacity(0.12),
            iconColor: _red,
            onTap: () => context.push('/blocked_list'),
          ),
          const SizedBox(height: 12),
          _QuickToolCard(
            title: 'Community Threats',
            icon: Icons.public_outlined,
            iconBg: Colors.teal.withOpacity(0.12),
            iconColor: Colors.teal,
            onTap: () => context.push('/community-reports'),
          ),
        ],
      );
    } else {
      // Light Mode Layout: Row 1 side-by-side, Row 2 side-by-side
      toolsContent = Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _QuickToolCard(
                  title: 'Quick Scan',
                  icon: Icons.qr_code_scanner_rounded,
                  iconBg: _primaryGreen.withOpacity(0.12),
                  iconColor: _primaryGreen,
                  onTap: () => widget.onNavigateToScan?.call(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickToolCard(
                  title: 'Threat Alerts',
                  icon: Icons.notifications_active_outlined,
                  iconBg: _amber.withOpacity(0.12),
                  iconColor: _amber,
                  onTap: () {
                    ref.read(alertsTabProvider.notifier).state = 0;
                    widget.onNavigateToAlerts?.call();
                  },
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
                  iconBg: _red.withOpacity(0.12),
                  iconColor: _red,
                  onTap: () => context.push('/blocked_list'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickToolCard(
                  title: 'Community Threats',
                  icon: Icons.public_outlined,
                  iconBg: Colors.teal.withOpacity(0.12),
                  iconColor: Colors.teal,
                  onTap: () => context.push('/community-reports'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 14),
        toolsContent,
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
              onTap: () {
                ref.read(alertsTabProvider.notifier).state = 1;
                widget.onNavigateToAlerts?.call();
              },
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
        _recentScans.isEmpty
            ? _buildHorizontalEmptyState()
            : _buildHorizontalRecentList(),
      ],
    );
  }

  Widget _buildHorizontalEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _surfaceColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
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
            'Tap Quick Scan to analyze your first URL.',
            style: TextStyle(color: _textSecondary, fontSize: 13),
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
                  color: Colors.black.withOpacity(0.04),
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
                          ? [
                              const Color(0xFF0B4C44).withOpacity(0.85),
                              const Color(0xFF064E3B).withOpacity(0.7),
                            ]
                          : [
                              const Color(0xFF7F1D1D).withOpacity(0.85),
                              const Color(0xFF991B1B).withOpacity(0.7),
                            ],
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSafe
                                  ? Icons.gpp_good_rounded
                                  : Icons.gpp_maybe_rounded,
                              size: 12,
                              color: isSafe
                                  ? const Color(0xFF5CED73)
                                  : const Color(0xFFFF4D4D),
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
                        isSafe
                            ? Icons.verified_user_rounded
                            : Icons.warning_rounded,
                        color: Colors.white.withOpacity(0.9),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: resultColor.withOpacity(0.12),
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

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: context.cardBg,
            shape: BoxShape.circle,
            border: Border.all(color: context.border),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, color: context.textPrimary, size: 22),
        ),
      ),
    );
  }
}

class _DashboardSecurityCard extends ConsumerWidget {
  const _DashboardSecurityCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final remainingScans = ref.watch(scanLimitProvider).valueOrNull ?? 0;
    const totalScans = 50;
    final usedScans = (totalScans - remainingScans).clamp(0, totalScans);
    final progress = usedScans / totalScans;
    final isPremium = user?.isPremium ?? false;
    final planLabel = isPremium ? 'PREMIUM' : 'FREE PLAN';
    final tierLabel = isPremium ? 'PREMIUM' : 'FREE';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF071A12), Color(0xFF0D241B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppPalette.darkAccentGreen.withOpacity(0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22C55E).withOpacity(0.18),
            blurRadius: 45,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShieldActivePill(),
                    const SizedBox(height: 16),
                    Text(
                      'URL DEFENDER',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      planLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppPalette.darkWarning),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_outlined,
                      color: AppPalette.darkWarning,
                      size: 27,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppPalette.darkWarning.withOpacity(0.8),
                      ),
                    ),
                    child: Text(
                      tierLabel,
                      style: const TextStyle(
                        color: AppPalette.darkWarning,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 4,
                color: AppPalette.darkAccentGreen,
                backgroundColor: Colors.white.withOpacity(0.13),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '$usedScans of $totalScans scans used',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PremiumScreen()),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF3B82F6),
                  minimumSize: Size.zero,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Upgrade →',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: const [
              Expanded(
                child: _SecurityFeature(
                  icon: Icons.shield_outlined,
                  label: 'Unlimited\nProtection',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _SecurityFeature(
                  icon: Icons.bolt_rounded,
                  label: 'Real-time\nScanning',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _SecurityFeature(
                  icon: Icons.lock_outline_rounded,
                  label: 'Advanced\nSecurity',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShieldActivePill extends StatefulWidget {
  @override
  State<_ShieldActivePill> createState() => _ShieldActivePillState();
}

class _ShieldActivePillState extends State<_ShieldActivePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF14532D),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFF39FF88,
              ).withOpacity(0.12 + (_controller.value * 0.14)),
              blurRadius: 12 + (_controller.value * 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shield_outlined,
              color: AppPalette.darkAccentGreen,
              size: 15,
            ),
            SizedBox(width: 6),
            Text(
              'SHIELD ACTIVE',
              style: TextStyle(
                color: AppPalette.darkAccentGreen,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityFeature extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SecurityFeature({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppPalette.darkAccentGreen, size: 18),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
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
              color: textMuted.withOpacity(0.6),
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
    final avatarUrl = widget.user?.avatarUrl;
    Widget? avatarImage;
    if (avatarUrl != null && avatarUrl.startsWith('http')) {
      avatarImage = Image.network(
        avatarUrl,
        key: ValueKey(avatarUrl),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    } else if (avatarUrl != null && avatarUrl.startsWith('data:image/')) {
      try {
        avatarImage = Image.memory(
          base64Decode(avatarUrl.split(',').last),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
      } catch (_) {}
    }

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
              colors: [Color(0xFF14532D), Color(0xFF22C55E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
                spreadRadius: 1,
              ),
              BoxShadow(
                color: const Color(0xFF22C55E).withOpacity(0.3),
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
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
                if (avatarImage != null)
                  Positioned.fill(child: avatarImage)
                else
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
                color: context.cardBg,
                border: Border.all(color: context.border, width: 1),
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                color: context.textPrimary,
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
                    color: Color(0xFF22C55E),
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

enum PlanTier { free, pro, enterprise }

class PlanTierConfig {
  final Widget badgeChild;
  final Color glowColor;
  final String pillLabel;

  const PlanTierConfig({
    required this.badgeChild,
    required this.glowColor,
    required this.pillLabel,
  });
}

const planTierConfigs = {
  PlanTier.free: PlanTierConfig(
    badgeChild: Icon(
      Icons.workspace_premium_rounded,
      size: 40,
      color: Color(0xFFCD7F32), // Bronze/Brown color for free tier
    ),
    glowColor: Color(0xFFCD7F32), // Bronze/Brown glow
    pillLabel: 'FREE',
  ),
  PlanTier.pro: PlanTierConfig(
    badgeChild: Icon(
      Icons.workspace_premium_rounded,
      size: 40,
      color: Color(0xFFFACC15),
    ),
    glowColor: Color(0xFFFACC15), // Gold color matching warning token (#FACC15)
    pillLabel: 'PRO',
  ),
  PlanTier.enterprise: PlanTierConfig(
    badgeChild: Icon(
      Icons.workspace_premium_rounded,
      size: 40,
      color: Color(0xFF60A5FA),
    ),
    glowColor: Color(0xFF60A5FA), // Blue accent glow
    pillLabel: 'ENTERPRISE',
  ),
};

class SubscriptionDashboardCard extends ConsumerStatefulWidget {
  const SubscriptionDashboardCard({super.key});

  @override
  ConsumerState<SubscriptionDashboardCard> createState() =>
      _SubscriptionDashboardCardState();
}

class _SubscriptionDashboardCardState
    extends ConsumerState<SubscriptionDashboardCard> {
  ScrollPosition? _scrollPosition;
  double _parallaxOffset = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupScrollListener();
    });
  }

  @override
  void dispose() {
    _cleanupScrollListener();
    super.dispose();
  }

  void _setupScrollListener() {
    if (!mounted) return;
    try {
      _scrollPosition = Scrollable.of(context).position;
      _scrollPosition?.addListener(_onScroll);
    } catch (_) {}
  }

  void _cleanupScrollListener() {
    _scrollPosition?.removeListener(_onScroll);
    _scrollPosition = null;
  }

  void _onScroll() {
    if (!mounted) return;
    final mediaQuery = MediaQuery.of(context);
    if (mediaQuery.disableAnimations) {
      if (_parallaxOffset != 0.0) {
        setState(() {
          _parallaxOffset = 0.0;
        });
      }
      return;
    }
    final pixels = _scrollPosition?.pixels ?? 0.0;
    final newOffset = (pixels * -0.05).clamp(-12.0, 12.0);
    if (newOffset != _parallaxOffset) {
      setState(() {
        _parallaxOffset = newOffset;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final subscriptionAsync = ref.watch(subscriptionProvider);
    final plansAsync = ref.watch(planProvider);

    final isPremium = user?.isPremium ?? false;

    String planName = isPremium ? 'PLUS' : 'FREE PLAN';
    final subscription = subscriptionAsync.valueOrNull;
    PlanTier currentTier = PlanTier.free;

    if (isPremium && subscription != null) {
      final plans = plansAsync.valueOrNull ?? [];
      final activePlan = plans.firstWhere(
        (p) => p.planId == subscription.planId,
        orElse: () =>
            PlanModel(planId: '', name: 'PLUS', durationMonths: 0, price: 0),
      );
      planName = activePlan.name.toUpperCase();
      if (activePlan.name.toLowerCase().contains('year')) {
        currentTier = PlanTier.pro;
      } else if (activePlan.name.toLowerCase().contains('enterprise') ||
          activePlan.name.toLowerCase().contains('business')) {
        currentTier = PlanTier.enterprise;
      } else {
        currentTier = PlanTier.pro;
      }
    }

    final config = planTierConfigs[currentTier]!;

    final remainingScans = ref.watch(scanLimitProvider).valueOrNull ?? 0;
    final usedScans = (50 - remainingScans).clamp(0, 50);
    final totalScans = 50;

    final isDarkTheme = context.isDark;
    final borderColorStart = const Color(0xFF5CED73);

    final double percent = (usedScans / totalScans).clamp(0.0, 1.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Soft blurred radial gradient background behind the card at low opacity (~15%) peeking from top-left corner
        Positioned(
          left: -70,
          top: -70,
          width: 300,
          height: 300,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF5CED73).withOpacity(0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // 2. The card container
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkTheme ? 0.35 : 0.12),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipPath(
            clipper: SquircleClipper(radius: 30),
            child: Stack(
              children: [
                // 3. Frosted tint, border gradient, grain noise overlay CustomPaint
                Positioned.fill(
                  child: CustomPaint(
                    painter: GlassCardPainter(
                      tintColor: const Color(
                        0xFF141614,
                      ), // Dark card base color
                      noiseColor: Colors.white.withOpacity(0.02),
                      borderColorStart: borderColorStart,
                      borderColorEnd: const Color(
                        0xFFFFD700,
                      ), // Gold/Yellow end color matching screenshot
                      borderWidth: 1.5,
                      radius: 30,
                    ),
                  ),
                ),

                // 4. Foreground Content
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Upper Row: Content on Left, Badge on Right
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Left column (texts)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top-left status pill
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF1A7A3A,
                                    ).withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF1A7A3A,
                                      ).withOpacity(0.5),
                                      width: 1.0,
                                    ),
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
                                const SizedBox(height: 4),
                                Text(
                                  isPremium
                                      ? planName.toUpperCase()
                                      : 'FREE PLAN',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Right column (badge)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 84,
                                height: 84,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(
                                    0xFF141614,
                                  ), // Dark circle background matching card
                                  border: Border.all(
                                    color: config.glowColor.withOpacity(0.35),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: config.glowColor.withOpacity(0.12),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: config.badgeChild,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: config.glowColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: config.glowColor.withOpacity(0.4),
                                    width: 1.0,
                                  ),
                                ),
                                child: Text(
                                  config.pillLabel,
                                  style: TextStyle(
                                    color: config.glowColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Usage indicator block (Full Width outside Row)
                      if (!isPremium) ...[
                        const SizedBox(height: 24),
                        Container(
                          height: 3,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final fillWidth = constraints.maxWidth * percent;
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  height: 3,
                                  width: fillWidth,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5CED73),
                                    borderRadius: BorderRadius.circular(1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF5CED73,
                                        ).withOpacity(0.4),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$usedScans of $totalScans scans used',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const PremiumScreen(),
                                  ),
                                );
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Upgrade',
                                    style: TextStyle(
                                      color: isDarkTheme
                                          ? const Color(0xFF60A5FA)
                                          : const Color(0xFF1D4ED8),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    color: isDarkTheme
                                        ? const Color(0xFF60A5FA)
                                        : const Color(0xFF1D4ED8),
                                    size: 13,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$usedScans scans used this month',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Text(
                              'Unlimited Scans Active',
                              style: TextStyle(
                                color: Color(0xFF5CED73),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Feature Row Container
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.04),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: _buildFeatureItem(
                                Icons.shield_outlined,
                                'Unlimited\nProtection',
                              ),
                            ),
                            _buildVerticalDivider(),
                            Expanded(
                              child: _buildFeatureItem(
                                Icons.bolt_rounded,
                                'Real-time\nScanning',
                              ),
                            ),
                            _buildVerticalDivider(),
                            Expanded(
                              child: _buildFeatureItem(
                                Icons.lock_outline_rounded,
                                'Advanced\nSecurity',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 18,
          color: const Color(0xFF5CED73).withOpacity(0.8),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            title,
            textAlign: TextAlign.left,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 20,
      width: 1,
      color: Colors.white.withOpacity(0.1),
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
              colors: [Color(0xFF1A7A3A), Color(0xFF1B5E20)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A7A3A).withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: const [
              Text('👑', style: TextStyle(fontSize: 18)),
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
              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
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
  State<DynamicSubscriptionArtwork> createState() =>
      _DynamicSubscriptionArtworkState();
}

class _DynamicSubscriptionArtworkState extends State<DynamicSubscriptionArtwork>
    with TickerProviderStateMixin {
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
                        ? widget.tierGlowColor.withOpacity(0.45)
                        : const Color(0xFF1A7A3A).withOpacity(0.2),
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
                      Icons.security_rounded,
                      size: 40,
                      color: widget.tierColor,
                      shadows: [
                        Shadow(
                          color: widget.tierGlowColor.withOpacity(0.6),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                  if (!widget.isPremium) ...[
                    Positioned(
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A7A3A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF5CED73),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF1A7A3A,
                              ).withOpacity(0.3),
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
        colors: [const Color(0xFF1B5E20), const Color(0xFF0F3214)],
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
      paint.color = _ringColor.withOpacity(0.25);
      canvas.drawCircle(center, w / 2, paint);

      paint.color = _ringColor.withOpacity(0.35);
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
      final List<double> particleAngles = [
        0.2,
        1.0,
        1.8,
        2.6,
        3.4,
        4.2,
        5.0,
        5.8,
      ];
      final List<double> particleSpeeds = [
        1.2,
        0.8,
        1.5,
        1.0,
        1.3,
        0.9,
        1.4,
        1.1,
      ];
      final List<double> particleRadii = [
        2.2,
        1.5,
        2.5,
        1.8,
        2.2,
        1.6,
        2.4,
        1.7,
      ];

      for (int i = 0; i < particleAngles.length; i++) {
        final double progress = (animationValue * particleSpeeds[i]) % 1.0;
        final double currentRadius = radius + (w / 2 - radius) * progress;
        final double angle = particleAngles[i] + (animationValue * 0.4);

        final double x = center.dx + currentRadius * math.cos(angle);
        final double y = center.dy + currentRadius * math.sin(angle);

        final double opacity = (1.0 - progress) * 0.7;
        dotPaint.color = _particleColor.withOpacity(opacity);

        canvas.drawCircle(Offset(x, y), particleRadii[i], dotPaint);
      }
    } else {
      paint.color = const Color(0xFFCD7F32).withOpacity(0.2);
      canvas.drawCircle(center, w / 2.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HolographicRingPainter oldDelegate) {
    return oldDelegate.planTier != planTier ||
        oldDelegate.animationValue != animationValue;
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

class _AnimatedSearchBarState extends State<_AnimatedSearchBar>
    with SingleTickerProviderStateMixin {
  static const _hints = ['Search Scan History...'];

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
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );
    _slideIn = Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
          ),
        );
    _slideOut = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -0.6))
        .animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
          ),
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
    final hintColor = widget.isDark
        ? AppPalette.darkTextSecondary
        : AppPalette.lightTextSecondary;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: widget.isDark ? AppPalette.darkSurface : AppPalette.lightCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: widget.isDark
                ? AppPalette.darkBorder
                : AppPalette.lightBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: hintColor, size: 22),
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
              color: hintColor.withOpacity(widget.isDark ? 0.5 : 0.45),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

class SquircleClipper extends CustomClipper<Path> {
  final double radius;
  SquircleClipper({this.radius = 28.0});

  @override
  Path getClip(Size size) {
    final path = Path();
    final r = radius.clamp(0.0, size.shortestSide / 2);
    final double offset = r * 1.4;
    final double ctrl = r * 0.45;

    path.moveTo(offset, 0);
    path.lineTo(size.width - offset, 0);
    path.cubicTo(size.width - ctrl, 0, size.width, ctrl, size.width, offset);
    path.lineTo(size.width, size.height - offset);
    path.cubicTo(
      size.width,
      size.height - ctrl,
      size.width - ctrl,
      size.height,
      size.width - offset,
      size.height,
    );
    path.lineTo(offset, size.height);
    path.cubicTo(
      ctrl,
      size.height,
      0,
      size.height - ctrl,
      0,
      size.height - offset,
    );
    path.lineTo(0, offset);
    path.cubicTo(0, ctrl, ctrl, 0, offset, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class GlassCardPainter extends CustomPainter {
  final Color tintColor;
  final Color noiseColor;
  final Color borderColorStart;
  final Color borderColorEnd;
  final double borderWidth;
  final double radius;

  GlassCardPainter({
    required this.tintColor,
    required this.noiseColor,
    required this.borderColorStart,
    required this.borderColorEnd,
    this.borderWidth = 1.6,
    this.radius = 28.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    final path = Path();
    final r = radius.clamp(0.0, size.shortestSide / 2);
    final double offset = r * 1.4;
    final double ctrl = r * 0.45;

    path.moveTo(offset, 0);
    path.lineTo(size.width - offset, 0);
    path.cubicTo(size.width - ctrl, 0, size.width, ctrl, size.width, offset);
    path.lineTo(size.width, size.height - offset);
    path.cubicTo(
      size.width,
      size.height - ctrl,
      size.width - ctrl,
      size.height,
      size.width - offset,
      size.height,
    );
    path.lineTo(offset, size.height);
    path.cubicTo(
      ctrl,
      size.height,
      0,
      size.height - ctrl,
      0,
      size.height - offset,
    );
    path.lineTo(0, offset);
    path.cubicTo(0, ctrl, ctrl, 0, offset, 0);
    path.close();

    final fillPaint = Paint()
      ..color = tintColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    canvas.save();
    canvas.clipPath(path);

    final noisePaint = Paint()
      ..color = noiseColor
      ..strokeWidth = 1.0;

    final points = <Offset>[];
    double x = 17.0;
    double y = 29.0;
    for (int i = 0; i < 900; i++) {
      x = (x * 131.71 + 83.19) % size.width;
      y = (y * 953.27 + 29.83) % size.height;
      points.add(Offset(x, y));
    }
    canvas.drawPoints(PointMode.points, points, noisePaint);
    canvas.restore();

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    borderPaint.shader = LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: [borderColorStart, borderColorEnd],
    ).createShader(rect);

    canvas.drawPath(path, borderPaint);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth * 1.2;

    rimPaint.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withOpacity(0.16),
        Colors.white.withOpacity(0.04),
        Colors.transparent,
      ],
      stops: const [0.0, 0.4, 1.0],
    ).createShader(rect);

    canvas.drawPath(path, rimPaint);
  }

  @override
  bool shouldRepaint(covariant GlassCardPainter oldDelegate) {
    return oldDelegate.tintColor != tintColor ||
        oldDelegate.noiseColor != noiseColor ||
        oldDelegate.borderColorStart != borderColorStart ||
        oldDelegate.borderColorEnd != borderColorEnd;
  }
}

class GlowingPulseLine extends StatefulWidget {
  final int used;
  final int total;
  const GlowingPulseLine({super.key, required this.used, required this.total});

  @override
  State<GlowingPulseLine> createState() => _GlowingPulseLineState();
}

class _GlowingPulseLineState extends State<GlowingPulseLine>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _idleController;
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant GlowingPulseLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.used != oldWidget.used) {
      final mediaQuery = MediaQuery.of(context);
      if (!mediaQuery.disableAnimations) {
        _pulseController.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _idleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double fillPercentage = (widget.total > 0)
        ? (widget.used / widget.total).clamp(0.0, 1.0)
        : 0.0;
    final greenColor = const Color(0xFF5CED73);

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _idleController]),
      builder: (context, child) {
        double pulseVal = 0.0;
        if (_pulseController.isAnimating) {
          double t = _pulseController.value;
          pulseVal = 0.15 * math.sin(t * math.pi);
        }

        double idleVal = _idleController.value;
        double glowScale = 1.0 + pulseVal;
        double glowOpacity = 0.3 + (idleVal * 0.15) + (pulseVal * 0.4);

        final mediaQuery = MediaQuery.of(context);
        if (mediaQuery.disableAnimations) {
          glowScale = 1.0;
          glowOpacity = 0.4;
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            final fillWidth = totalWidth * fillPercentage;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 3,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                    Container(
                      height: 3,
                      width: fillWidth,
                      decoration: BoxDecoration(
                        color: greenColor,
                        borderRadius: BorderRadius.circular(1.5),
                        boxShadow: [
                          BoxShadow(
                            color: greenColor.withOpacity(glowOpacity),
                            blurRadius: 6.0 * glowScale,
                            spreadRadius: 1.0 * glowScale,
                          ),
                        ],
                      ),
                    ),
                    if (fillPercentage > 0.0)
                      Positioned(
                        left: (fillWidth - 4).clamp(0.0, totalWidth - 8),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: greenColor,
                                blurRadius: 8.0 * glowScale,
                                spreadRadius: 2.0 * glowScale,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      TextSpan(
                        text: '${widget.used} ',
                        style: TextStyle(
                          color: greenColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: 'of '),
                      TextSpan(
                        text: '${widget.total} ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: 'scans used'),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class CheckeredShield extends StatelessWidget {
  final double width;
  final double height;
  const CheckeredShield({super.key, this.width = 24, this.height = 28});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _CheckeredShieldPainter(),
    );
  }
}

class _CheckeredShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final lightGold = const Color(0xFFD4AF37);
    final darkGold = const Color(0xFF8C6D23);

    final path = Path();
    final cx = w / 2;

    path.moveTo(cx, 0);
    path.quadraticBezierTo(w * 0.15, h * 0.05, 0, h * 0.15);
    path.quadraticBezierTo(w * 0.05, h * 0.6, cx, h);
    path.quadraticBezierTo(w * 0.95, h * 0.6, w, h * 0.15);
    path.quadraticBezierTo(w * 0.85, h * 0.05, cx, 0);
    path.close();

    canvas.save();
    canvas.clipPath(path);

    final paint = Paint()..style = PaintingStyle.fill;
    final cxVal = w / 2;
    final cyVal = h * 0.45;

    // Top-Left
    paint.color = darkGold;
    final tlPath = Path()
      ..moveTo(cxVal, 0)
      ..lineTo(cxVal, cyVal)
      ..lineTo(0, cyVal)
      ..lineTo(0, h * 0.15)
      ..quadraticBezierTo(w * 0.15, h * 0.05, cxVal, 0)
      ..close();
    canvas.drawPath(tlPath, paint);

    // Top-Right
    paint.color = lightGold;
    final trPath = Path()
      ..moveTo(cxVal, 0)
      ..lineTo(cxVal, cyVal)
      ..lineTo(w, cyVal)
      ..lineTo(w, h * 0.15)
      ..quadraticBezierTo(w * 0.85, h * 0.05, cxVal, 0)
      ..close();
    canvas.drawPath(trPath, paint);

    // Bottom-Left
    paint.color = lightGold;
    final blPath = Path()
      ..moveTo(0, cyVal)
      ..lineTo(cxVal, cyVal)
      ..lineTo(cxVal, h)
      ..quadraticBezierTo(w * 0.05, h * 0.6, 0, cyVal)
      ..close();
    canvas.drawPath(blPath, paint);

    // Bottom-Right
    paint.color = darkGold;
    final brPath = Path()
      ..moveTo(w, cyVal)
      ..lineTo(cxVal, cyVal)
      ..lineTo(cxVal, h)
      ..quadraticBezierTo(w * 0.95, h * 0.6, w, cyVal)
      ..close();
    canvas.drawPath(brPath, paint);

    canvas.restore();

    final borderPaint = Paint()
      ..color = const Color(0xFF5A4516)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WatermarkShield extends StatelessWidget {
  final double size;
  const WatermarkShield({super.key, this.size = 280});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _WatermarkShieldPainter(),
    );
  }
}

class _WatermarkShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final path = Path();
    path.moveTo(cx, 0);
    path.quadraticBezierTo(w * 0.15, h * 0.05, 0, h * 0.15);
    path.quadraticBezierTo(w * 0.05, h * 0.6, cx, h);
    path.quadraticBezierTo(w * 0.95, h * 0.6, w, h * 0.15);
    path.quadraticBezierTo(w * 0.85, h * 0.05, cx, 0);
    path.close();

    canvas.save();
    canvas.clipPath(path);

    final cy = h * 0.45;
    final fillPaint = Paint()..style = PaintingStyle.fill;

    final baseOpacityColor = Colors.white.withOpacity(0.02);
    final altOpacityColor = Colors.white.withOpacity(0.05);

    // Top-Left
    fillPaint.color = baseOpacityColor;
    canvas.drawRect(Rect.fromLTRB(0, 0, cx, cy), fillPaint);

    // Top-Right
    fillPaint.color = altOpacityColor;
    canvas.drawRect(Rect.fromLTRB(cx, 0, w, cy), fillPaint);

    // Bottom-Left
    fillPaint.color = altOpacityColor;
    canvas.drawPath(
      Path()
        ..moveTo(0, cy)
        ..lineTo(cx, cy)
        ..lineTo(cx, h)
        ..quadraticBezierTo(w * 0.05, h * 0.6, 0, cy)
        ..close(),
      fillPaint,
    );

    // Bottom-Right
    fillPaint.color = baseOpacityColor;
    canvas.drawPath(
      Path()
        ..moveTo(w, cy)
        ..lineTo(cx, cy)
        ..lineTo(cx, h)
        ..quadraticBezierTo(w * 0.95, h * 0.6, w, cy)
        ..close(),
      fillPaint,
    );

    canvas.restore();

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawLine(Offset(cx, 0), Offset(cx, h), linePaint);
    canvas.drawLine(Offset(0, cy), Offset(w, cy), linePaint);

    final outlinePaint = Paint()
      ..color = Colors.white.withOpacity(0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(path, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant _WatermarkShieldPainter oldDelegate) => false;
}
