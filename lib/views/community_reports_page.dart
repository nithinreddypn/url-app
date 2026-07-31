import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../services/community_threat_service.dart';
import '../providers/app_providers.dart';
import 'widgets/report_url_form.dart';
import 'widgets/community_protection_card.dart';
import 'widgets/threat_feed_card.dart';
import 'widgets/reports_preview_card.dart';
import 'widgets/community_alert_card.dart';
import 'widgets/security_tip_card.dart';

class CommunityReportsPage extends ConsumerStatefulWidget {
  const CommunityReportsPage({super.key});

  @override
  ConsumerState<CommunityReportsPage> createState() => _CommunityReportsPageState();
}

class _CommunityReportsPageState extends ConsumerState<CommunityReportsPage> {
  bool _isLoading = true;
  int _selectedFilterIndex = 0; // 0 = Feed (Threats + Alerts), 1 = My Reports, 2 = Verified Intel
  
  // Data states
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _feedReports = [];
  List<Map<String, dynamic>> _myReports = [];
  List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _verifiedReports = [];

  // Polling state
  Timer? _pollingTimer;

  // Local state to keep track of dismissed alerts visually
  final Set<String> _dismissedAlertIds = {};

  // For staggered animations on list load
  int _buildTriggerCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  bool _isPendingState(String status) {
    final s = status.toLowerCase();
    return s == 'pending' || s == 'needs_review' || s == 'queued';
  }

  void _startPollingIfNeeded() {
    _pollingTimer?.cancel();
    _pollingTimer = null;

    final hasPendingFeed = _feedReports.any((r) => _isPendingState(r['verification_status'] ?? ''));
    final hasPendingMyReports = _myReports.any((r) => _isPendingState(r['verification_status'] ?? ''));

    if (hasPendingFeed || hasPendingMyReports) {
      // NOTE: Polling is a client-side fallback/stopgap. WebSockets or Push notifications
      // should eventually replace this long-term.
      _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        _silentReloadData();
      });
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(communityThreatServiceProvider);
      
      // Fetch concurrently to minimize page load times
      final results = await Future.wait([
        service.getCommunityStats(),
        service.getFeed(),
        service.getMyReports(),
        service.getAlerts(),
        service.getVerified(),
      ]);

      if (mounted) {
        setState(() {
          _stats = results[0] as Map<String, dynamic>;
          _feedReports = results[1] as List<Map<String, dynamic>>;
          _myReports = results[2] as List<Map<String, dynamic>>;
          _alerts = results[3] as List<Map<String, dynamic>>;
          _verifiedReports = results[4] as List<Map<String, dynamic>>;
          _isLoading = false;
          _buildTriggerCount++; // Trigger staggered animation
        });
        _startPollingIfNeeded();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _silentReloadData() async {
    try {
      final service = ref.read(communityThreatServiceProvider);
      final results = await Future.wait([
        service.getCommunityStats(),
        service.getFeed(),
        service.getMyReports(),
        service.getAlerts(),
        service.getVerified(),
      ]);

      if (mounted) {
        setState(() {
          _stats = results[0] as Map<String, dynamic>;
          _feedReports = results[1] as List<Map<String, dynamic>>;
          _myReports = results[2] as List<Map<String, dynamic>>;
          _alerts = results[3] as List<Map<String, dynamic>>;
          _verifiedReports = results[4] as List<Map<String, dynamic>>;
        });
        _startPollingIfNeeded();
      }
    } catch (_) {}
  }

  Future<void> _refresh() async {
    await _loadAllData();
  }

  void _openReportForm() {
    context.push('/community-reports/new').then((_) {
      _refresh();
    });
  }

  void _dismissAlert(String id) {
    setState(() {
      _dismissedAlertIds.add(id);
    });
    // NOTE: Backend dismissal synchronization would be done here via a DELETE/POST API.
    // For now, it is handled visually in the client presentation layer to protect existing endpoints.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Alert acknowledged'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Merged Feed: Threats + Alerts
  // Justification: Alerts are merged client-side into the Latest Threat Feed tab chronologically.
  // Note: This client-side merge is a stopgap that should eventually move server-side.
  List<Map<String, dynamic>> get _mergedFeed {
    final merged = <Map<String, dynamic>>[];
    final seenIds = <String>{};
    
    // Tag and add threat reports
    for (final item in _feedReports) {
      final id = (item['id'] ?? item['threat_id'] ?? '').toString();
      if (id.isNotEmpty) {
        seenIds.add(id);
      }
      merged.add({
        ...item,
        'item_type': 'threat',
      });
    }

    // Tag and add alerts (if not dismissed)
    for (final item in _alerts) {
      final alertId = item['id']?.toString() ?? '';
      if (alertId.isNotEmpty && !_dismissedAlertIds.contains(alertId) && !seenIds.contains(alertId)) {
        seenIds.add(alertId);
        merged.add({
          ...item,
          'item_type': 'alert',
        });
      }
    }

    // Sort chronologically (newest first) based on created_at
    merged.sort((a, b) {
      final aDateStr = a['created_at']?.toString() ?? '';
      final bDateStr = b['created_at']?.toString() ?? '';
      if (aDateStr.isEmpty) return 1;
      if (bDateStr.isEmpty) return -1;
      return bDateStr.compareTo(aDateStr);
    });

    // Final list deduplication pass to prevent duplicate threat/alert items
    final uniqueMerged = <Map<String, dynamic>>[];
    final finalSeen = <String>{};
    for (final item in merged) {
      final id = (item['id'] ?? item['threat_id'] ?? '').toString();
      if (id.isEmpty) {
        uniqueMerged.add(item);
      } else if (!finalSeen.contains(id)) {
        finalSeen.add(id);
        uniqueMerged.add(item);
      }
    }

    return uniqueMerged;
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = context.bg;
    final textPrimary = context.textPrimary;
    final activeGreen = const Color(0xFF16A34A);

    // Setup selected tab content
    List<Map<String, dynamic>> activeList = [];
    if (_selectedFilterIndex == 0) {
      activeList = _mergedFeed;
    } else if (_selectedFilterIndex == 1) {
      final seen = <String>{};
      final deduped = <Map<String, dynamic>>[];
      for (final item in _myReports) {
        final id = (item['id'] ?? item['threat_id'] ?? '').toString();
        if (id.isEmpty || !seen.contains(id)) {
          if (id.isNotEmpty) seen.add(id);
          deduped.add(item);
        }
      }
      activeList = deduped;
    } else if (_selectedFilterIndex == 2) {
      final seen = <String>{};
      final deduped = <Map<String, dynamic>>[];
      for (final item in _verifiedReports) {
        final id = (item['id'] ?? item['threat_id'] ?? item['url_hash'] ?? '').toString();
        if (id.isEmpty || !seen.contains(id)) {
          if (id.isNotEmpty) seen.add(id);
          deduped.add(item);
        }
      }
      activeList = deduped;
    }

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openReportForm,
        backgroundColor: activeGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_moderator),
        label: const Text('Report Threat', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: activeGreen,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Pinned Material 3 SliverAppBar (Notification Icon removed per requirements)
            SliverAppBar(
              pinned: true,
              backgroundColor: context.cardBg,
              surfaceTintColor: Colors.transparent,
              centerTitle: false,
              title: Text(
                'Community Threat Intelligence',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refresh,
                ),
              ],
            ),

            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF16A34A)),
                ),
              )
            else ...[
              // Community Protection Shield Hero Banner
              SliverToBoxAdapter(
                child: CommunityProtectionCard(stats: _stats),
              ),

              // Segmented navigation filter / switcher (Pinned content selection)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<int>(
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: activeGreen.withOpacity(0.15),
                          selectedForegroundColor: activeGreen,
                          side: BorderSide(color: context.border),
                        ),
                        segments: const <ButtonSegment<int>>[
                          ButtonSegment<int>(
                            value: 0,
                            label: Text('Feed', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            icon: Icon(Icons.rss_feed, size: 14),
                          ),
                          ButtonSegment<int>(
                            value: 1,
                            label: Text('My Reports', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            icon: Icon(Icons.person_pin, size: 14),
                          ),
                          ButtonSegment<int>(
                            value: 2,
                            label: Text('Verified Intel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            icon: Icon(Icons.gpp_good, size: 14),
                          ),
                        ],
                        selected: <int>{_selectedFilterIndex},
                        onSelectionChanged: (Set<int> newSelection) {
                          setState(() {
                            _selectedFilterIndex = newSelection.first;
                            _buildTriggerCount++; // Re-trigger animations
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // Active tab list view
              if (activeList.isEmpty)
                SliverToBoxAdapter(
                  child: _buildEmptyState(_selectedFilterIndex),
                )
              else if (_selectedFilterIndex == 0) ...[
                // Unified Feed (Threats + Alerts)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = activeList[index];
                      final isAlert = item['item_type'] == 'alert';
                      
                      if (isAlert) {
                        return _buildStaggeredEntrance(
                          index,
                          CommunityAlertCard(
                            alert: item,
                            onDismiss: _dismissAlert,
                            onTap: () {
                              if (item['related_report_id'] != null) {
                                context.push('/community-reports/${item['related_report_id']}');
                              }
                            },
                          ),
                        );
                      } else {
                        final threatId = item['id'] ?? item['threat_id'] ?? '';
                        return _buildStaggeredEntrance(
                          index,
                          ThreatFeedCard(
                            data: item,
                            index: index,
                            onTap: () => context.push('/community-reports/$threatId'),
                          ),
                        );
                      }
                    },
                    childCount: activeList.length,
                  ),
                ),
              ] else if (_selectedFilterIndex == 1) ...[
                // Custom Reports Tracker Section
                SliverToBoxAdapter(
                  child: ReportsPreviewCard(
                    reports: _myReports,
                    onViewAll: () {
                      setState(() {
                        _selectedFilterIndex = 1;
                      });
                    },
                    onReportNew: _openReportForm,
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _myReports[index];
                      return _buildStaggeredEntrance(
                        index,
                        ThreatFeedCard(
                          data: item,
                          index: index,
                          onTap: () => context.push('/community-reports/${item['id']}'),
                        ),
                      );
                    },
                    childCount: _myReports.length,
                  ),
                ),
              ] else ...[
                // Verified list
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final report = activeList[index];
                      final threatId = report['id'] ?? report['threat_id'] ?? '';
                      return _buildStaggeredEntrance(
                        index,
                        ThreatFeedCard(
                          data: report,
                          index: index,
                          onTap: () => context.push('/community-reports/$threatId'),
                        ),
                      );
                    },
                    childCount: activeList.length,
                  ),
                ),
              ],

              // Daily Security Tip Card (rotates deterministically)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: SecurityTipCard(),
                ),
              ),

              // Bottom Spacer to clear the Extended FloatingActionButton
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Staggered Fade & Slide-In Animation wrapper (triggered on load, not on scroll)
  Widget _buildStaggeredEntrance(int index, Widget child) {
    return FutureBuilder(
      future: Future.delayed(Duration(milliseconds: 50 * index)),
      builder: (context, snapshot) {
        final animated = snapshot.connectionState == ConnectionState.done;
        return AnimatedOpacity(
          opacity: animated ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, animated ? 0 : 20, 0),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(int filterIndex) {
    String msg = 'No threat reports currently active.';
    if (filterIndex == 1) {
      msg = "You haven't submitted any community reports yet.";
    } else if (filterIndex == 2) {
      msg = "No confirmed community threats logged yet.";
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: [
          // Shield Custom Painter for empty states
          CustomPaint(
            size: const Size(60, 60),
            painter: ShieldEmptyStatePainter(color: Colors.grey.withOpacity(0.5)),
          ),
          const SizedBox(height: 18),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (filterIndex == 1) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _openReportForm,
              icon: const Icon(Icons.add_moderator, size: 16),
              label: const Text('File New Report', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Custom Painter for empty state illustration
class ShieldEmptyStatePainter extends CustomPainter {
  final Color color;
  ShieldEmptyStatePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final path = Path();
    path.moveTo(size.width * 0.5, size.height * 0.1);
    path.quadraticBezierTo(size.width * 0.8, size.height * 0.1, size.width * 0.85, size.height * 0.2);
    path.quadraticBezierTo(size.width * 0.85, size.height * 0.6, size.width * 0.5, size.height * 0.9);
    path.quadraticBezierTo(size.width * 0.15, size.height * 0.6, size.width * 0.15, size.height * 0.2);
    path.quadraticBezierTo(size.width * 0.2, size.height * 0.1, size.width * 0.5, size.height * 0.1);
    
    canvas.drawPath(path, paint);

    // Inner checkmark
    final checkPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    final checkPath = Path();
    checkPath.moveTo(size.width * 0.35, size.height * 0.48);
    checkPath.lineTo(size.width * 0.47, size.height * 0.6);
    checkPath.lineTo(size.width * 0.65, size.height * 0.38);
    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
