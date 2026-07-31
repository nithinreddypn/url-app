import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../services/community_threat_service.dart';
import '../providers/app_providers.dart';

class AdminCommunityReportsPage extends ConsumerStatefulWidget {
  const AdminCommunityReportsPage({super.key});

  @override
  ConsumerState<AdminCommunityReportsPage> createState() => _AdminCommunityReportsPageState();
}

class _AdminCommunityReportsPageState extends ConsumerState<AdminCommunityReportsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];

  final List<Map<String, String>> _tabs = [
    {'value': 'highest_priority', 'label': '🔥 Highest'},
    {'value': 'high', 'label': 'High'},
    {'value': 'medium', 'label': 'Medium'},
    {'value': 'low', 'label': 'Low'},
    {'value': 'approved', 'label': 'Approved'},
    {'value': 'rejected', 'label': 'Rejected'},
    {'value': 'duplicate', 'label': 'Duplicates'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadReports();
      }
    });
    _loadReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final service = ref.read(communityThreatServiceProvider);
      final currentTab = _tabs[_tabController.index]['value']!;
      final items = await service.getAdminReports(currentTab);
      setState(() {
        _reports = items;
      });
    } catch (_) {
      // Handle silently
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _approve(String id) async {
    try {
      final service = ref.read(communityThreatServiceProvider);
      await service.approveReport(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report approved and intelligence updated!'), backgroundColor: Colors.green),
      );
      _loadReports();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approve failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _reject(String id) async {
    try {
      final service = ref.read(communityThreatServiceProvider);
      await service.rejectReport(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report marked as rejected.'), backgroundColor: Colors.orange),
      );
      _loadReports();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reject failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _merge(String id) async {
    final TextEditingController targetIdController = TextEditingController();
    final targetId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.cardBg,
        title: const Text('Merge Duplicate Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the Target Report ID that this report should be merged into:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetIdController,
              decoration: InputDecoration(
                hintText: 'Target Report ID (UUID)',
                hintStyle: TextStyle(color: context.textSecondary.withOpacity(0.5)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: context.border)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: context.activeAccent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, targetIdController.text.trim()),
            child: const Text('Merge', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (targetId == null || targetId.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final service = ref.read(communityThreatServiceProvider);
      await service.mergeReport(reportId: id, targetId: targetId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report merged successfully!'), backgroundColor: Colors.green),
      );
      _loadReports();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Merge failed: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _blockReporter(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.cardBg,
        title: const Text('Confirm Block'),
        content: const Text('Are you sure you want to block this user from submitting threat reports?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Block', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final service = ref.read(communityThreatServiceProvider);
      await service.blockReporter(userId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reporter successfully blocked.'), backgroundColor: Colors.red),
      );
      _loadReports();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Block failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final isAuthorized = user?.role == 'admin' || user?.role == 'moderator';

    if (!isAuthorized) {
      return Scaffold(
        backgroundColor: context.bg,
        body: Center(
          child: Text(
            'Access Denied. Administrator clearance required.',
            style: TextStyle(color: context.danger, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final border = context.border;
    final primaryGreen = context.activeAccent;

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text('Admin Threat Queue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: context.cardBg,
        elevation: 0,
        bottom: TabBar(
          dividerColor: Colors.transparent,
          controller: _tabController,
          isScrollable: true,
          labelColor: primaryGreen,
          unselectedLabelColor: textSecondary,
          indicatorColor: primaryGreen,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: _tabs.map((tab) => Tab(text: tab['label']!)).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified_user_outlined, size: 40, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        'No community reports in this category.',
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reports.length,
                  itemBuilder: (context, idx) {
                    final report = _reports[idx];
                    return _buildAdminReportCard(report);
                  },
                ),
    );
  }

  Widget _buildAdminReportCard(Map<String, dynamic> report) {
    final cardBg = context.cardBg;
    final surfaceColor = context.border;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final primaryGreen = context.activeAccent;

    final id = report['id'] ?? '';
    final url = report['url'] ?? '';
    final category = report['threat_category'] ?? 'phishing';
    final desc = report['description'] ?? '';
    final count = report['report_count'] ?? 1;
    final reporterName = report['reporter_name'] ?? 'Anonymous';
    final reporterId = report['reporter_id'] ?? '';
    final confidence = report['confidence_score'] ?? 50;
    final priority = report['priority_score'] ?? 0.0;
    final priorityTier = report['priority_tier'] ?? 'Low';
    final screenshot = report['screenshot_url'];

    // Community votes metrics
    final confirmVotes = report['confirm_votes'] ?? 0;
    final safeVotes = report['safe_votes'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaceColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // URL and Category Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: SelectableText(
                  url,
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  category.toString().toUpperCase(),
                  style: TextStyle(color: context.warning, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // ID Reference (useful for merging)
          SelectableText(
            'Report ID: $id',
            style: TextStyle(color: textSecondary.withOpacity(0.6), fontSize: 10, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            desc,
            style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
          ),
          if (screenshot != null && screenshot.toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    child: Image.network('http://127.0.0.1:8123' + screenshot.toString()),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  'http://127.0.0.1:8123' + screenshot.toString(),
                  height: 100,
                  width: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Metrics grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfaceColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetric('Priority', '$priority', context.warning),
                _buildMetric('Confidence', '$confidence%', primaryGreen),
                _buildMetric('Reporters', '$count', textPrimary),
                _buildMetric('Votes (Y/N)', '$confirmVotes / $safeVotes', textSecondary),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Submitted by: $reporterName',
            style: TextStyle(color: textSecondary, fontSize: 11, fontStyle: FontStyle.italic),
          ),

          const Divider(height: 24, color: Colors.grey),

          // Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _blockReporter(reporterId),
                icon: const Icon(Icons.block, size: 14, color: Colors.red),
                label: const Text('Block User', style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
              TextButton.icon(
                onPressed: () => _merge(id),
                icon: const Icon(Icons.merge_type, size: 14, color: Colors.blue),
                label: const Text('Merge', style: TextStyle(color: Colors.blue, fontSize: 12)),
              ),
              ElevatedButton.icon(
                onPressed: () => _reject(id),
                icon: const Icon(Icons.close, size: 14, color: Colors.white),
                label: const Text('Reject', style: TextStyle(color: Colors.white, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _approve(id),
                icon: const Icon(Icons.check, size: 14, color: Colors.black),
                label: const Text('Approve', style: TextStyle(color: Colors.black, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: context.textSecondary, fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
