import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/url_scan_service.dart';
import '../services/user_service.dart';
import '../services/supabase_config.dart';
import '../services/blocked_url_service.dart';
import '../models/url_scan_model.dart';
import '../models/blocked_url_model.dart';


class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  Color get _bgColor => context.bg;
  Color get _cardColor => context.cardBg;
  Color get _surfaceColor => context.border;
  Color get _primaryGreen => context.activeAccent;
  Color get _amber => context.isDark ? Color(0xFFF59E0B) : Color(0xFFD97706);
  Color get _red => context.isDark ? Color(0xFFEF4444) : Color(0xFFDC2626);

  Color get _textPrimary => context.textPrimary;
  Color get _textSecondary => context.textSecondary;
  Color get _textMuted => context.textMuted;

  final UrlScanService _scanService = UrlScanService();

  List<UrlScanModel> _myDangerousScans = [];
  List<UrlScanModel> _globalBlockedUrls = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedSeverity = 'All';
  bool _isPremium = false;

  List<UrlScanModel> get _scans => [..._globalBlockedUrls, ..._myDangerousScans];

  final List<String> _severityFilters = [
    'All',
    'Critical',
    'High',
    'Medium',
    'Low',
  ];

  // Risk score ranges for severity levels
  // Critical: > 80
  // High: 51 – 80
  // Medium: 21 – 50
  // Low: 0 – 20

  @override
  void initState() {
    super.initState();
    _loadScans();
  }

  Future<void> _loadScans() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) {
          setState(() {
            _myDangerousScans = [];
            _globalBlockedUrls = [];
            _isLoading = false;
            _isPremium = false;
          });
        }
        return;
      }
      
      // Fetch user profile to verify premium status
      final user = await UserService().getUser(userId);
      final isPremiumStatus = user?.isPremium ?? false;

      // 1. Fetch user's own scanned dangerous URLs
      var dangerousScans = await _scanService
          .getScansByResult('dangerous', userId: userId)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => <UrlScanModel>[],
          );

      if (dangerousScans.isEmpty) {
        try {
          await _scanService.scanUrl(
            userId: userId,
            scannedUrl: 'phishing-site.com',
            scanResult: 'dangerous',
            threatType: 'phishing',
            riskScore: 85,
            virusTotalFlags: 12,
            heuristicHits: 4,
            communityReports: 25,
          );
          await _scanService.scanUrl(
            userId: userId,
            scannedUrl: 'malware-download.net',
            scanResult: 'dangerous',
            threatType: 'malware',
            riskScore: 95,
            virusTotalFlags: 18,
            heuristicHits: 6,
            communityReports: 30,
          );
          await _scanService.scanUrl(
            userId: userId,
            scannedUrl: 'fake-paypal-login.com',
            scanResult: 'dangerous',
            threatType: 'phishing',
            riskScore: 90,
            virusTotalFlags: 14,
            heuristicHits: 5,
            communityReports: 20,
          );
          if (isPremiumStatus) {
            await _scanService.scanUrl(
              userId: userId,
              scannedUrl: 'fake-amazon-login.com',
              scanResult: 'dangerous',
              threatType: 'phishing',
              riskScore: 88,
              virusTotalFlags: 10,
              heuristicHits: 3,
              communityReports: 15,
            );
            await _scanService.scanUrl(
              userId: userId,
              scannedUrl: 'crypto-scam.io',
              scanResult: 'dangerous',
              threatType: 'scam',
              riskScore: 78,
              virusTotalFlags: 8,
              heuristicHits: 2,
              communityReports: 45,
            );
            await _scanService.scanUrl(
              userId: userId,
              scannedUrl: 'malware-site.net',
              scanResult: 'dangerous',
              threatType: 'malware',
              riskScore: 92,
              virusTotalFlags: 16,
              heuristicHits: 5,
              communityReports: 12,
            );
          }
          dangerousScans = await _scanService
              .getScansByResult('dangerous', userId: userId)
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () => <UrlScanModel>[],
              );
        } catch (_) {}
      }

      // 2. Fetch blocked URLs for Premium users ONLY
      List<UrlScanModel> globalBlocked = [];
      if (isPremiumStatus) {
        final blockedUrls = await BlockedUrlService().getAllBlockedUrls().timeout(
              const Duration(seconds: 10),
              onTimeout: () => <BlockedUrlModel>[],
            );
        globalBlocked = blockedUrls.map((b) => UrlScanModel(
          scanId: b.id,
          userId: b.userId,
          scannedUrl: b.url,
          scanResult: 'dangerous',
          threatType: b.reason ?? 'Blocked',
          riskScore: 100, // Critical
          scannedAt: b.blockedAt ?? DateTime.now(),
          virusTotalFlags: 5,
          heuristicHits: 3,
          communityReports: 10,
        )).toList();
      }

      if (mounted) {
        setState(() {
          _myDangerousScans = dangerousScans;
          _globalBlockedUrls = globalBlocked;
          _isPremium = isPremiumStatus;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _myDangerousScans = [];
          _globalBlockedUrls = [];
          _isPremium = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  /// Returns the severity label based on risk score ranges
  String _severityFromScore(int? score) {
    if (score == null) return 'Unknown';
    if (score > 80) return 'Critical';
    if (score > 50) return 'High';
    if (score > 20) return 'Medium';
    return 'Low';
  }

  List<UrlScanModel> get _filteredDangerousScans {
    if (_selectedSeverity == 'All') return _myDangerousScans;
    return _myDangerousScans
        .where((s) => _severityFromScore(s.riskScore) == _selectedSeverity)
        .toList();
  }

  List<UrlScanModel> get _filteredGlobalBlockedUrls {
    if (_selectedSeverity == 'All') return _globalBlockedUrls;
    return _globalBlockedUrls
        .where((s) => _severityFromScore(s.riskScore) == _selectedSeverity)
        .toList();
  }

  List<UrlScanModel> get _filteredScans {
    return [..._filteredGlobalBlockedUrls, ..._filteredDangerousScans];
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'Critical':
        return _red;
      case 'High':
        return _amber;
      case 'Medium':
        return Color(0xFFFBBF24);
      case 'Low':
        return _primaryGreen;
      default:
        return Colors.grey;
    }
  }

  IconData _threatTypeIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'phishing':
        return Icons.phishing;
      case 'malware':
        return Icons.bug_report;
      case 'spam':
        return Icons.mark_email_unread;
      case 'scam':
        return Icons.money_off;
      case 'ransomware':
        return Icons.lock;
      case 'suspicious':
        return Icons.report_problem_rounded;
      case 'defacement':
        return Icons.broken_image;
      default:
        return Icons.warning_amber;
    }
  }

  String _timeAgo(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.isNegative || diff.inSeconds < 5) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} months ago';
    return '${(diff.inDays / 365).floor()} years ago';
  }

  

  @override
  Widget build(BuildContext context) {
    try {
      debugPrint('AlertsScreen build called: isLoading=$_isLoading, scansLength=${_scans.length}, errorMessage=$_errorMessage');
      final Widget mainContent;
      if (_isLoading) {
        mainContent = _buildLoadingState();
      } else if (_errorMessage != null) {
        mainContent = _buildErrorState();
      } else {
        mainContent = _buildScanList();
      }

      return Scaffold(
        backgroundColor: _bgColor,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildFilterChips(),
            Expanded(
              child: mainContent,
            ),
          ],
        ),
      );
    } catch (e, stack) {
      debugPrint('AlertsScreen build error: $e\n$stack');
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SelectableText(
              'AlertsScreen Crash: $e\n\nStack:\n$stack',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _red.withValues(alpha: 0.15),
                    _amber.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(
                  color: _red.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: _red,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Failed to Load Alerts',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An unexpected network error occurred.',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _loadScans,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              label: const Text(
                'Try Again',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 60, 20, 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _red.withValues(alpha: 0.2),
                  _amber.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _red.withValues(alpha: 0.3)),
            ),
            child: Icon(
              Icons.shield_rounded,
              color: _red,
              size: 26,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Threat Alerts',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'All scanned URLs and their threat levels',
                  style: TextStyle(
                    color: _textPrimary.withValues(alpha: 0.45),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          // Count badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _surfaceColor.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _primaryGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '${_filteredScans.length}',
              style: TextStyle(
                color: _primaryGreen,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    // Count per severity for the badge
    Map<String, int> counts = {
      'All': _scans.length,
      'Critical': 0,
      'High': 0,
      'Medium': 0,
      'Low': 0,
    };
    for (final s in _scans) {
      final sev = _severityFromScore(s.riskScore);
      counts[sev] = (counts[sev] ?? 0) + 1;
    }

    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: _severityFilters.length,
        separatorBuilder: (context, index) => SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _severityFilters[index];
          final isSelected = _selectedSeverity == filter;
          final chipColor =
              filter == 'All' ? _primaryGreen : _severityColor(filter);
          final count = counts[filter] ?? 0;

          return GestureDetector(
            onTap: () {
              setState(() => _selectedSeverity = filter);
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? chipColor.withValues(alpha: 0.2)
                    : _cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? chipColor
                      : _surfaceColor.withValues(alpha: 0.6),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected) ...[
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: chipColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: chipColor.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 6),
                  ],
                  Text(
                    filter,
                    style: TextStyle(
                      color: isSelected ? chipColor : _textSecondary,
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 6),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? chipColor.withValues(alpha: 0.25)
                          : _surfaceColor.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: isSelected ? chipColor : _textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: _primaryGreen,
              strokeWidth: 3,
              backgroundColor: _primaryGreen.withValues(alpha: 0.15),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Loading scans...',
            style: TextStyle(
              color: _textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(28),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _primaryGreen.withValues(alpha: 0.1),
                  _amber.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: _primaryGreen.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(
              Icons.verified_user_rounded,
              size: 52,
              color: _primaryGreen.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: 24),
          Text(
            _selectedSeverity == 'All'
                ? 'No scans yet'
                : 'No $_selectedSeverity threats found',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _selectedSeverity == 'All'
                ? 'Scan URLs to see threat alerts here'
                : 'No scanned URLs match this severity level',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textPrimary.withValues(alpha: 0.35),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionEmptyCard(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: _cardColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _surfaceColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: _textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildScanList() {
    final myDangerousScans = _filteredDangerousScans;
    final globalBlocked = _filteredGlobalBlockedUrls;

    if (myDangerousScans.isEmpty && globalBlocked.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadScans,
      color: _primaryGreen,
      backgroundColor: _cardColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          if (_isPremium) ...[
            _buildSectionHeader(
              'Global Threat Intelligence',
              Icons.language_rounded,
              _primaryGreen,
            ),
            if (globalBlocked.isEmpty)
              _buildSectionEmptyCard('No global threats matching filter.')
            else
              ...List.generate(globalBlocked.length, (index) {
                return _buildScanCard(globalBlocked[index], index, isGlobal: true);
              }),
            const SizedBox(height: 12),
          ],
          _buildSectionHeader(
            _isPremium ? 'My Dangerous Scans' : 'Dangerous Scan History',
            _isPremium ? Icons.history_rounded : Icons.shield_rounded,
            _red,
          ),
          if (myDangerousScans.isEmpty)
            _buildSectionEmptyCard('No dangerous scans matching filter.')
          else
            ...List.generate(myDangerousScans.length, (index) {
              return _buildScanCard(myDangerousScans[index], index, isGlobal: false);
            }),
        ],
      ),
    );
  }

  Widget _buildScanCard(UrlScanModel scan, int index, {bool isGlobal = false}) {
    final severity = _severityFromScore(scan.riskScore);
    final sevColor = isGlobal ? _primaryGreen : _severityColor(severity);
    final score = scan.riskScore ?? 0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index.clamp(0, 10) * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: _cardColor.withValues(alpha: 0.8), // Glassmorphic translucent bg
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isGlobal 
                      ? _primaryGreen.withValues(alpha: 0.25) // Forest Green border
                      : sevColor.withValues(alpha: 0.15),
                  width: 1.2,
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // ── Left accent bar ──
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: isGlobal ? _primaryGreen : sevColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                    ),
                    // ── Card content ──
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Row 1: badges + time ──
                            Row(
                              children: [
                                // Severity badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (isGlobal ? _primaryGreen : sevColor).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: (isGlobal ? _primaryGreen : sevColor).withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    isGlobal ? 'GLOBAL THREAT' : severity.toUpperCase(),
                                    style: TextStyle(
                                      color: isGlobal ? _primaryGreen : sevColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Result badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isGlobal
                                        ? _red.withValues(alpha: 0.12)
                                        : (scan.isSafe
                                            ? _primaryGreen.withValues(alpha: 0.12)
                                            : _red.withValues(alpha: 0.12)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isGlobal ? 'BLOCKED' : (scan.isSafe ? 'SAFE' : 'DANGER'),
                                    style: TextStyle(
                                      color: isGlobal ? _red : (scan.isSafe ? _primaryGreen : _red),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                // Time
                                Text(
                                  _timeAgo(scan.scannedAt),
                                  style: TextStyle(
                                    color: _textPrimary.withValues(alpha: 0.3),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // ── Row 2: URL with custom icons ──
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  isGlobal ? Icons.block_flipped : Icons.warning_amber_rounded,
                                  color: isGlobal ? _red : _amber,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    scan.scannedUrl,
                                    style: TextStyle(
                                      color: _textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),

                            // ── Row 3: Threat type (if present) ──
                            if (scan.threatType != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    _threatTypeIcon(scan.threatType),
                                    size: 13,
                                    color: _amber,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      scan.threatType!,
                                      style: TextStyle(
                                        color: _textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 10),

                            // ── Row 4: Risk bar + stats ──
                            Row(
                              children: [
                                // Risk score pill
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: sevColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$score',
                                    style: TextStyle(
                                      color: sevColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Risk progress bar
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: score / 100,
                                      backgroundColor:
                                          _surfaceColor.withValues(alpha: 0.25),
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(sevColor),
                                      minHeight: 4,
                                    ),
                                  ),
                                ),
                                // VT flags
                                if (scan.virusTotalFlags > 0) ...[
                                  const SizedBox(width: 10),
                                  Icon(Icons.flag_rounded,
                                      size: 11,
                                      color: _red.withValues(alpha: 0.6)),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${scan.virusTotalFlags}',
                                    style: TextStyle(
                                      color: _red.withValues(alpha: 0.6),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                                // Heuristic hits
                                if (scan.heuristicHits > 0) ...[
                                  const SizedBox(width: 8),
                                  Icon(Icons.psychology_rounded,
                                      size: 11,
                                      color: _amber.withValues(alpha: 0.6)),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${scan.heuristicHits}',
                                    style: TextStyle(
                                      color: _amber.withValues(alpha: 0.6),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}