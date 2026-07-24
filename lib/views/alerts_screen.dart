import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../services/url_scan_service.dart';
import '../services/user_service.dart';
import '../services/blocked_url_service.dart';
import '../models/url_scan_model.dart';
import '../models/blocked_url_model.dart';
import '../services/exception_mapper.dart';
import '../providers/app_providers.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  Color get _bgColor => context.bg;
  Color get _cardColor => context.cardBg;
  Color get _surfaceColor => context.border;
  Color get _primaryGreen => context.activeAccent;
  Color get _amber => context.warning;
  Color get _red => context.danger;

  Color get _textPrimary => context.textPrimary;
  Color get _textSecondary => context.textSecondary;
  Color get _textMuted => context.textMuted;

  final UrlScanService _scanService = UrlScanService();

  List<UrlScanModel> _myDangerousScans = [];
  List<UrlScanModel> _globalBlockedUrls = [];
  List<UrlScanModel> _allScans = [];
  List<UrlScanModel> _filteredHistoryScans = [];
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  String _selectedSeverity = 'All';
  bool _isPremium = false;

  List<UrlScanModel> get _scans => [
    ..._globalBlockedUrls,
    ..._myDangerousScans,
  ];

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
    _searchController.addListener(_filterHistoryScans);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterHistoryScans() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredHistoryScans = _allScans;
      } else {
        _filteredHistoryScans = _allScans.where((scan) {
          final urlMatch = scan.scannedUrl.toLowerCase().contains(query);
          final resultMatch = (scan.scanResult ?? '').toLowerCase().contains(
            query,
          );
          final threatMatch = (scan.threatType ?? '').toLowerCase().contains(
            query,
          );
          return urlMatch || resultMatch || threatMatch;
        }).toList();
      }
    });
  }

  Future<void> _loadScans() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final userId = ref.read(userProvider)?.userId;
      if (userId == null) {
        if (mounted) {
          setState(() {
            _myDangerousScans = [];
            _globalBlockedUrls = [];
            _allScans = [];
            _filteredHistoryScans = [];
            _isLoading = false;
            _isPremium = false;
          });
        }
        return;
      }

      // Fetch user profile to verify premium status
      final user = await UserService().getUser(userId);
      final isPremiumStatus = user?.isPremium ?? false;

      // Fetch all personal scans once. Alerts are derived from unsafe verdicts
      // while History retains the complete scan list.
      var allScans = await _scanService
          .getUserScans(userId)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => <UrlScanModel>[],
          );
      final dangerousScans = allScans.where((scan) {
        final verdict = scan.scanResult?.toLowerCase();
        return verdict == 'dangerous' || verdict == 'suspicious';
      }).toList();

      // Fetch blocked URLs for Premium users only.
      List<UrlScanModel> globalBlocked = [];
      if (isPremiumStatus) {
        final blockedUrls = await BlockedUrlService()
            .getBlockedUrls(userId)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => <BlockedUrlModel>[],
            );
        globalBlocked = blockedUrls
            .map(
              (b) => UrlScanModel(
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
              ),
            )
            .toList();
      }

      if (mounted) {
        setState(() {
          _myDangerousScans = dangerousScans;
          _globalBlockedUrls = globalBlocked;
          _allScans = allScans;
          // Apply active search filter if text exists
          if (_searchController.text.isNotEmpty) {
            final query = _searchController.text.toLowerCase().trim();
            _filteredHistoryScans = allScans.where((scan) {
              final urlMatch = scan.scannedUrl.toLowerCase().contains(query);
              final resultMatch = (scan.scanResult ?? '')
                  .toLowerCase()
                  .contains(query);
              final threatMatch = (scan.threatType ?? '')
                  .toLowerCase()
                  .contains(query);
              return urlMatch || resultMatch || threatMatch;
            }).toList();
          } else {
            _filteredHistoryScans = allScans;
          }
          _isPremium = isPremiumStatus;
          _isLoading = false;
        });
      }
    } catch (e) {
      final mapped = ExceptionMapper.map(e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _myDangerousScans = [];
          _globalBlockedUrls = [];
          _allScans = [];
          _filteredHistoryScans = [];
          _isPremium = false;
          _errorMessage = mapped.message;
        });
      }
    }
  }

  String _severityForScan(UrlScanModel scan) {
    final score = scan.riskScore ?? 0;
    switch (scan.scanResult?.toLowerCase()) {
      case 'dangerous':
        return score >= 85 ? 'Critical' : 'High';
      case 'suspicious':
        return score >= 60 ? 'Medium' : 'Low';
      case 'safe':
        return 'Low';
      default:
        return 'Unknown';
    }
  }

  String _alertTitle(UrlScanModel scan, {bool isGlobal = false}) {
    if (isGlobal) return 'Known threat blocked';
    return switch (scan.scanResult?.toLowerCase()) {
      'dangerous' => 'Malicious URL detected',
      'suspicious' => 'Suspicious URL flagged',
      'safe' => 'No threats detected',
      _ => 'Scan result available',
    };
  }

  List<UrlScanModel> get _filteredDangerousScans {
    if (_selectedSeverity == 'All') return _myDangerousScans;
    return _myDangerousScans
        .where((s) => _severityForScan(s) == _selectedSeverity)
        .toList();
  }

  List<UrlScanModel> get _filteredGlobalBlockedUrls {
    if (_selectedSeverity == 'All') return _globalBlockedUrls;
    return _globalBlockedUrls
        .where((s) => _severityForScan(s) == _selectedSeverity)
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
    final selectedTab = ref.watch(alertsTabProvider);
    ref.watch(dangerousScansProvider).whenData((scans) {
      _myDangerousScans = scans;
    });

    ref.watch(blockedUrlsProvider).whenData((blocked) {
      _globalBlockedUrls = blocked
          .map(
            (b) => UrlScanModel(
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
            ),
          )
          .toList();
    });

    ref.watch(scanHistoryProvider).whenData((scans) {
      _allScans = scans;
      // Apply active search filter if text exists
      if (_searchController.text.isNotEmpty) {
        final query = _searchController.text.toLowerCase().trim();
        _filteredHistoryScans = scans.where((scan) {
          final urlMatch = scan.scannedUrl.toLowerCase().contains(query);
          final resultMatch = (scan.scanResult ?? '').toLowerCase().contains(
            query,
          );
          final threatMatch = (scan.threatType ?? '').toLowerCase().contains(
            query,
          );
          return urlMatch || resultMatch || threatMatch;
        }).toList();
      } else {
        _filteredHistoryScans = scans;
      }
    });

    try {
      final Widget mainContent;
      if (_isLoading) {
        mainContent = _buildLoadingState();
      } else if (_errorMessage != null) {
        mainContent = _buildErrorState();
      } else {
        mainContent = selectedTab == 0
            ? _buildScanList()
            : _buildHistoryTabContent();
      }

      return Scaffold(
        backgroundColor: _bgColor,
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = constraints.maxWidth > 760
                  ? 760.0
                  : constraints.maxWidth;
              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: contentWidth,
                  height: constraints.maxHeight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      _buildTabBar(selectedTab),
                      if (selectedTab == 0 &&
                          !_isLoading &&
                          _errorMessage == null)
                        _buildFilterChips(),
                      Expanded(child: mainContent),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    } catch (e, stack) {
      if (kDebugMode) debugPrint('AlertsScreen build error: $e\n$stack');
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFEF4444),
                  size: 48,
                ),
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
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
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
                border: Border.all(color: _red.withValues(alpha: 0.3)),
              ),
              child: Icon(Icons.error_outline_rounded, size: 48, color: _red),
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
              icon: const Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: 20,
              ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isCompact ? 16 : 20,
        isCompact ? 12 : 20,
        isCompact ? 16 : 20,
        8,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isCompact ? 10 : 12),
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
              size: isCompact ? 23 : 26,
            ),
          ),
          SizedBox(width: isCompact ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Threat Alerts',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: isCompact ? 21 : 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Unsafe scans that need your attention',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
              border: Border.all(color: _primaryGreen.withValues(alpha: 0.3)),
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
      final sev = _severityForScan(s);
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
          final chipColor = filter == 'All'
              ? _primaryGreen
              : _severityColor(filter);
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
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 6),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
              border: Border.all(color: _primaryGreen.withValues(alpha: 0.2)),
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
                return _buildScanCard(
                  globalBlocked[index],
                  index,
                  isGlobal: true,
                );
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
              return _buildScanCard(
                myDangerousScans[index],
                index,
                isGlobal: false,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTabBar(int selectedTab) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _surfaceColor.withValues(alpha: 0.8)),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => ref.read(alertsTabProvider.notifier).state = 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: selectedTab == 0
                        ? _primaryGreen.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_rounded,
                        color: selectedTab == 0
                            ? _primaryGreen
                            : _textSecondary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Threat Alerts',
                        style: TextStyle(
                          color: selectedTab == 0
                              ? _primaryGreen
                              : _textSecondary,
                          fontSize: 13,
                          fontWeight: selectedTab == 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => ref.read(alertsTabProvider.notifier).state = 1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: selectedTab == 1
                        ? _primaryGreen.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        color: selectedTab == 1
                            ? _primaryGreen
                            : _textSecondary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Scan History',
                        style: TextStyle(
                          color: selectedTab == 1
                              ? _primaryGreen
                              : _textSecondary,
                          fontSize: 13,
                          fontWeight: selectedTab == 1
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTabContent() {
    if (_filteredHistoryScans.isEmpty) {
      return _buildHistoryEmptyState();
    }

    return Column(
      children: [
        _buildHistorySearchInput(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadScans,
            color: _primaryGreen,
            backgroundColor: _cardColor,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              itemCount: _filteredHistoryScans.length,
              itemBuilder: (context, index) {
                return _buildScanCard(
                  _filteredHistoryScans[index],
                  index,
                  isGlobal: false,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySearchInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(color: _textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search scans by URL or status...',
            hintStyle: TextStyle(
              color: _textPrimary.withValues(alpha: 0.3),
              fontSize: 13,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(
                Icons.search_rounded,
                color: _textPrimary.withValues(alpha: 0.4),
                size: 20,
              ),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: _textPrimary.withValues(alpha: 0.4),
                      size: 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                : null,
            filled: true,
            fillColor: _cardColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _textPrimary.withValues(alpha: 0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _textPrimary.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _primaryGreen, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryEmptyState() {
    return Column(
      children: [
        _buildHistorySearchInput(),
        Expanded(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.15),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
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
                        Icons.history_rounded,
                        size: 52,
                        color: _primaryGreen.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _allScans.isEmpty
                          ? 'No scan history'
                          : 'No results found',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _allScans.isEmpty
                          ? 'Start scanning URLs to view them here.'
                          : 'Try checking your spelling or search terms.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textPrimary.withValues(alpha: 0.35),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScanCard(UrlScanModel scan, int index, {bool isGlobal = false}) {
    final severity = _severityForScan(scan);
    final sevColor = isGlobal ? _primaryGreen : _severityColor(severity);
    final score = scan.riskScore ?? 0;
    final isSuspicious = scan.scanResult?.toLowerCase() == 'suspicious';
    final resultColor = isGlobal
        ? _red
        : scan.isSafe
        ? _primaryGreen
        : isSuspicious
        ? _amber
        : _red;
    final resultLabel = isGlobal
        ? 'BLOCKED'
        : scan.isSafe
        ? 'SAFE'
        : isSuspicious
        ? 'SUSPICIOUS'
        : 'DANGER';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index.clamp(0, 10) * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push('/scan-detail/${scan.scanId}'),
                child: child,
              ),
            ),
          ),
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
                color: _cardColor.withValues(
                  alpha: 0.8,
                ), // Glassmorphic translucent bg
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isGlobal
                      ? _primaryGreen.withValues(
                          alpha: 0.25,
                        ) // Forest Green border
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
                                    color: (isGlobal ? _primaryGreen : sevColor)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color:
                                          (isGlobal ? _primaryGreen : sevColor)
                                              .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    isGlobal
                                        ? 'GLOBAL THREAT'
                                        : severity.toUpperCase(),
                                    style: TextStyle(
                                      color: isGlobal
                                          ? _primaryGreen
                                          : sevColor,
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
                                    color: resultColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    resultLabel,
                                    style: TextStyle(
                                      color: resultColor,
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
                            Text(
                              _alertTitle(scan, isGlobal: isGlobal),
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.1,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  isGlobal
                                      ? Icons.block_flipped
                                      : (scan.isSafe
                                            ? Icons.check_circle_outline_rounded
                                            : Icons.warning_amber_rounded),
                                  color: isGlobal
                                      ? _red
                                      : (scan.isSafe ? _primaryGreen : _amber),
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
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
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
                                      backgroundColor: _surfaceColor.withValues(
                                        alpha: 0.25,
                                      ),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        sevColor,
                                      ),
                                      minHeight: 4,
                                    ),
                                  ),
                                ),
                                // VT flags
                                if (scan.virusTotalFlags > 0) ...[
                                  const SizedBox(width: 10),
                                  Icon(
                                    Icons.flag_rounded,
                                    size: 11,
                                    color: _red.withValues(alpha: 0.6),
                                  ),
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
                                  Icon(
                                    Icons.psychology_rounded,
                                    size: 11,
                                    color: _amber.withValues(alpha: 0.6),
                                  ),
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
