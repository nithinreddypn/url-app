import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/blocked_url_model.dart';
import '../services/blocked_url_service.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../services/alert_service.dart';

class BlockedUrlsScreen extends ConsumerStatefulWidget {
  const BlockedUrlsScreen({super.key});

  @override
  ConsumerState<BlockedUrlsScreen> createState() => _BlockedUrlsScreenState();
}

class _BlockedUrlsScreenState extends ConsumerState<BlockedUrlsScreen> {
  final BlockedUrlService _blockedUrlService = BlockedUrlService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Color get _bgColor => context.bg;
  Color get _cardColor => context.cardBg;
  Color get _surfaceColor => context.border;
  Color get _primaryGreen => context.activeAccent;
  Color get _red => context.isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626);

  Color get _textPrimary => context.textPrimary;


  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
      });
    });
    // Refresh blocked URLs on entry
    Future.microtask(() {
      ref.invalidate(blockedUrlsProvider);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.isNegative || diff.inSeconds < 5) return 'Just now';
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _unblockUrl(BlockedUrlModel blockedUrl) async {
    try {
      final currentUser = ref.read(userProvider);
      if (currentUser == null) return;
      HapticFeedback.mediumImpact();
      await _blockedUrlService.unblockUrl(blockedUrl.id, userId: currentUser.userId);
      if (!mounted) return;
      AlertService.showSuccess(
        context,
        'URL Unblocked',
        'URL unblocked successfully.',
      );
      ref.invalidate(blockedUrlsProvider);
      await ref.read(userProvider.notifier).refreshUser();
    } catch (e) {
      if (!mounted) return;
      AlertService.showError(context, e);
    }
  }

  Future<void> _handleRefresh() async {
    ref.invalidate(blockedUrlsProvider);
    return ref.read(blockedUrlsProvider.future).then((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final blockedUrlsAsync = ref.watch(blockedUrlsProvider);

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
          'Blocked URLs',
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
              onRefresh: _handleRefresh,
              child: blockedUrlsAsync.when(
                data: (blockedUrls) {
                  final filteredList = blockedUrls.where((url) {
                    final urlMatch = url.url.toLowerCase().contains(_searchQuery);
                    final reasonMatch = (url.reason ?? '').toLowerCase().contains(_searchQuery);
                    return urlMatch || reasonMatch;
                  }).toList();

                  if (filteredList.isEmpty) {
                    return _buildEmptyState(blockedUrls.isEmpty);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final url = filteredList[index];
                      return _buildBlockedUrlCard(url);
                    },
                  );
                },
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: _primaryGreen,
                  ),
                ),
                error: (err, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Failed to load blocked URLs: $err',
                          style: TextStyle(color: _red, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(color: _textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search blocked URLs by domain or reason...',
            hintStyle: TextStyle(
              color: _textPrimary.withOpacity(0.3),
              fontSize: 13,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(
                Icons.search_rounded,
                color: _textPrimary.withOpacity(0.4),
                size: 20,
              ),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: _textPrimary.withOpacity(0.4),
                      size: 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                : null,
            filled: true,
            fillColor: _cardColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _textPrimary.withOpacity(0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _textPrimary.withOpacity(0.08),
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

  Widget _buildEmptyState(bool isListEmpty) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _cardColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: _surfaceColor),
                ),
                child: Icon(
                  Icons.link_off_rounded,
                  size: 48,
                  color: _textPrimary.withOpacity(0.2),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isListEmpty ? 'No Blocked URLs' : 'No results found',
                style: TextStyle(
                  color: _textPrimary.withOpacity(0.6),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isListEmpty
                    ? 'URLs blocked from scans will be listed here.'
                    : 'Try checking your spelling or search terms.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textPrimary.withOpacity(0.3),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBlockedUrlCard(BlockedUrlModel url) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _red.withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.link_off_rounded,
                color: _red.withOpacity(0.7),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    url.url,
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (url.reason != null && url.reason!.isNotEmpty) ...[
                        Flexible(
                          child: Text(
                            url.reason!,
                            style: TextStyle(
                              color: _textPrimary.withOpacity(0.4),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          ' · ',
                          style: TextStyle(
                            color: _textPrimary.withOpacity(0.3),
                          ),
                        ),
                      ],
                      Text(
                        _formatDate(url.blockedAt),
                        style: TextStyle(
                          color: _textPrimary.withOpacity(0.3),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    await Clipboard.setData(ClipboardData(text: url.url));
                    if (!mounted) return;
                    AlertService.showInfo(
                      context,
                      'Copied to Clipboard',
                      'URL copied to clipboard.',
                    );
                  },
                  icon: Icon(
                    Icons.content_copy_rounded,
                    color: _textPrimary.withOpacity(0.55),
                    size: 20,
                  ),
                  tooltip: 'Copy URL',
                  visualDensity: VisualDensity.compact,
                ),
                if (url.userId == ref.read(userProvider)?.userId)
                  IconButton(
                    onPressed: () => _unblockUrl(url),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: _red.withOpacity(0.65),
                      size: 22,
                    ),
                    tooltip: 'Unblock',
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
