import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_config.dart';
import '../services/url_scan_service.dart';
import '../services/blocked_url_service.dart';
import '../models/url_scan_model.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import 'widgets/scan_limit_dialog.dart';

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
  Color get _amber =>
      context.isDark ? Color(0xFFF59E0B) : Color(0xFFD97706);
  Color get _red => context.isDark ? Color(0xFFEF4444) : Color(0xFFDC2626);
  Color get _textPrimary => context.textPrimary;
  Color get _textMuted => context.textMuted;

  final _urlController = TextEditingController();
  final _scanService = UrlScanService();
  final _blockedService = BlockedUrlService();

  bool _isScanning = false;
  bool _hasResult = false;
  bool _isBlocking = false;
  bool _isBlocked = false;
  UrlScanModel? _scanResult;

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
      CurvedAnimation(
        parent: _buttonBounceController,
        curve: Curves.easeInOut,
      ),
    );

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
    _urlController.dispose();
    _resultAnimController.dispose();
    _pulseController.dispose();
    _radarSweepController.dispose();
    _riskGaugeController.dispose();
    _buttonBounceController.dispose();
    super.dispose();
  }

  Future<void> _performScan() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showSnackBar('Please enter a URL to scan', isError: true);
      return;
    }

    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) {
      _showSnackBar('Please log in to scan URLs', isError: true);
      return;
    }

    setState(() {
      _isScanning = true;
      _hasResult = false;
      _isBlocked = false;
    });
    _resultAnimController.reset();
    _riskGaugeController.reset();

    try {
      final limitService = ref.read(scanLimitServiceProvider);
      final canScan = await limitService.canUserScan(userId);
      if (!canScan) {
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

      await ref.read(userProvider.notifier).refreshUser();
      ref.invalidate(scanLimitProvider);

      if (!mounted) return;

      setState(() {
        _scanResult = result;
        _isScanning = false;
        _hasResult = true;
      });
      _resultAnimController.forward();
      _riskGaugeController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      final errMsg = e.toString();
      if (errMsg.contains('Free scan limit reached') ||
          errMsg.contains('P0001')) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => ScanLimitDialog(),
        );
      } else {
        _showSnackBar(
            'Scan failed: ${errMsg.replaceFirst('Exception: ', '')}',
            isError: true);
      }
    }
  }

  Future<void> _blockUrl() async {
    if (_scanResult == null) return;
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) {
      _showSnackBar('You must be logged in to block URLs', isError: true);
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
      if (!mounted) return;
      setState(() {
        _isBlocking = false;
        _isBlocked = true;
      });
      _showSnackBar('URL has been blocked successfully');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBlocking = false);
      _showSnackBar('Failed to block URL', isError: true);
    }
  }

  void _resetScan() {
    _resultAnimController.reset();
    _riskGaugeController.reset();
    setState(() {
      _urlController.clear();
      _hasResult = false;
      _scanResult = null;
      _isBlocked = false;
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
              Text('Security Warning',
                  style: TextStyle(
                      color: _textPrimary, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'This link is flagged as DANGEROUS (${_scanResult?.threatType ?? "malicious"}). Visiting this site may expose your device to security threats.',
            style: TextStyle(
                color: Color(0xFF8E8E93), fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TextStyle(color: Color(0xFF8E8E93))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child:
                  Text('Proceed', style: TextStyle(color: Colors.white)),
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
        _showSnackBar('Could not open the link.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error opening link: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _red : _primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 60, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitleSection(),
            SizedBox(height: 28),
            _buildUrlInput(),
            SizedBox(height: 20),
            _buildScanButton(),
            SizedBox(height: 28),
            AnimatedSwitcher(
              duration: Duration(milliseconds: 500),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _isScanning
                  ? _buildScanningIndicator()
                  : _hasResult && _scanResult != null
                      ? _buildResultSection()
                      : _buildIdleState(),
            ),
          ],
        ),
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
                    color: _primaryGreen.withValues(
                        alpha: 0.2 + (_pulseController.value * 0.15)),
                    blurRadius: 16 + (_pulseController.value * 8),
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.radar_rounded,
                color: Colors.white,
                size: 26,
              ),
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
            color: Colors.black.withValues(alpha: 0.15),
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
          hintText: 'Enter URL (e.g., https://example.com)',
          hintStyle: TextStyle(
            color: _textPrimary.withValues(alpha: 0.2),
            fontSize: 14,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              Icons.language_rounded,
              color: _primaryGreen.withValues(alpha: 0.6),
              size: 22,
            ),
          ),
          suffixIcon: _urlController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: _textPrimary.withValues(alpha: 0.4),
                    size: 20,
                  ),
                  onPressed: () {
                    _urlController.clear();
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: _cardColor,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: _surfaceColor.withValues(alpha: 0.3),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: _surfaceColor.withValues(alpha: 0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: _primaryGreen,
              width: 1.5,
            ),
          ),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _performScan(),
      ),
    );
  }

  // ──────────────────────────── Scan Button ────────────────────────────

  Widget _buildScanButton() {
    return GestureDetector(
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
                ? LinearGradient(colors: [
                    _primaryGreen.withValues(alpha: 0.4),
                    Color(0xFF3ED65C).withValues(alpha: 0.4),
                  ])
                : LinearGradient(
                    colors: [_primaryGreen, Color(0xFF3ED65C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            boxShadow: _isScanning
                ? []
                : [
                    BoxShadow(
                      color: _primaryGreen.withValues(alpha: 0.4),
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
                  _isScanning ? 'Scanning...' : 'Scan Now',
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
    return Container(
      key: ValueKey('idle'),
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primaryGreen.withValues(alpha: 0.06),
                border: Border.all(
                  color: _primaryGreen.withValues(alpha: 0.1),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.security_rounded,
                color: _primaryGreen.withValues(alpha: 0.3),
                size: 48,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Enter a URL to check its safety',
              style: TextStyle(
                color: _textPrimary.withValues(alpha: 0.3),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'We analyze URLs against 70+ security engines',
              style: TextStyle(
                color: _textPrimary.withValues(alpha: 0.2),
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
    return Container(
      key: ValueKey('scanning'),
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
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
                            color: _primaryGreen.withValues(
                                alpha: 0.1 + (_pulseController.value * 0.15)),
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
                          color: _primaryGreen.withValues(alpha: 0.04 + (v * 0.04)),
                          border: Border.all(
                            color: _primaryGreen.withValues(alpha: 0.15 + (v * 0.1)),
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
                          size: Size(100, 100),
                          painter: _RadarSweepPainter(
                            color: _primaryGreen,
                          ),
                        ),
                      );
                    },
                  ),
                  // Center icon
                  Container(
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          _primaryGreen,
                          Color(0xFF3ED65C),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryGreen.withValues(alpha: 0.4),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.radar_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Analyzing URL...',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Checking against 70+ threat databases',
              style: TextStyle(
                color: _textMuted,
                fontSize: 13,
              ),
            ),
            SizedBox(height: 16),
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
                          color: _primaryGreen.withValues(alpha: 0.3 + (v * 0.7)),
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
    );
  }

  // ──────────────────────────── Result Section ────────────────────────────

  Widget _buildResultSection() {
    final scan = _scanResult!;
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
                color: statusColor.withValues(alpha: 0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.06),
                  blurRadius: 40,
                  offset: Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
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
                        statusColor.withValues(alpha: 0.08),
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
                          return Transform.scale(
                            scale: value,
                            child: child,
                          );
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
                                    color: statusColor.withValues(alpha: 0.15),
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
                                      statusColor.withValues(alpha: 0.2),
                                      statusColor.withValues(alpha: 0.06),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.35),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: statusColor.withValues(alpha: 0.25),
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
                                color: _textPrimary.withValues(alpha: 0.4),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            if (!isSafe && scan.threatType != null) ...[
                              SizedBox(height: 10),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _red.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _red.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.warning_rounded,
                                      size: 12,
                                      color: _red.withValues(alpha: 0.8),
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
                                trackColor:
                                    _surfaceColor.withValues(alpha: 0.15),
                                fillColor: riskColor,
                                glowColor: riskColor.withValues(alpha: 0.3),
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
                                      color: riskColor.withValues(alpha: 0.7),
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
                      color: _bgColor.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _surfaceColor.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.link_rounded,
                              size: 14, color: statusColor.withValues(alpha: 0.7)),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            scan.scannedUrl,
                            style: TextStyle(
                              color: _textPrimary.withValues(alpha: 0.45),
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
                      Icon(Icons.verified_outlined,
                          size: 11,
                          color: _textPrimary.withValues(alpha: 0.2)),
                      SizedBox(width: 4),
                      Text(
                        'Powered by VirusTotal',
                        style: TextStyle(
                          color: _textPrimary.withValues(alpha: 0.2),
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
                      color: _primaryGreen.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _primaryGreen.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _primaryGreen.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check_rounded,
                              color: _primaryGreen, size: 16),
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
                  subtitle: isSafe ? 'Open in browser' : 'Proceed at your own risk',
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
                          color: _surfaceColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.radar_rounded,
                            color: _textPrimary.withValues(alpha: 0.5),
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Scan Another URL',
                            style: TextStyle(
                              color: _textPrimary.withValues(alpha: 0.5),
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
                color: gradientColors[0].withValues(alpha: 0.25),
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
                  color: Colors.white.withValues(alpha: 0.15),
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
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.5),
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
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
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
              color: _textPrimary.withValues(alpha: 0.35),
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
      ..color = trackColor.withValues(alpha: 0.5)
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
      canvas.drawCircle(
        dotCenter,
        6,
        Paint()..color = fillColor,
      );
      canvas.drawCircle(
        dotCenter,
        3,
        Paint()..color = Colors.white,
      );
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
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.3),
          color.withValues(alpha: 0.0),
        ],
        stops: [0.0, 0.15, 0.3],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}