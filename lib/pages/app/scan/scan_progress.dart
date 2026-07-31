import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'scan_theme.dart';

/// 4-stage scan progress indicator with gradient progress bar.
class ScanProgress extends StatefulWidget {
  final int currentStageIndex;
  final List<String> stages;

  const ScanProgress({
    super.key,
    required this.currentStageIndex,
    required this.stages,
  });

  @override
  State<ScanProgress> createState() => _ScanProgressState();
}

class _ScanProgressState extends State<ScanProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _sweepController;

  static const _stageDetails = [
    'Cross-referencing WHOIS + DNS history',
    'Verifying issuer, chain, and expiration',
    '12 engines · 87 blacklists',
    'Aggregating signals into a verdict',
  ];

  static const _stageLabels = [
    'Checking domain reputation',
    'Analyzing SSL certificate',
    'Cross-referencing threat databases',
    'Finalizing report',
  ];

  static const _stageIcons = [
    Icons.dns_rounded,
    Icons.lock_rounded,
    Icons.security_rounded,
    Icons.assessment_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = context.textPrimary;
    final textMuted = context.textMuted;
    final isDark = context.isDark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final screenWidth = MediaQuery.of(context).size.width;
    final useTwoColumns = screenWidth >= 640;

    final percentage =
        ((widget.currentStageIndex + 1) / widget.stages.length * 100)
            .clamp(0, 100)
            .toInt();

    return Semantics(
      liveRegion: true,
      label: 'Scan progress: ${_stageLabels[widget.currentStageIndex.clamp(0, 3)]}',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(ScanTokens.cardRadius),
          border: Border.all(color: context.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Percentage label
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Scanning…',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                Text(
                  '$percentage%',
                  style: ScanTokens.mono(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    // Background
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.black.withOpacity(0.06),
                      ),
                    ),
                    // Filled portion
                    AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      widthFactor: percentage / 100,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: ScanTokens.progressGradient,
                          ),
                        ),
                      ),
                    ),
                    // Sweep highlight
                    if (!reduceMotion)
                      AnimatedBuilder(
                        animation: _sweepController,
                        builder: (context, child) {
                          return FractionallySizedBox(
                            widthFactor: percentage / 100,
                            alignment: Alignment.centerLeft,
                            child: ShaderMask(
                              shaderCallback: (bounds) {
                                final offset =
                                    _sweepController.value * bounds.width * 2 -
                                        bounds.width * 0.5;
                                return LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.white.withOpacity(0.0),
                                    Colors.white.withOpacity(0.3),
                                    Colors.white.withOpacity(0.0),
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                  transform: GradientTranslate(offset),
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.srcATop,
                              child: Container(color: Colors.white),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Stage cards
            if (useTwoColumns)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(
                  4,
                  (i) => SizedBox(
                    width: (MediaQuery.of(context).size.width - 100) / 2,
                    child: _StageCard(
                      index: i,
                      currentIndex: widget.currentStageIndex,
                      label: _stageLabels[i],
                      detail: _stageDetails[i],
                      icon: _stageIcons[i],
                      reduceMotion: reduceMotion,
                    ),
                  ),
                ),
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  4,
                  (i) => Padding(
                    padding: EdgeInsets.only(bottom: i < 3 ? 10 : 0),
                    child: _StageCard(
                      index: i,
                      currentIndex: widget.currentStageIndex,
                      label: _stageLabels[i],
                      detail: _stageDetails[i],
                      icon: _stageIcons[i],
                      reduceMotion: reduceMotion,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Gradient translate for sweep effect
class GradientTranslate extends GradientTransform {
  final double offset;
  const GradientTranslate(this.offset);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(offset, 0, 0);
  }
}

class _StageCard extends StatelessWidget {
  final int index;
  final int currentIndex;
  final String label;
  final String detail;
  final IconData icon;
  final bool reduceMotion;

  const _StageCard({
    required this.index,
    required this.currentIndex,
    required this.label,
    required this.detail,
    required this.icon,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = index < currentIndex;
    final isActive = index == currentIndex;
    final isDark = context.isDark;

    Color borderColor;
    Color bgColor;
    Widget leadingIcon;

    if (isDone) {
      borderColor = ScanTokens.emerald.withOpacity(0.3);
      bgColor = ScanTokens.emeraldBg;
      leadingIcon = AnimatedScale(
        scale: 1.0,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: Curves.elasticOut,
        child: Icon(
          Icons.check_circle_rounded,
          size: 20,
          color: ScanTokens.emerald,
        ),
      );
    } else if (isActive) {
      borderColor = ScanTokens.focusBlue.withOpacity(0.3);
      bgColor = ScanTokens.focusBlueBg;
      leadingIcon = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: ScanTokens.focusBlue,
        ),
      );
    } else {
      borderColor = context.border;
      bgColor = isDark
          ? Colors.white.withOpacity(0.02)
          : Colors.black.withOpacity(0.02);
      leadingIcon = Icon(
        Icons.schedule_rounded,
        size: 20,
        color: context.textMuted.withOpacity(0.4),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(ScanTokens.innerRadius),
        border: Border.all(color: borderColor),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: ScanTokens.focusBlue.withOpacity(0.08),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          leadingIcon,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive || isDone
                        ? context.textPrimary
                        : context.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 10,
                    color: context.textMuted.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
