import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../services/community_threat_service.dart';
import '../../services/api_client.dart';
import '../../providers/app_providers.dart';
import 'widgets/threat_status_badge.dart';
import 'widgets/verification_timeline.dart';

class CommunityReportDetailPage extends ConsumerStatefulWidget {
  final String reportId;

  const CommunityReportDetailPage({super.key, required this.reportId});

  @override
  ConsumerState<CommunityReportDetailPage> createState() => _CommunityReportDetailPageState();
}

class _CommunityReportDetailPageState extends ConsumerState<CommunityReportDetailPage> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _report = {};
  bool _voting = false;

  @override
  void initState() {
    super.initState();
    _loadReportDetail();
  }

  Future<void> _loadReportDetail() async {
    try {
      final service = ref.read(communityThreatServiceProvider);
      final data = await service.getReportDetail(widget.reportId);
      if (mounted) {
        setState(() {
          _report = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _vote(String type) async {
    setState(() {
      _voting = true;
    });
    try {
      final service = ref.read(communityThreatServiceProvider);
      await service.submitVote(reportId: widget.reportId, voteType: type);
      await _loadReportDetail(); // Reload to refresh timeline/votes
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vote counted. Re-evaluating verification...'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final message = (e is ApiException) ? (e.safeMessage ?? e.toString()) : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to vote: $message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _voting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = context.bg;
    final cardBg = context.cardBg;
    final border = context.border;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final primaryGreen = context.activeAccent;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A))),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $_errorMessage', style: TextStyle(color: textPrimary)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _loadReportDetail();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final url = _report['url'] ?? '';
    final category = _report['threat_category'] ?? 'Suspicious';
    final status = _report['verification_status'] ?? 'pending';
    final confidence = _report['confidence_score'] ?? 0;
    final reportCount = _report['report_count'] ?? 1;
    final description = _report['description'] ?? 'No description provided.';
    final timeline = _report['timeline'] ?? [];
    final userVote = _report['user_vote'] as String?;
    
    // Dates
    final firstReported = _report['created_at'] ?? 'Recently';
    final lastActivity = _report['last_reported_at'] ?? firstReported;

    // Vote metrics
    final confirmVotes = _report['confirm_votes'] ?? 0;
    final safeVotes = _report['safe_votes'] ?? 0;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Threat Analysis Details',
          style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textPrimary),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadReportDetail();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── 1. Header Card (URL + Status Badge + Hero Target) ───
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ThreatStatusBadge(status: status),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: border,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category.toUpperCase(),
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Target URL:',
                    style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  
                  // Shared Hero Animation Target
                  Hero(
                    tag: 'threat-url-${widget.reportId}',
                    child: Material(
                      color: Colors.transparent,
                      child: SelectableText(
                        url,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Confidence Score', style: TextStyle(color: textSecondary, fontSize: 11)),
                          const SizedBox(height: 4),
                          Text(
                            '$confidence%',
                            style: TextStyle(
                              color: confidence >= 75
                                  ? Colors.red
                                  : (confidence >= 45 ? Colors.orange : Colors.green),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Reports Count', style: TextStyle(color: textSecondary, fontSize: 11)),
                          const SizedBox(height: 4),
                          Text(
                            '$reportCount',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimeMetric('First Reported', firstReported),
                      ),
                      Expanded(
                        child: _buildTimeMetric('Last Activity', lastActivity),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── 2. Safety Recommendation ───
            _buildSafetyRecommendationCard(status),
            const SizedBox(height: 16),

            // ─── 3. Verification Sources ───
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: border),
              ),
              child: Builder(builder: (context) {
                final scan = _report['scan'];
                final scanResults = _report['scan_results'];
                final scanEngines = _report['scan_engines'] as List?;

                bool isEngineFlagged(String name) {
                  if (scanEngines == null) return false;
                  return scanEngines.any((e) {
                    final eName = e['engine_name'].toString().toLowerCase();
                    final flagged = e['flagged'] == 1 || e['flagged'] == true || e['flagged'] == '1';
                    return eName.contains(name.toLowerCase()) && flagged;
                  });
                }

                final vtDetections = scanEngines?.where((e) => e['flagged'] == 1 || e['flagged'] == true || e['flagged'] == '1').length ?? 0;
                final vtTotal = scanEngines?.length ?? 0;

                final blacklistListed = scanResults?['blacklist_listed'] ?? 0;
                final blacklistTotal = scanResults?['blacklist_total'] ?? 10;
                final domainAge = scanResults?['domain_age_days'];

                final hasScan = scan != null;

                // 1. VirusTotal info
                final vtText = hasScan 
                    ? (vtDetections > 0 ? 'Flagged by $vtDetections/$vtTotal engines' : 'All $vtTotal engines clean') 
                    : (confidence >= 75 ? 'Derived threat flag' : 'Derived safe status');
                final vtColor = hasScan 
                    ? (vtDetections > 0 ? Colors.red : Colors.green) 
                    : (confidence >= 75 ? Colors.red : Colors.green);

                // 2. Google Safe Browsing
                final googleFlagged = isEngineFlagged('Google') || isEngineFlagged('Safe Browsing');
                final googleText = hasScan 
                    ? (googleFlagged ? 'Flagged as phishing/malware' : 'No threat detected') 
                    : (confidence >= 75 ? 'Derived threat flag' : 'Derived safe status');
                final googleColor = hasScan 
                    ? (googleFlagged ? Colors.red : Colors.green) 
                    : (confidence >= 75 ? Colors.red : Colors.green);

                // 3. URL Defender AI
                final aiRisk = scan != null ? scan['risk_score'] : null;
                final aiText = aiRisk != null ? 'Risk score: $aiRisk%' : '$confidence% confidence rating';
                final aiColor = aiRisk != null 
                    ? (aiRisk >= 60 ? Colors.red : (aiRisk >= 30 ? Colors.orange : Colors.green))
                    : (confidence >= 75 ? Colors.red : (confidence >= 45 ? Colors.orange : Colors.green));

                // 4. Blocklists & Feeds
                final blocklistsFlagged = blacklistListed > 0;
                final blocklistsText = hasScan 
                    ? (blocklistsFlagged ? 'Listed on $blacklistListed/$blacklistTotal blacklists' : 'Not listed on any feeds') 
                    : (confidence >= 75 ? 'Derived threat flag' : 'Derived safe status');
                final blocklistsColor = hasScan 
                    ? (blocklistsFlagged ? Colors.red : Colors.green) 
                    : (confidence >= 75 ? Colors.red : Colors.green);

                // 5. Domain WHOIS Record
                String whoisText;
                Color whoisColor;
                if (hasScan && domainAge != null) {
                  if (domainAge < 30) {
                    whoisText = 'Registered $domainAge days ago (new/suspicious)';
                    whoisColor = Colors.red;
                  } else if (domainAge < 365) {
                    whoisText = 'Registered $domainAge days ago (moderate age)';
                    whoisColor = Colors.orange;
                  } else {
                    whoisText = 'Registered $domainAge days ago (established domain)';
                    whoisColor = Colors.green;
                  }
                } else {
                  whoisText = confidence >= 75 ? 'Derived warning flag' : 'Derived safe status';
                  whoisColor = confidence >= 75 ? Colors.orange : Colors.green;
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Security Engine & Verification Sources',
                      style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasScan 
                          ? '✅ Real-time integration active. Showing verified VirusTotal and WHOIS logs.' 
                          : '⚠️ Backend Gap: Detailed engine logs not found. Showing confidence-derived status.',
                      style: TextStyle(color: hasScan ? Colors.green : Colors.grey, fontSize: 10, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 16),
                    _buildSourceRow('VirusTotal Engine', vtText, vtColor),
                    _buildSourceRow('Google Safe Browsing', googleText, googleColor),
                    _buildSourceRow('URL Defender AI', aiText, aiColor),
                    _buildSourceRow('Blocklists & Feeds', blocklistsText, blocklistsColor),
                    _buildSourceRow('Domain WHOIS Record', whoisText, whoisColor),
                  ],
                );
              }),
            ),
            const SizedBox(height: 16),

            // ─── 4. Timeline ───
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verification Timeline',
                    style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  VerificationTimeline(timeline: timeline),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── 5. Description ───
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reporter Description',
                    style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: TextStyle(color: textSecondary, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Submitted by: Community Contributor',
                    style: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── 6. Voting & Community Opinion ───
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Community Verdict',
                    style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Help security workers verify by confirming or challenging the status of this report.',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _voting ? null : () => _vote('confirm_threat'),
                          icon: const Icon(Icons.thumb_up, color: Colors.red, size: 16),
                          label: const Text('Confirm Dangerous', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: userVote == 'confirm_threat' ? Colors.red : border),
                            backgroundColor: userVote == 'confirm_threat' ? Colors.red.withValues(alpha: 0.05) : Colors.transparent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _voting ? null : () => _vote('looks_safe'),
                          icon: const Icon(Icons.thumb_down, color: Colors.green, size: 16),
                          label: const Text('Looks Safe', style: TextStyle(color: Colors.green)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: userVote == 'looks_safe' ? Colors.green : border),
                            backgroundColor: userVote == 'looks_safe' ? Colors.green.withValues(alpha: 0.05) : Colors.transparent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Community Confirmed: $confirmVotes • Clean votes: $safeVotes',
                        style: TextStyle(color: textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: context.textSecondary, fontSize: 10),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: context.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildSafetyRecommendationCard(String status) {
    Color cardBorder;
    Color bgFill;
    String recTitle;
    String recMessage;
    IconData icon;

    final s = status.toLowerCase();
    if (s == 'approved' || s == 'verified' || s == 'high_risk') {
      cardBorder = const Color(0xFFEF4444);
      bgFill = const Color(0xFFEF4444).withValues(alpha: 0.05);
      recTitle = '🔴 CRITICAL SAFETY ALERT';
      recMessage = 'Avoid visiting this website. Do not enter login details, reveal passwords, or download any attachments. This page is confirmed malicious.';
      icon = Icons.gpp_bad;
    } else if (s == 'pending' || s == 'queued' || s == 'needs_review' || s == 'duplicate' || s == 'verification') {
      cardBorder = const Color(0xFFEAB308);
      bgFill = const Color(0xFFEAB308).withValues(alpha: 0.05);
      recTitle = '🟡 SAFETY ADVISORY';
      recMessage = 'This URL is currently under active investigation. Refrain from entering any credentials or personal info until review is complete.';
      icon = Icons.warning_amber;
    } else {
      cardBorder = const Color(0xFF22C55E);
      bgFill = const Color(0xFF22C55E).withValues(alpha: 0.05);
      recTitle = '🟢 SAFE SITE VERIFIED';
      recMessage = 'Automated engines and analyst review did not find any security threats. It appears safe to browse.';
      icon = Icons.verified;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgFill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cardBorder, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recTitle,
                  style: TextStyle(color: cardBorder, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  recMessage,
                  style: TextStyle(color: context.textPrimary, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceRow(String label, String result, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: context.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              result,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
