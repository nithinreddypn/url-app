import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/app_providers.dart';
import '../../../services/url_scan_service.dart';
import '../../../services/blocked_url_service.dart';
import '../../../models/url_scan_model.dart';
import '../../../models/url_lookup_result.dart';
import '../../../theme/app_theme.dart';
import '../../../services/alert_service.dart';
import '../../../services/api_client.dart';
import '../../../views/widgets/scan_limit_dialog.dart';
import 'scan_theme.dart';
import 'scan_page_error_boundary.dart';
import 'scan_input_card.dart';
import 'scan_progress.dart';
import 'analysis_result_card.dart';
import 'usage_limit_view.dart';
import 'recent_scans_list.dart';

/// Main Scan Page — structured so the header + input ALWAYS render
/// unconditionally, regardless of any async provider state.
class ScanPage extends ConsumerStatefulWidget {
  final String? initialUrl;
  const ScanPage({super.key, this.initialUrl});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage>
    with TickerProviderStateMixin {
  final _urlController = TextEditingController();
  late final UrlScanService _scanService;
  final _blockedService = BlockedUrlService();

  // Scan state
  bool _isScanning = false;
  bool _hasResult = false;
  bool _isBlocked = false;
  bool _isBlocking = false;
  UrlScanModel? _scanResult;
  UrlLookupResult? _lookupResult;
  bool _showLookupProgress = false;
  bool _lookupFailed = false;
  bool _isDisposed = false;

  // Timers
  Timer? _lookupDebounce;
  Timer? _lookupProgressDelay;
  Timer? _scanLogTimer;
  Timer? _autoResetTimer;
  Timer? _pendingScansTimer;
  int _lookupGeneration = 0;
  int _currentLogIndex = 0;

  // Scan progress stages
  final List<String> _scanLogs = [
    'Analyzing URL...',
    'Checking Community Intelligence...',
    'Retrieving Scan Result...',
    'Almost Finished...',
  ];

  // Animation controllers
  late AnimationController _resultAnimController;
  late Animation<double> _resultFadeAnimation;

  @override
  void initState() {
    super.initState();
    _scanService = ref.read(urlScanServiceProvider);
    _resultAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _resultFadeAnimation = CurvedAnimation(
      parent: _resultAnimController,
      curve: Curves.easeOutCubic,
    );

    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _urlController.text = widget.initialUrl!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performScan();
      });
    }
  }

  @override
  void didUpdateWidget(covariant ScanPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialUrl != null &&
        widget.initialUrl != oldWidget.initialUrl &&
        widget.initialUrl!.isNotEmpty) {
      _urlController.text = widget.initialUrl!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performScan();
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _lookupDebounce?.cancel();
    _lookupProgressDelay?.cancel();
    _scanLogTimer?.cancel();
    _autoResetTimer?.cancel();
    _pendingScansTimer?.cancel();
    _scanService.cancelLookup();
    _urlController.dispose();
    _resultAnimController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────
  // EXISTING LOGIC — copied from scan_screen.dart, unchanged
  // ──────────────────────────────────────────

  void _startPendingScansPolling() {
    if (_isDisposed || _pendingScansTimer != null) return;
    _pendingScansTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (!mounted || _isDisposed) {
        timer.cancel();
        _pendingScansTimer = null;
        return;
      }

      final recentScans = ref.read(recentScansProvider).valueOrNull;
      if (recentScans != null) {
        final pendingScans = recentScans.where((s) => s.scanResult?.toLowerCase() == 'pending').toList();
        if (pendingScans.isNotEmpty) {
          final userId = ref.read(userProvider)?.userId;
          if (userId != null) {
            for (final scan in pendingScans) {
              try {
                await _scanService.getScanById(scan.scanId, userId: userId);
              } catch (_) {}
            }
          }
        }
      }

      if (mounted && !_isDisposed) {
        ref.invalidate(recentScansProvider);
      }
    });
  }

  void _stopPendingScansPolling() {
    _pendingScansTimer?.cancel();
    _pendingScansTimer = null;
  }

  void _startAutoResetTimer() {
    _autoResetTimer?.cancel();
    _autoResetTimer = Timer(const Duration(seconds: 60), () {
      if (mounted) {
        setState(() {
          _urlController.clear();
          _lookupResult = null;
          _showLookupProgress = false;
          _lookupFailed = false;
          _hasResult = false;
          _scanResult = null;
        });
      }
    });
  }

  void _handleUrlChanged(String value) {
    _autoResetTimer?.cancel();
    _lookupDebounce?.cancel();
    _lookupProgressDelay?.cancel();
    _scanService.cancelLookup();
    final generation = ++_lookupGeneration;
    setState(() {
      _lookupResult = null;
      _showLookupProgress = false;
      _lookupFailed = false;
    });
    if (!_isValidLookupUrl(value)) return;
    _lookupDebounce = Timer(const Duration(milliseconds: 400), () {
      _runLookup(value.trim(), generation);
    });
  }

  bool _isValidLookupUrl(String value) {
    final input = value.trim();
    if (input.isEmpty || input.length > 2048 || input.contains(' ')) {
      return false;
    }
    final candidate =
        input.startsWith('http://') || input.startsWith('https://')
            ? input
            : 'https://$input';
    final uri = Uri.tryParse(candidate);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  Future<void> _runLookup(String url, int generation) async {
    final userId = ref.read(userProvider)?.userId;
    if (userId == null || !mounted || generation != _lookupGeneration) return;
    _lookupProgressDelay = Timer(const Duration(milliseconds: 300), () {
      if (mounted && generation == _lookupGeneration) {
        setState(() => _showLookupProgress = true);
      }
    });
    try {
      final result = await _scanService.lookupUrl(userId: userId, url: url);
      if (!mounted || generation != _lookupGeneration) return;
      _lookupProgressDelay?.cancel();
      setState(() {
        _lookupResult = result;
        _showLookupProgress = false;
        _lookupFailed = false;
      });
    } catch (_) {
      if (!mounted || generation != _lookupGeneration) return;
      _lookupProgressDelay?.cancel();
      setState(() {
        _showLookupProgress = false;
        _lookupFailed = true;
      });
    }
  }

  String _normalizeUrl(String url) {
    var clean = url.trim().toLowerCase();
    clean = clean.replaceFirst(RegExp(r'^https?://'), '');
    clean = clean.replaceFirst(RegExp(r'/$'), '');
    return clean;
  }

  Future<void> _performScan() async {
    _autoResetTimer?.cancel();
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showSnackBar('Please enter a URL to scan', isError: true);
      return;
    }

    final userId = ref.read(userProvider)?.userId;
    if (userId == null) {
      _showSnackBar('Please log in to scan URLs', isError: true);
      return;
    }

    // Duplicate scan prevention (local cache)
    final cleanInput = _normalizeUrl(url);
    try {
      final recentScans = ref.read(recentScansProvider).valueOrNull ?? [];
      UrlScanModel? cachedScan;
      for (final s in recentScans) {
        if (_normalizeUrl(s.scannedUrl) == cleanInput) {
          cachedScan = s;
          break;
        }
      }

      final finalScan = cachedScan;
      if (finalScan != null &&
          finalScan.scanResult?.toLowerCase() != 'pending' &&
          finalScan.scanResult?.toLowerCase() != 'error') {
        _scanLogTimer?.cancel();
        if (mounted) {
          setState(() {
            _scanResult = finalScan;
            _isScanning = false;
            _hasResult = true;
          });
          _resultAnimController.reset();
          _resultAnimController.forward();
          _startAutoResetTimer();
          _showSnackBar('URL already scanned — showing cached result');
        }
        return;
      }
    } catch (_) {
      // Continue to fresh scan if cache check fails
    }

    _currentLogIndex = 0;
    _scanLogTimer?.cancel();
    _scanLogTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (mounted && _isScanning) {
        setState(() {
          if (_currentLogIndex < _scanLogs.length - 1) {
            _currentLogIndex++;
          }
        });
      } else {
        timer.cancel();
      }
    });

    setState(() {
      _isScanning = true;
      _isBlocked = false;
    });

    try {
      final limitService = ref.read(scanLimitServiceProvider);
      final canScan = await limitService.canUserScan(userId);
      if (!canScan) {
        _scanLogTimer?.cancel();
        if (!mounted) return;
        setState(() => _isScanning = false);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => ScanLimitDialog(),
        );
        return;
      }

      final result = await _scanService.scanUrlWithVirusTotal(
        scannedUrl: url,
        userId: userId,
      );
      _scanService.clearLookupCache();

      await ref.read(userProvider.notifier).refreshUser();
      ref.invalidate(scanLimitProvider);
      ref.invalidate(scanHistoryProvider);
      ref.invalidate(recentScansProvider);
      ref.invalidate(dangerousScansProvider);

      _scanLogTimer?.cancel();
      if (!mounted) return;

      setState(() {
        _scanResult = result;
        _isScanning = false;
        _hasResult = true;
      });
      _resultAnimController.reset();
      _resultAnimController.forward();
      _startAutoResetTimer();
    } catch (e) {
      _scanLogTimer?.cancel();
      if (!mounted) return;
      setState(() => _isScanning = false);
      if (e is ApiException && e.statusCode == 429) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => ScanLimitDialog(),
        );
      } else {
        AlertService.showError(context, e);
      }
    }
  }

  void _resetScan() {
    _lookupDebounce?.cancel();
    _lookupProgressDelay?.cancel();
    _autoResetTimer?.cancel();
    _scanService.cancelLookup();
    _lookupGeneration++;
    _resultAnimController.reset();
    setState(() {
      _urlController.clear();
      _hasResult = false;
      _scanResult = null;
      _isBlocked = false;
      _lookupResult = null;
      _showLookupProgress = false;
      _lookupFailed = false;
    });
  }

  Future<void> _blockUrl() async {
    if (_scanResult == null) return;
    final userId = ref.read(userProvider)?.userId;
    if (userId == null) {
      AlertService.showWarning(
        context,
        'Authentication Required',
        'You must be logged in to block URLs.',
      );
      return;
    }
    setState(() => _isBlocking = true);
    try {
      await _blockedService.blockUrl(
        userId: userId,
        url: _scanResult!.scannedUrl,
        reason: _scanResult!.threatType ?? 'dangerous',
      );
      await ref.read(userProvider.notifier).refreshUser();
      ref.invalidate(blockedUrlsProvider);
      ref.invalidate(dangerousScansProvider);
      if (!mounted) return;
      setState(() {
        _isBlocking = false;
        _isBlocked = true;
      });
      AlertService.showSuccess(context, 'URL Blocked', 'URL blocked successfully.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBlocking = false);
      AlertService.showError(context, e);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AlertService.showAlert(
        context,
        type: AlertType.error,
        title: 'Action Failed',
        description: message,
      );
    } else {
      AlertService.showAlert(
        context,
        type: AlertType.success,
        title: 'Success',
        description: message,
      );
    }
  }

  void _showScanDetails(UrlScanModel scan) {
    context.push('/scan-detail/${scan.scanId}');
  }

  String _getRelativeTime(DateTime? dateTime) {
    if (dateTime == null) return 'just now';
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ──────────────────────────────────────────
  // BUILD — structured so header + input are UNCONDITIONAL
  // ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final scanLimitAsync = ref.watch(scanLimitProvider);

    // Update _scanResult status if it changes in the background (e.g. from pending to safe/dangerous)
    ref.listen<AsyncValue<List<UrlScanModel>>>(recentScansProvider, (previous, next) {
      final scans = next.valueOrNull;
      if (scans != null && _scanResult != null) {
        try {
          final updatedScan = scans.firstWhere(
            (s) => s.scanId == _scanResult!.scanId || _normalizeUrl(s.scannedUrl) == _normalizeUrl(_scanResult!.scannedUrl),
          );
          if (updatedScan.scanResult != _scanResult!.scanResult) {
            setState(() {
              _scanResult = updatedScan;
            });
          }
        } catch (_) {
          // If not found in the top 5 scans, do nothing
        }
      }
    });

    final isDark = context.isDark;
    final textPrimary = context.textPrimary;
    final textMuted = context.textMuted;

    // Usage counter: try to read, but never let it cause a blank page
    int? remainingScans;
    try {
      remainingScans = scanLimitAsync.valueOrNull;
    } catch (_) {}

    final usedScans = user != null ? user.lifetimeScanCount : null;
    final limitReached = remainingScans != null && remainingScans <= 0;

    return ScanPageErrorBoundary(
      child: Scaffold(
        backgroundColor: context.bg,
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              24,
              20,
              // Extra bottom padding for floating nav bar
              MediaQuery.of(context).padding.bottom + 100,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ─── HEADER — always renders unconditionally ───
                    _buildHeader(textPrimary, textMuted),
                    const SizedBox(height: 24),

                    // ─── SCAN CARD — always renders unconditionally ───
                    if (limitReached)
                      UsageLimitView(
                        used: usedScans ?? 50,
                        limit: 50,
                        onUpgrade: () {
                          // Navigate to settings/upgrade
                          ref.read(tabIndexProvider.notifier).state = 2;
                        },
                        onBackToDashboard: () {
                          ref.read(tabIndexProvider.notifier).state = 0;
                        },
                      )
                    else ...[
                      ScanInputCard(
                        urlController: _urlController,
                        isScanning: _isScanning,
                        hasResult: _hasResult,
                        lookupResult: _lookupResult,
                        showLookupProgress: _showLookupProgress,
                        lookupFailed: _lookupFailed,
                        remainingScans: remainingScans,
                        onUrlChanged: _handleUrlChanged,
                        onScan: _performScan,
                        onClear: _resetScan,
                      ),

                      // ─── SCAN PROGRESS — only when scanning ───
                      if (_isScanning) ...[
                        const SizedBox(height: 16),
                        ScanProgress(
                          currentStageIndex: _currentLogIndex,
                          stages: _scanLogs,
                        ),
                      ],

                      // ─── ANALYSIS RESULT — only when result exists ───
                      if (_hasResult && _scanResult != null) ...[
                        const SizedBox(height: 16),
                        FadeTransition(
                          opacity: _resultFadeAnimation,
                          child: AnalysisResultCard(
                            scan: _scanResult!,
                            lookupResult: _lookupResult,
                            isBlocked: _isBlocked,
                            isBlocking: _isBlocking,
                            onBlock: _blockUrl,
                            onViewReport: () =>
                                _showScanDetails(_scanResult!),
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 24),

                    // ─── RECENT SCANS — isolated async, errors here
                    //     NEVER blank the header/input above ───
                    RecentScansList(
                      onScanTap: (scan) {
                        _showScanDetails(scan);
                      },
                      onViewDashboard: () {
                        ref.read(alertsTabProvider.notifier).state = 1;
                        ref.read(tabIndexProvider.notifier).state = 2;
                      },
                      getRelativeTime: _getRelativeTime,
                      startPolling: _startPendingScansPolling,
                      stopPolling: _stopPendingScansPolling,
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

  Widget _buildHeader(Color textPrimary, Color textMuted) {
    return Column(
      children: [
        // Eyebrow
        Text(
          'URL SCANNER',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.5,
            color: textMuted,
          ),
        ),
        const SizedBox(height: 8),
        // Title
        Text(
          'Scan a URL',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        // Description
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 512),
          child: Text(
            'Paste any link. We check reputation, SSL, and 12 threat databases in under a second.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: textMuted,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
