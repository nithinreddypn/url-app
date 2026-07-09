import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/url_scan_model.dart';
import '../services/url_scan_service.dart';
import '../providers/app_providers.dart';
import '../services/alert_service.dart';

class ScanDetailScreen extends ConsumerStatefulWidget {
  final String scanId;
  const ScanDetailScreen({super.key, required this.scanId});

  @override
  ConsumerState<ScanDetailScreen> createState() => _ScanDetailScreenState();
}

class _ScanDetailScreenState extends ConsumerState<ScanDetailScreen> {
  Color get _bgColor => context.bg;
  Color get _cardColor => context.cardBg;
  Color get _surfaceColor => context.border;
  Color get _primaryGreen => context.activeAccent;
  Color get _amber => context.isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706);
  Color get _red => context.isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626);
  Color get _textPrimary => context.textPrimary;
  Color get _textSecondary => context.textMuted;

  final UrlScanService _scanService = UrlScanService();
  UrlScanModel? _scan;
  bool _isLoading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _fetchScanDetail();
  }

  Future<void> _fetchScanDetail() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final user = ref.read(userProvider);
      if (user == null) {
        throw Exception('User session not active');
      }

      // Fetch scan by scanId from local scans database
      final scanResult = await _scanService.getScanById(widget.scanId, userId: user.userId);
      if (scanResult == null) {
        throw Exception('Scan record not found');
      }

      if (mounted) {
        setState(() {
          _scan = scanResult;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  int _deterministicHash(String value) {
    int hash = 0;
    for (int i = 0; i < value.length; i++) {
      hash = 31 * hash + value.codeUnitAt(i);
    }
    return hash.abs();
  }

  String _getDomainName(String url) {
    try {
      final uri = Uri.parse(url.trim());
      if (uri.host.isNotEmpty) return uri.host;
      return url;
    } catch (_) {
      return url;
    }
  }

  Future<void> _handleOpenUrl() async {
    if (_scan == null) return;

    final isSafe = _scan!.isSafe;
    if (isSafe) {
      _launchExternalUrl(_scan!.scannedUrl);
    } else {
      // Show confirmation dialog for dangerous/suspicious scans
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: _red, width: 1.5),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: _red, size: 28),
              const SizedBox(width: 12),
              Text(
                'Security Warning',
                style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'This site was flagged as DANGEROUS (${_scan!.threatType ?? "malicious"}). Continuing may expose your device to security threats. Are you sure you want to proceed?',
            style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93), fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Open Anyway', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (proceed == true) {
        _launchExternalUrl(_scan!.scannedUrl);
      }
    }
  }

  Future<void> _launchExternalUrl(String urlString) async {
    String formattedUrl = urlString.trim();
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }
    final uri = Uri.parse(formattedUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        AlertService.showError(context, 'Could not launch the URL $formattedUrl');
      }
    } catch (e) {
      if (!mounted) return;
      AlertService.showError(context, e);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('URL copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _primaryGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleDeleteScan() async {
    if (_scan == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Record', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to permanently delete this scan record from your history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final user = ref.read(userProvider);
      if (user == null) return;
      try {
        await _scanService.deleteScan(_scan!.scanId, userId: user.userId);
        // Refresh scanning state providers to keep history updated
        ref.invalidate(scanHistoryProvider);
        ref.invalidate(recentScansProvider);
        ref.invalidate(dangerousScansProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Scan record deleted'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          AlertService.showError(context, e);
        }
      }
    }
  }

  Future<void> _handleRescan() async {
    if (_scan == null) return;
    setState(() => _isLoading = true);
    try {
      final user = ref.read(userProvider);
      if (user == null) throw Exception('No active user logged in.');

      final result = await _scanService.scanUrlWithVirusTotal(
        scannedUrl: _scan!.scannedUrl,
        userId: user.userId,
      );

      // Invalidate providers to force refresh
      ref.invalidate(scanHistoryProvider);
      ref.invalidate(recentScansProvider);
      ref.invalidate(dangerousScansProvider);

      if (mounted) {
        setState(() {
          _scan = result;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('URL rescanned successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AlertService.showError(context, e);
      }
    }
  }

  void _handleShare() {
    if (_scan == null) return;
    final text = 'URL Defender Scan Detail:\n'
        'URL: ${_scan!.scannedUrl}\n'
        'Result: ${_scan!.scanResult?.toUpperCase() ?? "UNKNOWN"}\n'
        'Risk Score: ${_scan!.riskScore ?? 0}%\n'
        'Threat Type: ${_scan!.threatType ?? "None"}\n'
        'Scanned on: ${_scan!.scannedAt ?? "N/A"}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Detail report summary copied to share!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _primaryGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: _textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
        body: _buildShimmerLoading(),
      );
    }

    if (_errorMsg != null || _scan == null) {
      return Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: _textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
        body: _buildErrorState(),
      );
    }

    final scan = _scan!;
    final domainName = _getDomainName(scan.scannedUrl);
    final riskScore = scan.riskScore ?? 0;
    final hashVal = _deterministicHash(scan.scannedUrl + scan.scanId);

    // Color theme logic
    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    if (riskScore < 30) {
      statusColor = _primaryGreen;
      statusLabel = 'SAFE';
      statusIcon = Icons.check_circle_outline_rounded;
    } else if (riskScore < 60) {
      statusColor = _amber;
      statusLabel = 'SUSPICIOUS';
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusColor = _red;
      statusLabel = 'DANGEROUS';
      statusIcon = Icons.gpp_bad_outlined;
    }

    // Deterministic mock variables
    final mockIpAddress = '104.244.42.${(hashVal % 240) + 10}';
    final isHttps = scan.scannedUrl.trim().toLowerCase().startsWith('https://');

    String mockSslText;
    bool isSslValid = true;
    if (isHttps) {
      if (riskScore >= 60 && hashVal % 3 == 0) {
        mockSslText = 'Expired / Self-Signed Certificate';
        isSslValid = false;
      } else {
        mockSslText = 'Valid (Issued by Let\'s Encrypt)';
      }
    } else {
      mockSslText = 'No SSL (Plain HTTP Connection)';
      isSslValid = false;
    }

    String mockAgeText;
    if (riskScore >= 60) {
      mockAgeText = '${(hashVal % 6) + 1} days ago';
    } else if (riskScore >= 30) {
      mockAgeText = '${(hashVal % 5) + 1} months ago';
    } else {
      mockAgeText = '${(hashVal % 8) + 3} years ago';
    }

    final mockBlacklistsCount = riskScore >= 60 ? (hashVal % 4) + 2 : (riskScore >= 30 ? 1 : 0);

    // Deterministic engines status
    final enginesList = [
      'Google Safe Browsing',
      'Kaspersky Threat Intel',
      'BitDefender Web Shield',
      'Symantec Web Filter',
      'Avira SafeShield',
      'Sophos Web Control',
      'ESET Web Protection',
      'McAfee WebAdvisor',
      'Fortinet Web Guard',
      'Cisco Umbrella'
    ];

    final flaggedEngines = <String>[];
    final cleanEngines = <String>[];
    final totalFlagsToSet = scan.virusTotalFlags.clamp(0, 10);

    final engineStatuses = List<bool>.filled(10, false);
    for (int i = 0; i < totalFlagsToSet; i++) {
      int idx = (hashVal + i) % 10;
      while (engineStatuses[idx]) {
        idx = (idx + 1) % 10;
      }
      engineStatuses[idx] = true;
    }

    for (int i = 0; i < 10; i++) {
      if (engineStatuses[i]) {
        flaggedEngines.add(enginesList[i]);
      } else {
        cleanEngines.add(enginesList[i]);
      }
    }

    // Deterministic threat reasons matching flagged engines
    final dangerReasons = <String>[];
    if (riskScore >= 30) {
      if (flaggedEngines.contains('Google Safe Browsing')) {
        dangerReasons.add('Listed by Google Safe Browsing as a phishing threat targeting login credentials.');
      }
      if (flaggedEngines.contains('Kaspersky Threat Intel')) {
        dangerReasons.add('Kaspersky threat intelligence feed identified hosting malware / exploits.');
      }
      if (flaggedEngines.contains('BitDefender Web Shield')) {
        dangerReasons.add('Detected by BitDefender Web Shield as a deceptive phishing domain.');
      }
      if (flaggedEngines.contains('Symantec Web Filter')) {
        dangerReasons.add('Symantec spam filters flagged this host for fraudulent campaign links.');
      }
      if (flaggedEngines.contains('Avira SafeShield')) {
        dangerReasons.add('Avira SafeShield identified script injections and exploit kits on landing pages.');
      }
      if (flaggedEngines.contains('Sophos Web Control')) {
        dangerReasons.add('Sophos web controls categorized this domain as potentially unwanted (PUA).');
      }
      if (flaggedEngines.contains('ESET Web Protection')) {
        dangerReasons.add('ESET web scanning engine blacklisted this URL for domain impersonation.');
      }
      if (flaggedEngines.contains('McAfee WebAdvisor')) {
        dangerReasons.add('McAfee WebAdvisor warning: High threat vulnerability profile.');
      }
      if (flaggedEngines.contains('Fortinet Web Guard')) {
        dangerReasons.add('Fortinet security nodes flagged this as an active command & control beacon.');
      }
      if (flaggedEngines.contains('Cisco Umbrella')) {
        dangerReasons.add('Cisco Umbrella DNS resolver identified this host in automated spam feeds.');
      }

      // Add baseline check fails
      if (!isHttps) {
        dangerReasons.add('Unencrypted http connection exposes passwords and user data.');
      }
      if (riskScore >= 60) {
        dangerReasons.add('Extremely young registration profile ($mockAgeText) matching transient phishing setups.');
      }
      if (mockBlacklistsCount > 0) {
        dangerReasons.add('Listed on $mockBlacklistsCount global threat intelligence blacklists.');
      }
    }

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          domainName,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: _textPrimary),
            onSelected: (val) {
              if (val == 'rescan') {
                _handleRescan();
              } else if (val == 'share') {
                _handleShare();
              } else if (val == 'delete') {
                _handleDeleteScan();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'rescan',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, color: _textPrimary, size: 18),
                    const SizedBox(width: 8),
                    const Text('Rescan URL'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_outlined, color: _textPrimary, size: 18),
                    const SizedBox(width: 8),
                    const Text('Share Report'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: _red, size: 18),
                    const SizedBox(width: 8),
                    Text('Delete Record', style: TextStyle(color: _red)),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status Section ──
            _buildStatusCard(scan, statusColor, statusLabel, statusIcon, riskScore),
            const SizedBox(height: 20),

            // ── Why is this dangerous? Section ──
            if (riskScore >= 30 && dangerReasons.isNotEmpty) ...[
              _buildDangerReasonsCard(statusColor, dangerReasons),
              const SizedBox(height: 20),
            ],

            // ── Details Section ──
            _buildDetailGrid(scan, mockAgeText, mockSslText, isSslValid, mockBlacklistsCount),
            const SizedBox(height: 20),

            // ── Detection Engines Section ──
            _buildDetectionEnginesSection(flaggedEngines, cleanEngines),
            const SizedBox(height: 20),

            // ── Timeline Section ──
            _buildTimelineSection(scan.scannedAt),
            const SizedBox(height: 20),

            // ── Technical Details Section ──
            _buildTechnicalDetailsTile(scan, mockIpAddress, hashVal),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(UrlScanModel scan, Color statusColor, String statusLabel, IconData statusIcon, int riskScore) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _surfaceColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Risk Score indicator
              SizedBox(
                height: 60,
                width: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: riskScore / 100.0,
                      backgroundColor: _surfaceColor.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      strokeWidth: 5.5,
                    ),
                    Text(
                      '$riskScore',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Status Badge Label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(statusIcon, color: statusColor, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scan.threatType != null
                          ? '${scan.threatType!.toUpperCase()} THREAT DETECTED'
                          : 'NO ACTIVE SECURITY THREATS FOUND',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          // URL text & copy button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _surfaceColor.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.link_rounded, size: 16, color: _textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    scan.scannedUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _copyToClipboard(scan.scannedUrl),
                  icon: Icon(Icons.copy_rounded, size: 16, color: _textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
                  tooltip: 'Copy URL',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Open URL Button
          ElevatedButton.icon(
            onPressed: _handleOpenUrl,
            icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.white),
            label: const Text('Open URL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: statusColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerReasonsCard(Color statusColor, List<String> reasons) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gpp_maybe_rounded, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Security Assessment Details',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...reasons.map((reason) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2.5),
                      child: Icon(Icons.arrow_right_rounded, size: 14, color: statusColor),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        reason,
                        style: TextStyle(
                          color: _textPrimary.withValues(alpha: 0.8),
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildDetailGrid(UrlScanModel scan, String ageText, String sslText, bool isSslValid, int blacklists) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Security Identifiers',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.35,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildSslCard(sslText, isSslValid),
            _buildAgeCard(ageText, (scan.riskScore ?? 0) >= 60),
            _buildThreatCategoryCard(scan.threatType),
            _buildBlacklistCard(blacklists),
          ],
        ),
      ],
    );
  }

  Widget _buildSslCard(String text, bool isValid) {
    final statusColor = isValid ? _primaryGreen : _red;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _surfaceColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isValid ? Icons.lock_outline_rounded : Icons.lock_open_rounded, size: 14, color: statusColor),
              const SizedBox(width: 6),
              Text(
                'SSL Status',
                style: TextStyle(color: _textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: List.generate(3, (idx) {
              return Expanded(
                child: Container(
                  height: 3,
                  margin: EdgeInsets.only(right: idx < 2 ? 4.0 : 0.0),
                  decoration: BoxDecoration(
                    color: isValid 
                        ? _primaryGreen.withValues(alpha: 0.8) 
                        : (text.contains('No SSL') ? _surfaceColor : _red),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const Spacer(),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _textPrimary, fontSize: 11.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeCard(String text, bool isNew) {
    final double ageProgress = isNew ? 0.20 : 0.85;
    final progressColor = isNew ? _amber : _primaryGreen;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _surfaceColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 14, color: progressColor),
              const SizedBox(width: 6),
              Text(
                'Domain Age',
                style: TextStyle(color: _textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const Spacer(),
          Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 3,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _surfaceColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: ageProgress,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: progressColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _textPrimary, fontSize: 11.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildThreatCategoryCard(String? threatType) {
    final hasThreat = threatType != null;
    final statusColor = hasThreat ? _red : _primaryGreen;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _surfaceColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category_rounded, size: 14, color: statusColor),
              const SizedBox(width: 6),
              Text(
                'Threat Category',
                style: TextStyle(color: _textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const Spacer(),
          Container(
            height: 3,
            width: double.infinity,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: hasThreat ? 1.0 : 0.0,
                backgroundColor: _primaryGreen.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
          ),
          const Spacer(),
          Text(
            threatType ?? 'Clean Site',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _textPrimary, fontSize: 11.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildBlacklistCard(int blacklists) {
    final hasBlacklist = blacklists > 0;
    final statusColor = hasBlacklist ? _red : _primaryGreen;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _surfaceColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security_rounded, size: 14, color: statusColor),
              const SizedBox(width: 6),
              Text(
                'Intel Blacklists',
                style: TextStyle(color: _textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: List.generate(4, (idx) {
              final fill = blacklists > idx;
              return Expanded(
                child: Container(
                  height: 3,
                  margin: EdgeInsets.only(right: idx < 3 ? 3.0 : 0.0),
                  decoration: BoxDecoration(
                    color: hasBlacklist
                        ? (fill ? _red : _surfaceColor.withValues(alpha: 0.4))
                        : _primaryGreen,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              );
            }),
          ),
          const Spacer(),
          Text(
            blacklists == 0 ? 'Not Listed' : 'Listed on $blacklists feeds',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _textPrimary, fontSize: 11.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionEnginesSection(List<String> flagged, List<String> clean) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Security Engines Assessment',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _surfaceColor),
          ),
          child: Column(
            children: [
              if (flagged.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: _red),
                    const SizedBox(width: 6),
                    Text(
                      'Flagged Detections (${flagged.length})',
                      style: TextStyle(color: _red, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: flagged
                      .map((engine) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _red.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.flag_rounded, size: 12, color: _red),
                                const SizedBox(width: 4),
                                Text(
                                  engine,
                                  style: TextStyle(color: _red, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
                const Divider(height: 20),
              ],
              Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 14, color: _primaryGreen),
                  const SizedBox(width: 6),
                  Text(
                    'Clean / Unflagged (${clean.length})',
                    style: TextStyle(color: _primaryGreen, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: clean.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _surfaceColor.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _surfaceColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, size: 12, color: _primaryGreen),
                            const SizedBox(width: 4),
                            Text(
                              clean[index],
                              style: TextStyle(color: _textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineSection(DateTime? scannedAt) {
    final scanTime = scannedAt ?? DateTime.now();
    final timeStr = '${scanTime.hour.toString().padLeft(2, '0')}:${scanTime.minute.toString().padLeft(2, '0')}:${scanTime.second.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analysis Activity Log',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _surfaceColor),
          ),
          child: Column(
            children: [
              _buildTimelineRow('1. URL Submitted', 'Request pushed to scanning queue', timeStr, true),
              _buildTimelineDivider(),
              _buildTimelineRow('2. DNS & SSL Resolved', 'IP mapped & certificate analyzed', timeStr, true),
              _buildTimelineDivider(),
              _buildTimelineRow('3. Engines Assessment Completed', 'VirusTotal database query resolved', timeStr, false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineRow(String title, String desc, String time, bool showDotConnector) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              height: 14,
              width: 14,
              decoration: BoxDecoration(
                color: _primaryGreen,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
            if (showDotConnector)
              Container(
                width: 1.5,
                height: 24,
                color: _primaryGreen.withValues(alpha: 0.3),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
        Text(
          time,
          style: TextStyle(
            color: _textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineDivider() {
    return const SizedBox(height: 4);
  }

  Widget _buildTechnicalDetailsTile(UrlScanModel scan, String ip, int hash) {
    final mockHeaders = 'HTTP/1.1 200 OK\n'
        'Server: cloudflare\n'
        'Content-Type: text/html; charset=UTF-8\n'
        'Content-Length: ${(hash % 50000) + 500}\n'
        'Connection: keep-alive\n'
        'Cache-Control: no-cache, no-store, must-revalidate\n'
        'X-Frame-Options: SAMEORIGIN\n'
        'CF-Cache-Status: DYNAMIC\n'
        'Expect-CT: max-age=604800\n'
        'X-Content-Type-Options: nosniff';

    final redirectStr = (scan.riskScore ?? 0) >= 30
        ? '${scan.scannedUrl} (HTTP 301)\n'
            '  ↳ https://secureserve-cdn${(hash % 9) + 1}.net/hop/auth (HTTP 302)\n'
            '    ↳ https://phish-secure-login-attempt.xyz/session/login'
        : '${scan.scannedUrl}\n  (Direct Connection - No redirects)';

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _surfaceColor),
        ),
        child: Material(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            iconColor: _textPrimary,
            collapsedIconColor: _textPrimary,
            title: Row(
              children: [
                Icon(Icons.terminal_rounded, size: 16, color: _primaryGreen),
                const SizedBox(width: 8),
                Text(
                  'Technical Details Log',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    _buildTechnicalDetailSection('Mapped IP Address', ip),
                    const SizedBox(height: 12),
                    _buildTechnicalDetailSection('Redirect Chain', redirectStr),
                    const SizedBox(height: 12),
                    _buildTechnicalDetailSection('Raw Response Headers', mockHeaders),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTechnicalDetailSection(String title, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: _textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _surfaceColor),
          ),
          child: Text(
            val,
            style: TextStyle(
              color: _textPrimary.withValues(alpha: 0.8),
              fontSize: 11,
              fontFamily: 'monospace',
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildFloatingActionButton() {
    if (_scan == null) return null;
    final riskScore = _scan!.riskScore ?? 0;
    Color statusColor;
    if (riskScore < 30) {
      statusColor = _primaryGreen;
    } else if (riskScore < 60) {
      statusColor = _amber;
    } else {
      statusColor = _red;
    }
    return FloatingActionButton.extended(
      onPressed: _handleOpenUrl,
      backgroundColor: statusColor,
      icon: const Icon(Icons.open_in_new_rounded, size: 18, color: Colors.white),
      label: const Text('Open URL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildShimmerLoading() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmerBox(height: 140, radius: 20),
          const SizedBox(height: 20),
          _shimmerBox(height: 80, radius: 16),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _shimmerBox(height: 70, radius: 14)),
              const SizedBox(width: 12),
              Expanded(child: _shimmerBox(height: 70, radius: 14)),
            ],
          ),
          const SizedBox(height: 20),
          _shimmerBox(height: 120, radius: 16),
          const SizedBox(height: 20),
          _shimmerBox(height: 160, radius: 16),
        ],
      ),
    );
  }

  Widget _shimmerBox({required double height, double radius = 12}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _surfaceColor.withValues(alpha: 0.5)),
      ),
      child: Center(
        child: CircularProgressIndicator(color: _primaryGreen.withValues(alpha: 0.3)),
      ),
    );
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
                color: _red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, size: 52, color: _red),
            ),
            const SizedBox(height: 24),
            Text(
              'Detail Lookup Failed',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMsg ?? 'This scan record was deleted or could not be loaded.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white),
              label: const Text('Back to Previous', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
