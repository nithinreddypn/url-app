// LINT-STYLE REMINDER:
// Never expose third-party provider names (VirusTotal, Google Safe Browsing, OpenPhish, URLHaus, PhishTank, WHOIS, etc.) anywhere in this UI.
// Always use the single branded phrase "URL Defender Threat Intelligence" for anything sourced from the verification pipeline.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../services/community_threat_service.dart';
import '../../providers/app_providers.dart';
import 'report_flow_wizard.dart';

class MyReportStatusScreen extends ConsumerStatefulWidget {
  final String? reportId;
  final String? url;

  const MyReportStatusScreen({
    super.key,
    this.reportId,
    this.url,
  });

  @override
  ConsumerState<MyReportStatusScreen> createState() => _MyReportStatusScreenState();
}

class _MyReportStatusScreenState extends ConsumerState<MyReportStatusScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _reportDetails;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    setState(() => _isLoading = true);

    try {
      final threatService = ref.read(communityThreatServiceProvider);
      
      if (widget.reportId != null) {
        final detail = await threatService.getReportDetail(widget.reportId!);
        setState(() {
          _reportDetails = detail['report'] ?? detail;
          _isLoading = false;
        });
      } else if (widget.url != null) {
        final check = await threatService.checkStatus(widget.url!);
        setState(() {
          _reportDetails = check['data'] ?? {
            'url': widget.url,
            'verification_status': 'pending',
            'threat_category': 'Suspicious',
            'report_count': 1,
          };
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
        _reportDetails = {
          'url': widget.url ?? 'Unknown URL',
          'verification_status': 'pending',
          'threat_category': 'Suspicious',
          'report_count': 1,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = context.bg;
    final cardBg = context.cardBg;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final activeGreen = const Color(0xFF16A34A);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        title: Text(
          'Investigation Tracker',
          style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)))
          : RefreshIndicator(
              onRefresh: _fetchStatus,
              color: activeGreen,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report Investigation Status',
                      style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    if (_reportDetails != null) ...[
                      // Report details header card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Target website:',
                              style: TextStyle(color: textSecondary, fontSize: 11),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              _reportDetails!['url'] ?? _reportDetails!['scanned_url'] ?? '',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildBadge(
                                  (_reportDetails!['verification_status'] ?? _reportDetails!['scan_result'] ?? 'pending').toString(),
                                ),
                                Text(
                                  'Category: ${(_reportDetails!['threat_category'] ?? _reportDetails!['threat_type'] ?? 'Suspicious').toString().toUpperCase()}',
                                  style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Stepper progress timeline
                      Text(
                        'Investigation Roadmap',
                        style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.border),
                        ),
                        child: ProgressTimeline(
                          status: _reportDetails!['verification_status'] ?? 'pending',
                          step3Completed: true,
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      Text(
                        'This roadmap shows the status of this link within URL Defender Threat Intelligence. Safe records will be updated automatically, and malicious threats will be blocked globally.',
                        style: TextStyle(color: textSecondary, fontSize: 11, height: 1.45),
                      ),
                    ] else ...[
                      Center(
                        child: Text(
                          'No details found for this report.',
                          style: TextStyle(color: textSecondary),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBadge(String status) {
    Color badgeColor = Colors.amber;
    String label = 'Investigation Pending';

    final cleanStatus = status.toLowerCase();
    if (cleanStatus == 'verified' || cleanStatus == 'approved' || cleanStatus == 'safe') {
      badgeColor = Colors.green;
      label = 'Verdict Decided';
    } else if (cleanStatus == 'high_risk' || cleanStatus == 'dangerous') {
      badgeColor = Colors.red;
      label = 'Dangerous Threat';
    } else if (cleanStatus == 'needs_review') {
      badgeColor = Colors.amber;
      label = 'Moderator Review';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
