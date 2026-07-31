import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/url_scan_service.dart';
import '../services/blocked_url_service.dart';
import '../models/url_scan_model.dart';
import '../models/url_lookup_result.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import 'widgets/scan_limit_dialog.dart';
import '../services/alert_service.dart';
import '../services/api_client.dart';

class ScanScreen extends ConsumerStatefulWidget {
  final String? initialUrl;
  const ScanScreen({super.key, this.initialUrl});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with TickerProviderStateMixin {
  Color get _bgColor => context.bg;
  Color get _cardColor => context.cardBg;
  Color get _surfaceColor => context.border;
  Color get _primaryGreen => context.activeAccent;
  Color get _amber => context.warning;
  Color get _red => context.danger;
  Color get _textPrimary => context.textPrimary;
  Color get _textMuted => context.textMuted;

  final _urlController = TextEditingController();
  late final UrlScanService _scanService;
  final _blockedService = BlockedUrlService();

  bool _isScanning = false;
  bool _hasResult = false;
  bool _isBlocking = false;
  bool _isBlocked = false;
  UrlScanModel? _scanResult;
  UrlLookupResult? _lookupResult;
  Timer? _lookupDebounce;
  Timer? _lookupProgressDelay;
  int _lookupGeneration = 0;
  bool _showLookupProgress = false;
  bool _lookupFailed = false;
  bool _isDisposed = false;

  Timer? _scanLogTimer;
  int _currentLogIndex = 0;
  Timer? _autoResetTimer;

  // Typing animation fields for hint text
  Timer? _typingTimer;
  String _hintText = 'Enter URL...';
  final List<String> _hintKeywords = [
    'https://google.com',
    'https://github.com',
    'https://paypal-security-login.com',
    'https://malicious-link-reputation.net',
  ];
  int _keywordIndex = 0;
  int _charIndex = 0;
  bool _isErasing = false;

  void _startHintTypingAnimation() {
    if (_isDisposed) return;
    _typingTimer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
      if (_isDisposed || !mounted) {
        timer.cancel();
        return;
      }
      final currentWord = _hintKeywords[_keywordIndex];
      setState(() {
        if (!_isErasing) {
          _hintText = 'e.g., ${currentWord.substring(0, _charIndex + 1)}';
          _charIndex++;
          if (_charIndex == currentWord.length) {
            _isErasing = true;
            timer.cancel();
            Future.delayed(const Duration(milliseconds: 2000), () {
              if (mounted && !_isDisposed) {
                _startHintTypingAnimation();
              }
            });
          }
        } else {
          _hintText = 'e.g., ${currentWord.substring(0, _charIndex - 1)}';
          _charIndex--;
          if (_charIndex == 0) {
            _isErasing = false;
            _keywordIndex = (_keywordIndex + 1) % _hintKeywords.length;
            timer.cancel();
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted && !_isDisposed) {
                _startHintTypingAnimation();
              }
            });
          }
        }
      });
    });
  }

  final List<String> _scanLogs = [
    'Analyzing URL...',
    'Checking Community Intelligence...',
    'Retrieving Scan Result...',
    'Almost Finished...',
  ];

  // Animation controllers
  late AnimationController _resultAnimController;
  late Animation<double> _resultFadeAnimation;
  late AnimationController _pulseController;
  late AnimationController _radarSweepController;
  late AnimationController _riskGaugeController;
  late AnimationController _buttonBounceController;
  late Animation<double> _buttonBounceAnimation;

  @override
  void initState() {
    super.initState();
    _scanService = ref.read(urlScanServiceProvider);
    _resultAnimController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _resultFadeAnimation = CurvedAnimation(
      parent: _resultAnimController,
      curve: Curves.easeOutCubic,
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _radarSweepController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    )..repeat();
    _riskGaugeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    );
    _buttonBounceController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 150),
    );
    _buttonBounceAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonBounceController, curve: Curves.easeInOut),
    );

    _startHintTypingAnimation();

    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _urlController.text = widget.initialUrl!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performScan();
      });
    }
  }

  @override
  void didUpdateWidget(covariant ScanScreen oldWidget) {
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
    _typingTimer?.cancel();
    _scanLogTimer?.cancel();
    _lookupDebounce?.cancel();
    _lookupProgressDelay?.cancel();
    _autoResetTimer?.cancel();
    _scanService.cancelLookup();
    _urlController.dispose();
    _resultAnimController.dispose();
    _pulseController.dispose();
    _radarSweepController.dispose();
    _riskGaugeController.dispose();
    _buttonBounceController.dispose();
    _pendingScansTimer?.cancel();
    super.dispose();
  }

  Timer? _pendingScansTimer;

  void _startPendingScansPolling() {
    if (_isDisposed) return;
    if (_pendingScansTimer != null) return;
    _pendingScansTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && !_isDisposed) {
        ref.invalidate(recentScansProvider);
      } else {
        timer.cancel();
        _pendingScansTimer = null;
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

    // ─── Duplicate Scan Prevention Check (Local Provider Cache) ───
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
          _riskGaugeController.reset();
          _riskGaugeController.forward();
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
      _riskGaugeController.reset();
      _riskGaugeController.forward();
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
      AlertService.showSuccess(
        context,
        'URL Blocked',
        'URL blocked successfully.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBlocking = false);
      AlertService.showError(context, e);
    }
  }

  void _resetScan() {
    _lookupDebounce?.cancel();
    _lookupProgressDelay?.cancel();
    _autoResetTimer?.cancel();
    _scanService.cancelLookup();
    _lookupGeneration++;
    _resultAnimController.reset();
    _riskGaugeController.reset();
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

  Future<void> _handleRedirect(String url, bool isSafe) async {
    String formattedUrl = url.trim();
    if (!formattedUrl.startsWith('http://') &&
        !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }
    final uri = Uri.parse(formattedUrl);

    if (!isSafe) {
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
              SizedBox(width: 12),
              Text(
                'Security Warning',
                style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'This link is flagged as DANGEROUS (${_scanResult?.threatType ?? "malicious"}). Visiting this site may expose your device to security threats.',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Proceed', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        AlertService.showError(
          context,
          'Could not open the link.',
          customTitle: 'Link Error',
        );
      }
    } catch (e) {
      if (!mounted) return;
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

  String _getRelativeTime(DateTime? dateTime) {
    if (dateTime == null) return 'just now';
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildRecentActivitySection() {
    final recentScansAsync = ref.watch(recentScansProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  color: _primaryGreen.withOpacity(0.8),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                ref.read(alertsTabProvider.notifier).state = 1;
                ref.read(tabIndexProvider.notifier).state =
                    2; // Navigate to History
              },
              style: TextButton.styleFrom(
                foregroundColor: _primaryGreen,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Row(
                children: [
                  Text(
                    'See All',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 16),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        recentScansAsync.when(
          data: (scans) {
            final displayScans = scans.take(5).toList();
            final hasPending = displayScans.any((s) => s.scanResult?.toLowerCase() == 'pending');
            if (hasPending) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_isDisposed) {
                  _startPendingScansPolling();
                }
              });
            } else {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_isDisposed) {
                  _stopPendingScansPolling();
                }
              });
            }

            if (displayScans.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _surfaceColor.withOpacity(0.08),
                  ),
                ),
                child: Center(
                  child: Text(
                    'No recent scans found',
                    style: TextStyle(
                      color: _textMuted.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayScans.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final scan = displayScans[index];
                return _buildRecentScanCard(scan);
              },
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Error loading recent activity',
                style: TextStyle(color: _red, fontSize: 13),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentScanCard(UrlScanModel scan) {
    final resultStr = scan.scanResult?.toLowerCase() ?? 'safe';
    final isDangerous = resultStr == 'dangerous';
    final isSuspicious = resultStr == 'suspicious';
    final isPending = resultStr == 'pending';
    final isError = resultStr == 'error';

    final scannedAt = scan.scannedAt;
    final isTimeout = isPending && scannedAt != null && DateTime.now().difference(scannedAt).inMinutes >= 2;

    Color statusColor = _primaryGreen;
    IconData statusIcon = Icons.shield_rounded;
    String statusText = 'Safe';

    if (isDangerous) {
      statusColor = _red;
      statusIcon = Icons.gpp_bad_rounded;
      statusText = 'Unsafe';
    } else if (isSuspicious) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning_amber_rounded;
      statusText = 'Warning';
    } else if (isPending) {
      if (isTimeout) {
        statusColor = Colors.orange;
        statusIcon = Icons.refresh_rounded;
        statusText = 'Incomplete';
      } else {
        statusColor = Colors.grey;
        statusIcon = Icons.hourglass_empty_rounded;
        statusText = 'Pending';
      }
    } else if (isError) {
      statusColor = Colors.grey;
      statusIcon = Icons.error_outline_rounded;
      statusText = 'Error';
    }

    // Extract domain name for a cleaner appearance
    String domain = scan.scannedUrl;
    try {
      String cleanUrl = scan.scannedUrl.trim();
      if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
        cleanUrl = 'https://$cleanUrl';
      }
      final uri = Uri.parse(cleanUrl);
      domain = uri.host;
      if (domain.isEmpty) domain = scan.scannedUrl;
    } catch (_) {}

    return GestureDetector(
      onTap: isTimeout
          ? () {
              _urlController.text = scan.scannedUrl;
              _performScan();
            }
          : () => _showScanDetails(scan),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDangerous
                ? _red.withOpacity(0.2)
                : _surfaceColor.withOpacity(0.08),
            width: isDangerous ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Status Icon with glowing circle backing
            Container(
              padding: isPending && !isTimeout ? const EdgeInsets.all(11) : const EdgeInsets.all(10),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor.withOpacity(0.08),
              ),
              child: isPending && !isTimeout
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    )
                  : Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 14),
            // URL / Domain info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    domain,
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    scan.scannedUrl,
                    style: TextStyle(color: _textMuted, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Right status badge or relative time
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isTimeout ? 'Tap to retry' : _getRelativeTime(scan.scannedAt),
                  style: TextStyle(
                    color: isTimeout ? _amber : _textMuted.withOpacity(0.6),
                    fontSize: 10,
                    fontWeight: isTimeout ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showScanDetails(UrlScanModel scan) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final resultStr = scan.scanResult?.toLowerCase() ?? 'safe';
        final isSafe = resultStr == 'safe';
        final isDangerous = resultStr == 'dangerous';
        final isSuspicious = resultStr == 'suspicious';

        Color statusColor = _primaryGreen;
        IconData statusIcon = Icons.shield_rounded;
        String statusTitle = 'This URL is Safe';
        String statusDesc =
            'No security engines detected malicious content or phishing threats on this link.';

        if (isDangerous) {
          statusColor = _red;
          statusIcon = Icons.gpp_bad_rounded;
          statusTitle = 'This URL is Dangerous';
          statusDesc =
              'Multiple security engines flagged this URL as a malware threat or phishing host.';
        } else if (isSuspicious) {
          statusColor = Colors.orange;
          statusIcon = Icons.warning_amber_rounded;
          statusTitle = 'This URL is Suspicious';
          statusDesc =
              'Some heuristic alerts or community reports suggested caution when visiting this link.';
        }

        return Container(
          decoration: BoxDecoration(
            color: isDark ? _bgColor : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pull bar indicator
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _textMuted.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Scan Details',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: _textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Status Panel
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: statusColor.withOpacity(0.15),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusTitle,
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            statusDesc,
                            style: TextStyle(
                              color: _textMuted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Risk Score Progress
              Text(
                'Risk Score Analysis',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (scan.riskScore ?? 0) / 100.0,
                        backgroundColor: _surfaceColor.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${scan.riskScore ?? 0}%',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Metrics Grid
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'VirusTotal Flags',
                      '${scan.virusTotalFlags}',
                      Icons.security_rounded,
                      statusColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      'Heuristic Hits',
                      '${scan.heuristicHits}',
                      Icons.analytics_rounded,
                      isSafe ? _textMuted : statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Community Reports',
                      '${scan.communityReports}',
                      Icons.people_alt_rounded,
                      isSafe ? _textMuted : statusColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      'Threat Classification',
                      scan.threatType ?? 'None',
                      Icons.bug_report_rounded,
                      isSafe ? _textMuted : statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Full URL Details
              Text(
                'Full URL Path',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _surfaceColor.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        scan.scannedUrl,
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.copy_rounded,
                        color: _textMuted,
                        size: 18,
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: scan.scannedUrl));
                        _showSnackBar('URL copied to clipboard');
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // Bottom Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _urlController.text = scan.scannedUrl;
                        _performScan();
                      },
                      icon: const Icon(Icons.replay_rounded, size: 18),
                      label: const Text('Re-run Scan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _handleRedirect(scan.scannedUrl, isSafe);
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('Visit Link'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textPrimary,
                        side: BorderSide(
                          color: _textMuted.withOpacity(0.3),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _surfaceColor.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(color: _textMuted, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(tabIndexProvider, (previous, next) {
      if (next == 1) {
        ref.invalidate(recentScansProvider);
        ref.invalidate(scanHistoryProvider);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _resetScan();
        });
      }
    });

    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _CyberGridPainter(
                    color: _primaryGreen,
                    pulse: _pulseController.value,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleSection(),
                  const SizedBox(height: 12),
                  _buildUrlInput(),
                  if (_showLookupProgress ||
                      _lookupResult != null ||
                      _lookupFailed) ...[
                    const SizedBox(height: 12),
                    _buildLookupState(),
                  ],
                  const SizedBox(height: 14),
                  _buildScanButton(),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.15),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _isScanning
                        ? _buildScanningIndicator()
                        : _hasResult && _scanResult != null
                        ? _buildResultSection(_scanResult!)
                        : _lookupResult != null || _lookupFailed
                        ? const SizedBox.shrink(key: ValueKey('lookup-state'))
                        : _buildIdleState(),
                  ),
                  _buildRecentActivitySection(),
                  const SizedBox(height: 32),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          color: _textMuted.withOpacity(0.45),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Secure 256-bit SSL Scan · History is private',
                          style: TextStyle(
                            color: _textMuted.withOpacity(0.45),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────── Title ────────────────────────────

  Widget _buildTitleSection() {
    return Row(
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryGreen, Color(0xFF3ED65C)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _primaryGreen.withOpacity(0.2 + (_pulseController.value * 0.15)),
                    blurRadius: 16 + (_pulseController.value * 8),
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.radar_rounded, color: Colors.white, size: 26),
            );
          },
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scan URL',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Powered by VirusTotal intelligence',
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────── URL Input ────────────────────────────

  Widget _buildUrlInput() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: _urlController,
        style: TextStyle(color: _textPrimary, fontSize: 15),
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          hintText: _hintText,
          hintStyle: TextStyle(
            color: _textPrimary.withOpacity(0.2),
            fontSize: 14,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              Icons.language_rounded,
              color: _primaryGreen.withOpacity(0.6),
              size: 22,
            ),
          ),
          suffixIcon: _urlController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: _textPrimary.withOpacity(0.4),
                    size: 20,
                  ),
                  onPressed: () {
                    _urlController.clear();
                    _handleUrlChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: _cardColor,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: _surfaceColor.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: _surfaceColor.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: _primaryGreen, width: 1.5),
          ),
        ),
        onChanged: _handleUrlChanged,
        onSubmitted: (_) => _performScan(),
      ),
    );
  }

  // ──────────────────────────── Scan Button ────────────────────────────

  Widget _buildLookupState() {
    if (_showLookupProgress) {
      return Container(
        key: const ValueKey('lookup-progress'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _surfaceColor.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _primaryGreen,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Checking URL Defender intelligence...',
                style: TextStyle(color: _textMuted, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }
    if (_lookupFailed) {
      return _buildLookupMessage(
        icon: Icons.cloud_off_rounded,
        color: _textMuted,
        title: 'Instant lookup unavailable',
        message: 'You can still use Scan Now to analyze this URL.',
      );
    }

    final result = _lookupResult;
    final analysis = result?.analysis;
    if (result == null) return const SizedBox.shrink();
    if (!result.exists || analysis == null) {
      return _buildLookupMessage(
        icon: Icons.manage_search_rounded,
        color: _textMuted,
        title: 'No analysis available yet',
        message: 'Tap Scan Now to analyze this URL.',
      );
    }

    final status = analysis.status.toLowerCase();
    final statusColor = switch (status) {
      'safe' => _primaryGreen,
      'suspicious' => _amber,
      'dangerous' => _red,
      _ => _textMuted,
    };
    final statusIcon = switch (status) {
      'safe' => Icons.verified_user_rounded,
      'suspicious' => Icons.warning_amber_rounded,
      'dangerous' => Icons.gpp_bad_rounded,
      _ => Icons.help_outline_rounded,
    };

    return Container(
      key: ValueKey('lookup-${analysis.url}-$status'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(context.isDark ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.38)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(statusIcon, color: statusColor, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Threat Intelligence Available',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      analysis.url,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildLookupMetric(
                    'Risk Score',
                    '${analysis.riskScore}/100',
                    itemWidth,
                  ),
                  _buildLookupMetric('Category', analysis.category, itemWidth),
                  _buildLookupMetric(
                    'Threat Type',
                    analysis.threatType ?? 'None detected',
                    itemWidth,
                  ),
                  _buildLookupMetric(
                    'SSL',
                    _displayLookupValue(analysis.sslStatus),
                    itemWidth,
                  ),
                  _buildLookupMetric(
                    'Redirects',
                    '${analysis.redirectCount}',
                    itemWidth,
                  ),
                  _buildLookupMetric('Source', analysis.source, itemWidth),
                ],
              );
            },
          ),
          if (result.alreadyInHistory) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.history_rounded, color: statusColor, size: 17),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Already in Your Scan History · Last scanned ${_getRelativeTime(result.lastScanned)}',
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showScanDetails(
                UrlScanModel(
                  scanId: result.scanId ?? '',
                  userId: ref.read(userProvider)?.userId,
                  scannedUrl: analysis.url,
                  scanResult: analysis.status,
                  threatType: analysis.threatType,
                  riskScore: analysis.riskScore,
                  scannedAt: result.lastScanned,
                ),
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              label: const Text('View Details'),
              style: OutlinedButton.styleFrom(
                foregroundColor: statusColor,
                side: BorderSide(color: statusColor.withOpacity(0.45)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLookupMessage({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _surfaceColor.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(color: _textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLookupMetric(String label, String value, double width) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _cardColor.withOpacity(0.78),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _surfaceColor.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: _textMuted, fontSize: 10)),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _displayLookupValue(String value) {
    if (value.isEmpty) return 'Unknown';
    return value[0].toUpperCase() + value.substring(1).replaceAll('_', ' ');
  }

  Widget _buildScanButton() {
    return GestureDetector(
      key: const ValueKey('scan_button'),
      onTapDown: (_) => _buttonBounceController.forward(),
      onTapUp: (_) {
        _buttonBounceController.reverse();
        if (!_isScanning) _performScan();
      },
      onTapCancel: () => _buttonBounceController.reverse(),
      child: AnimatedBuilder(
        animation: _buttonBounceAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _buttonBounceAnimation.value,
            child: child,
          );
        },
        child: Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: _isScanning
                ? LinearGradient(
                    colors: [
                      _primaryGreen.withOpacity(0.4),
                      Color(0xFF3ED65C).withOpacity(0.4),
                    ],
                  )
                : LinearGradient(
                    colors: [_primaryGreen, Color(0xFF3ED65C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            boxShadow: _isScanning
                ? []
                : [
                    BoxShadow(
                      color: _primaryGreen.withOpacity(0.4),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isScanning)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                else
                  Icon(Icons.shield_rounded, color: Colors.white, size: 22),
                SizedBox(width: 12),
                Text(
                  _isScanning
                      ? 'Scanning...'
                      : _lookupResult?.exists == true
                      ? 'Add to My History'
                      : 'Scan Now',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────── Idle State ────────────────────────────

  Widget _buildIdleState() {
    final hasHistory = ref.watch(recentScansProvider).valueOrNull?.isNotEmpty ?? false;
    if (hasHistory) {
      return const SizedBox.shrink(key: ValueKey('idle-collapsed'));
    }

    return Container(
      key: ValueKey('idle'),
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primaryGreen.withOpacity(0.06),
                border: Border.all(
                  color: _primaryGreen.withOpacity(0.1),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.security_rounded,
                color: _primaryGreen.withOpacity(0.3),
                size: 40,
              ),
            ),
            SizedBox(height: 14),
            Text(
              'Enter a URL to check its safety',
              style: TextStyle(
                color: _textPrimary.withOpacity(0.3),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'We analyze URLs against 70+ security engines',
              style: TextStyle(
                color: _textPrimary.withOpacity(0.2),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────── Scanning Indicator ────────────────────────────

  Widget _buildScanningIndicator() {
    final prevScan = _scanResult;
    return Container(
      key: const ValueKey('scanning'),
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Center(
            child: Column(
              children: [
                // Animated radar sweep
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer pulsing ring
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          return Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _primaryGreen.withOpacity(0.1 + (_pulseController.value * 0.15)),
                                width: 2,
                              ),
                            ),
                          );
                        },
                      ),
                      // Middle ring
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          final v = _pulseController.value;
                          return Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _primaryGreen.withOpacity(0.04 + (v * 0.04)),
                              border: Border.all(
                                color: _primaryGreen.withOpacity(0.15 + (v * 0.1)),
                                width: 1.5,
                              ),
                            ),
                          );
                        },
                      ),
                      // Radar sweep
                      AnimatedBuilder(
                        animation: _radarSweepController,
                        builder: (context, _) {
                          return Transform.rotate(
                            angle: _radarSweepController.value * 2 * math.pi,
                            child: CustomPaint(
                              size: const Size(100, 100),
                              painter: _RadarSweepPainter(color: _primaryGreen),
                            ),
                          );
                        },
                      ),
                      // Center icon
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [_primaryGreen, const Color(0xFF3ED65C)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryGreen.withOpacity(0.4),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.radar_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Analyzing URL...',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _primaryGreen.withOpacity(0.15),
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _scanLogs[_currentLogIndex],
                      key: ValueKey(_currentLogIndex),
                      style: TextStyle(
                        color: _primaryGreen.withOpacity(0.85),
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Animated dots
                SizedBox(
                  width: 40,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(3, (i) {
                          final delay = i * 0.3;
                          final v = ((_pulseController.value + delay) % 1.0);
                          return Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _primaryGreen.withOpacity(0.3 + (v * 0.7)),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (prevScan != null) ...[
            const SizedBox(height: 32),
            Opacity(
              opacity: 0.5,
              child: AbsorbPointer(
                child: _buildResultSection(prevScan),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────── Result Section ────────────────────────────

  Widget _buildResultSection(UrlScanModel scan) {
    final isSafe = scan.isSafe;
    final riskScore = scan.riskScore ?? 0;
    final statusColor = isSafe ? _primaryGreen : _red;

    Color riskColor;
    String riskLabel;
    if (riskScore <= 20) {
      riskColor = _primaryGreen;
      riskLabel = 'Low Risk';
    } else if (riskScore <= 50) {
      riskColor = _amber;
      riskLabel = 'Medium Risk';
    } else if (riskScore <= 80) {
      riskColor = Color(0xFFFF6B35);
      riskLabel = 'High Risk';
    } else {
      riskColor = _red;
      riskLabel = 'Critical';
    }

    return FadeTransition(
      key: ValueKey('result'),
      opacity: _resultFadeAnimation,
      child: Column(
        children: [
          // ─── Main Result Card ───
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: statusColor.withOpacity(0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.06),
                  blurRadius: 40,
                  offset: Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // ─── Top: Status header with gradient bg ───
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(24, 28, 24, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        statusColor.withOpacity(0.08),
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Animated status icon with double ring
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 700),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(scale: value, child: child);
                        },
                        child: SizedBox(
                          width: 88,
                          height: 88,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer glow ring
                              Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: statusColor.withOpacity(0.15),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              // Inner filled circle
                              Container(
                                width: 66,
                                height: 66,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      statusColor.withOpacity(0.2),
                                      statusColor.withOpacity(0.06),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: statusColor.withOpacity(0.35),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: statusColor.withOpacity(0.25),
                                      blurRadius: 24,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isSafe
                                      ? Icons.verified_rounded
                                      : Icons.gpp_bad_rounded,
                                  color: statusColor,
                                  size: 32,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Status text
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 500),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 8 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            Text(
                              isSafe ? 'URL is Safe' : 'Threat Detected',
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              isSafe
                                  ? 'No threats found in this URL'
                                  : 'This URL has been flagged as malicious',
                              style: TextStyle(
                                color: _textPrimary.withOpacity(0.4),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            if (!isSafe && scan.threatType != null) ...[
                              SizedBox(height: 10),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: _red.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _red.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.warning_rounded,
                                      size: 12,
                                      color: _red.withOpacity(0.8),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      scan.threatType!.toUpperCase(),
                                      style: TextStyle(
                                        color: _red,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Risk Score Arc Gauge ───
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: AnimatedBuilder(
                    animation: _riskGaugeController,
                    builder: (context, _) {
                      final animatedScore =
                          (riskScore * _riskGaugeController.value).round();
                      final animatedProgress =
                          (riskScore / 100) * _riskGaugeController.value;
                      return SizedBox(
                        width: 180,
                        height: 120,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Arc gauge
                            CustomPaint(
                              size: Size(180, 120),
                              painter: _RiskArcPainter(
                                progress: animatedProgress,
                                trackColor: _surfaceColor.withOpacity(0.15),
                                fillColor: riskColor,
                                glowColor: riskColor.withOpacity(0.3),
                              ),
                            ),
                            // Score text
                            Positioned(
                              bottom: 8,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$animatedScore',
                                    style: TextStyle(
                                      color: riskColor,
                                      fontSize: 38,
                                      fontWeight: FontWeight.w800,
                                      height: 1,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    riskLabel,
                                    style: TextStyle(
                                      color: riskColor.withOpacity(0.7),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                SizedBox(height: 16),

                // ─── Stats tiles ───
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatTile(
                          icon: Icons.bug_report_rounded,
                          value: '${scan.virusTotalFlags}',
                          label: 'VT Flags',
                          color: scan.virusTotalFlags > 0
                              ? _red
                              : _primaryGreen,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildStatTile(
                          icon: Icons.psychology_rounded,
                          value: '${scan.heuristicHits}',
                          label: 'Heuristic',
                          color: scan.heuristicHits > 0
                              ? _amber
                              : _primaryGreen,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildStatTile(
                          icon: Icons.groups_rounded,
                          value: '${scan.communityReports}',
                          label: 'Reports',
                          color: scan.communityReports > 3
                              ? _amber
                              : _primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Scanned URL chip ───
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _bgColor.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _surfaceColor.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.link_rounded,
                            size: 14,
                            color: statusColor.withOpacity(0.7),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            scan.scannedUrl,
                            style: TextStyle(
                              color: _textPrimary.withOpacity(0.45),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Powered by
                Padding(
                  padding: EdgeInsets.only(bottom: 16, top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        size: 11,
                        color: _textPrimary.withOpacity(0.2),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Powered by VirusTotal',
                        style: TextStyle(
                          color: _textPrimary.withOpacity(0.2),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 20),

          // ─── Action Buttons ───
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 700),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 24 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Column(
              children: [
                // ─── Block / Blocked ───
                if (!isSafe && !_isBlocked)
                  _buildPremiumButton(
                    label: _isBlocking ? 'Blocking...' : 'Block This URL',
                    subtitle: 'Add to your blocklist',
                    icon: Icons.shield_rounded,
                    isLoading: _isBlocking,
                    gradientColors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                    onTap: _isBlocking ? null : _blockUrl,
                  ),

                if (_isBlocked)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: _primaryGreen.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _primaryGreen.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _primaryGreen.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            color: _primaryGreen,
                            size: 16,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'URL Successfully Blocked',
                          style: TextStyle(
                            color: _primaryGreen,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: 10),

                // ─── Redirect ───
                _buildPremiumButton(
                  label: 'Visit This Link',
                  subtitle: isSafe
                      ? 'Open in browser'
                      : 'Proceed at your own risk',
                  icon: Icons.open_in_new_rounded,
                  gradientColors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  onTap: () => _handleRedirect(scan.scannedUrl, isSafe),
                ),

                SizedBox(height: 10),

                // ─── Scan Another ───
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _resetScan,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _surfaceColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.radar_rounded,
                            color: _textPrimary.withOpacity(0.5),
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Scan Another URL',
                            style: TextStyle(
                              color: _textPrimary.withOpacity(0.5),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }

  // ──────────────── Premium Button ────────────────

  Widget _buildPremiumButton({
    required String label,
    required String subtitle,
    required IconData icon,
    bool isLoading = false,
    required List<Color> gradientColors,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: gradientColors[0].withOpacity(0.25),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(icon, color: Colors.white, size: 20),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────── Stat Tile ────────────────

  Widget _buildStatTile({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: _textPrimary.withOpacity(0.35),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────── Risk Arc Gauge Painter ────────────────────────────

class _RiskArcPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color fillColor;
  final Color glowColor;

  _RiskArcPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 8);
    final radius = size.width / 2 - 16;
    const startAngle = math.pi * 1.0; // left
    const sweepAngle = math.pi * 1.0; // semicircle

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // Glow fill
    final glowPaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8);

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * progress,
        false,
        glowPaint,
      );
    }

    // Fill
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * progress,
        false,
        fillPaint,
      );
    }

    // Tick marks
    final tickPaint = Paint()
      ..color = trackColor.withOpacity(0.5)
      ..strokeWidth = 1;

    for (int i = 0; i <= 10; i++) {
      final angle = startAngle + (sweepAngle * i / 10);
      final innerR = radius - 6;
      final outerR = radius + 6;
      final p1 = Offset(
        center.dx + innerR * math.cos(angle),
        center.dy + innerR * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + outerR * math.cos(angle),
        center.dy + outerR * math.sin(angle),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Endpoint dot
    if (progress > 0.01) {
      final endAngle = startAngle + sweepAngle * progress;
      final dotCenter = Offset(
        center.dx + radius * math.cos(endAngle),
        center.dy + radius * math.sin(endAngle),
      );
      canvas.drawCircle(dotCenter, 6, Paint()..color = fillColor);
      canvas.drawCircle(dotCenter, 3, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _RiskArcPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ──────────────────────────── Radar Sweep Painter ────────────────────────────

class _RadarSweepPainter extends CustomPainter {
  final Color color;

  _RadarSweepPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..shader = SweepGradient(
        colors: [
          color.withOpacity(0.0),
          color.withOpacity(0.3),
          color.withOpacity(0.0),
        ],
        stops: [0.0, 0.15, 0.3],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ──────────────────────────── Cyber Grid Background Painter ────────────────────────────

class _CyberGridPainter extends CustomPainter {
  final Color color;
  final double pulse;

  _CyberGridPainter({required this.color, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.03)
      ..strokeWidth = 1.0;

    // Draw vertical grid lines
    const double gridSpacing = 32.0;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal grid lines
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw a subtle tech grid circle target in center
    final center = Offset(size.width / 2, size.height / 3.2);
    final circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color.withOpacity(0.015 + (pulse * 0.025))
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, 120 + (pulse * 20), circlePaint);
    canvas.drawCircle(center, 240 + (pulse * 40), circlePaint);
  }

  @override
  bool shouldRepaint(covariant _CyberGridPainter oldDelegate) =>
      oldDelegate.pulse != pulse;
}
