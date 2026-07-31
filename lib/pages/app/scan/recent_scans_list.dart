import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/url_scan_model.dart';
import '../../../providers/app_providers.dart';
import '../../../theme/app_theme.dart';
import 'scan_theme.dart';
import 'verdict_dot.dart';

/// Recent scans list — binds to recentScansProvider with its own
/// isolated AsyncValue.when() so errors here NEVER blank the parent page.
class RecentScansList extends ConsumerWidget {
  final void Function(UrlScanModel scan) onScanTap;
  final VoidCallback onViewDashboard;
  final String Function(DateTime?) getRelativeTime;
  final VoidCallback startPolling;
  final VoidCallback stopPolling;

  const RecentScansList({
    super.key,
    required this.onScanTap,
    required this.onViewDashboard,
    required this.getRelativeTime,
    required this.startPolling,
    required this.stopPolling,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textPrimary = context.textPrimary;
    final textMuted = context.textMuted;

    // ─── This is the ONLY place recentScansProvider is read.
    //     A failure here shows an inline error — it NEVER propagates
    //     upward to blank the header or input card. ───
    final recentScansAsync = ref.watch(recentScansProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Recent scans',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Click any URL to reopen its report.',
                    style: TextStyle(
                      fontSize: 12,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onViewDashboard,
              style: TextButton.styleFrom(
                foregroundColor: context.activeAccent,
                padding: EdgeInsets.zero,
                minimumSize: const Size(48, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_forward_rounded, size: 14),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // List content — isolated async handling
        recentScansAsync.when(
          data: (scans) {
            final displayScans = scans.take(5).toList();

            // Start/stop polling for pending scans
            final hasPending = displayScans.any(
              (s) => s.scanResult?.toLowerCase() == 'pending',
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (hasPending) {
                startPolling();
              } else {
                stopPolling();
              }
            });

            if (displayScans.isEmpty) {
              return _EmptyState(textMuted: textMuted);
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayScans.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final scan = displayScans[index];
                return _ScanRow(
                  scan: scan,
                  relativeTime: getRelativeTime(scan.scannedAt),
                  onTap: () => onScanTap(scan),
                );
              },
            );
          },
          loading: () => _ShimmerSkeleton(),
          // ─── ERROR STATE: shows inline retry, NEVER blanks the page ───
          error: (err, stack) => _ErrorState(
            onRetry: () => ref.invalidate(recentScansProvider),
          ),
        ),
      ],
    );
  }
}

class _ScanRow extends StatelessWidget {
  final UrlScanModel scan;
  final String relativeTime;
  final VoidCallback onTap;

  const _ScanRow({
    required this.scan,
    required this.relativeTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = context.textPrimary;
    final textMuted = context.textMuted;
    final isDark = context.isDark;
    final isCompact = MediaQuery.of(context).size.width < 640;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ScanTokens.innerRadius),
        hoverColor: isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.black.withOpacity(0.02),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ScanTokens.innerRadius),
            border: Border.all(color: context.border.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              // Verdict dot
              VerdictDot(verdict: scan.scanResult),
              const SizedBox(width: 10),

              // URL
              Expanded(
                child: Text(
                  scan.scannedUrl,
                  style: ScanTokens.mono(
                    fontSize: 12,
                    color: textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Relative time (hidden on narrow widths)
              if (!isCompact) ...[
                const SizedBox(width: 8),
                Text(
                  relativeTime,
                  style: TextStyle(
                    fontSize: 11,
                    color: textMuted,
                  ),
                ),
              ],

              // Duration placeholder
              const SizedBox(width: 8),
              Text(
                scan.scanResult?.toLowerCase() == 'pending'
                    ? 'Pending'
                    : '${scan.riskScore ?? 0}%',
                style: ScanTokens.mono(
                  fontSize: 11,
                  color: textMuted,
                ),
              ),

              // Chevron
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: textMuted.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Color textMuted;
  const _EmptyState({required this.textMuted});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.04),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.document_scanner_outlined,
              size: 24,
              color: textMuted.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No scans yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your submitted URLs will show up here for one-click re-open.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer loading skeleton for recent scans
class _ShimmerSkeleton extends StatefulWidget {
  @override
  State<_ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<_ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            return Padding(
              padding: EdgeInsets.only(bottom: i < 4 ? 6 : 0),
              child: Container(
                height: 44,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(ScanTokens.innerRadius),
                  border: Border.all(
                    color: context.border.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    // Dot placeholder
                    _shimmerBox(10, 10, isDark, reduceMotion),
                    const SizedBox(width: 10),
                    // URL placeholder
                    Expanded(
                      child: _shimmerBox(
                        double.infinity,
                        12,
                        isDark,
                        reduceMotion,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Time placeholder
                    _shimmerBox(40, 12, isDark, reduceMotion),
                    const SizedBox(width: 8),
                    // Score placeholder
                    _shimmerBox(30, 12, isDark, reduceMotion),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _shimmerBox(
    double width,
    double height,
    bool isDark,
    bool reduceMotion,
  ) {
    final baseColor = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.06);
    final highlightColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.10);

    if (reduceMotion) {
      return Container(
        width: width == double.infinity ? null : width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    return Container(
      width: width == double.infinity ? null : width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          colors: [baseColor, highlightColor, baseColor],
          stops: const [0.0, 0.5, 1.0],
          transform: GradientTranslate(
            _shimmerController.value * 400 - 200,
          ),
        ),
      ),
    );
  }
}

class GradientTranslate extends GradientTransform {
  final double offset;
  const GradientTranslate(this.offset);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(offset, 0, 0);
  }
}

/// Inline error state for when recentScansProvider fails.
/// This NEVER blanks the rest of the page — it's scoped to this section only.
class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final textMuted = context.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 24,
            color: textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'Couldn\'t load recent scans',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry', style: TextStyle(fontSize: 13)),
            style: TextButton.styleFrom(
              foregroundColor: context.activeAccent,
              minimumSize: const Size(48, 36),
            ),
          ),
        ],
      ),
    );
  }
}
