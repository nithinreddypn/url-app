import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import '../models/url_scan_model.dart';
import '../services/url_scan_service.dart';
import '../providers/app_providers.dart';

class ScanHistoryScreen extends ConsumerStatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  ConsumerState<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends ConsumerState<ScanHistoryScreen> {
  Color get _bgColor => context.bg;
  Color get _cardColor => context.cardBg;
  Color get _surfaceColor => context.border;
  Color get _primaryGreen => context.activeAccent;
  Color get _amber => context.isDark ? Color(0xFFF59E0B) : Color(0xFFD97706);
  Color get _red => context.isDark ? Color(0xFFEF4444) : Color(0xFFDC2626);

  Color get _textPrimary => context.textPrimary;

  final _scanService = UrlScanService();
  bool _isLoading = true;
  List<UrlScanModel> _allScans = [];
  List<UrlScanModel> _filteredScans = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _searchController.addListener(_filterScans);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final userId = ref.read(userProvider)?.userId;
      if (userId != null) {
        final scans = await _scanService.getUserScans(userId);
        setState(() {
          _allScans = scans;
          _filteredScans = scans;
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  void _filterScans() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredScans = _allScans;
      } else {
        _filteredScans = _allScans.where((scan) {
          final urlMatch = scan.scannedUrl.toLowerCase().contains(query);
          final resultMatch = (scan.scanResult ?? '').toLowerCase().contains(query);
          final threatMatch = (scan.threatType ?? '').toLowerCase().contains(query);
          return urlMatch || resultMatch || threatMatch;
        }).toList();
      }
    });
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
    ref.watch(scanHistoryProvider).whenData((scans) {
      _allScans = scans;
      // Re-filter scans list
      final query = _searchController.text.toLowerCase().trim();
      if (query.isEmpty) {
        _filteredScans = scans;
      } else {
        _filteredScans = scans.where((scan) {
          final urlMatch = scan.scannedUrl.toLowerCase().contains(query);
          final resultMatch = (scan.scanResult ?? '').toLowerCase().contains(query);
          final threatMatch = (scan.threatType ?? '').toLowerCase().contains(query);
          return urlMatch || resultMatch || threatMatch;
        }).toList();
      }
    });

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
          'Scan History',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchInput(),
          Expanded(
            child: RefreshIndicator(
              color: _primaryGreen,
              backgroundColor: _cardColor,
              onRefresh: () async {
                ref.invalidate(scanHistoryProvider);
                await _loadHistory();
              },
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: _primaryGreen,
                      ),
                    )
                  : _filteredScans.isEmpty
                      ? _buildEmptyState()
                      : _buildHistoryList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchInput() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: Offset(0, 4),
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
              padding: EdgeInsets.only(left: 14, right: 10),
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
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              borderSide: BorderSide(
                color: _primaryGreen,
                width: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _cardColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.history_rounded,
                  size: 48,
                  color: _textPrimary.withValues(alpha: 0.2),
                ),
              ),
              SizedBox(height: 18),
              Text(
                _allScans.isEmpty ? 'No scan history' : 'No results found',
                style: TextStyle(
                  color: _textPrimary.withValues(alpha: 0.6),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 6),
              Text(
                _allScans.isEmpty
                    ? 'Start scanning URLs to view them here.'
                    : 'Try checking your spelling or search terms.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textPrimary.withValues(alpha: 0.3),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 40),
      itemCount: _filteredScans.length,
      itemBuilder: (context, index) {
        final scan = _filteredScans[index];
        return _buildScanHistoryCard(scan);
      },
    );
  }

  Widget _buildScanHistoryCard(UrlScanModel scan) {
    final isSafe = scan.isSafe;
    final resultColor = isSafe ? _primaryGreen : _red;
    final riskScore = scan.riskScore ?? 0;

    Color riskColor;
    if (riskScore < 30) {
      riskColor = _primaryGreen;
    } else if (riskScore < 60) {
      riskColor = _amber;
    } else {
      riskColor = _red;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/scan-detail/${scan.scanId}'),
        child: Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: resultColor.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Scan status badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: resultColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSafe ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                            color: resultColor,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            isSafe ? 'SAFE' : (scan.threatType ?? 'DANGEROUS').toUpperCase(),
                            style: TextStyle(
                              color: resultColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Risk score badge
                    Row(
                      children: [
                        Text(
                          'Risk Score: ',
                          style: TextStyle(
                            color: _textPrimary.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '$riskScore%',
                          style: TextStyle(
                            color: riskColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),
                // Scanned URL
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.link_rounded,
                      size: 16,
                      color: _textPrimary.withValues(alpha: 0.3),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        scan.scannedUrl,
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Divider(color: _surfaceColor, height: 1),
                SizedBox(height: 10),
                // Timestamp and reports
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _timeAgo(scan.scannedAt),
                      style: TextStyle(
                        color: _textPrimary.withValues(alpha: 0.3),
                        fontSize: 12,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.bug_report_outlined,
                          size: 14,
                          color: _textPrimary.withValues(alpha: 0.3),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'VT: ${scan.virusTotalFlags}',
                          style: TextStyle(
                            color: _textPrimary.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
