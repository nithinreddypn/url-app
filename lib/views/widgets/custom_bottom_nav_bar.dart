import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<CustomBottomNavBar> createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanPulseController;

  @override
  void initState() {
    super.initState();
    _scanPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanPulseController.dispose();
    super.dispose();
  }

  int _getLeftActiveIndex(int index) {
    if (index == 0) return 0; // Home
    if (index == 2) return 1; // Alerts
    if (index == 3) return 2; // Settings
    return -1; // Scan is selected (index 1), left pill has no active items
  }

  @override
  Widget build(BuildContext context) {
    // ── Visual constants ──
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pillBgColor = isDark
        ? Colors.black.withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.75);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final shadowColor = Colors.black.withValues(alpha: 0.35);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

    // Active green: Vibrant Lime in both modes
    final activeGreen = const Color(0xFF5CED73);
    final activeGlow = activeGreen.withValues(alpha: 0.45);

    // Layout constants
    const leftPillHeight = 62.0;
    const leftPillRadius = 36.0;
    const itemSize = 70.0;
    const leftPillWidth = itemSize * 3 + 2 + 2; // 3 items + 2 dividers (1px each) + 2 borders (1px each)
    const indicatorSize = 42.0;

    final int leftActiveIndex = _getLeftActiveIndex(widget.currentIndex);
    final bool isLeftActive = leftActiveIndex != -1;

    // Calculate the center position for the active indicator pill
    // Each item is `itemSize` wide, dividers are 1px
    double indicatorLeft = 0;
    if (isLeftActive) {
      indicatorLeft = (leftActiveIndex * (itemSize + 1)) +
          (itemSize - indicatorSize) / 2;
    }

    return SafeArea(
      child: SizedBox(
        height: leftPillHeight + 16,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              // ═══════════════════════════════════════════
              // ── 1. Left Floating Glass Navigation Pill ──
              // ═══════════════════════════════════════════
              Container(
                width: leftPillWidth,
                height: leftPillHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(leftPillRadius),
                  border: Border.all(color: borderColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(leftPillRadius),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      color: pillBgColor,
                      child: Stack(
                        children: [
                          // ── Sliding green circle indicator ──
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            left: indicatorLeft,
                            top: (leftPillHeight - indicatorSize - 2) / 2,
                            child: AnimatedScale(
                              scale: isLeftActive ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              child: AnimatedOpacity(
                                opacity: isLeftActive ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  width: indicatorSize,
                                  height: indicatorSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: activeGreen,
                                    boxShadow: [
                                      BoxShadow(
                                        color: activeGlow,
                                        blurRadius: 16,
                                        spreadRadius: 1,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // ── Nav items row with dividers ──
                          Positioned.fill(
                            child: Row(
                              children: [
                                // Home (Index 0)
                                SizedBox(
                                  width: itemSize,
                                  child: _NavItem(
                                    icon: Icons.home_outlined,
                                    activeIcon: Icons.home_rounded,
                                    isSelected: widget.currentIndex == 0,
                                    activeColor: activeGreen,
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      widget.onTap(0);
                                    },
                                  ),
                                ),
                                // Divider 1
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: dividerColor,
                                ),
                                // Alerts (Index 2)
                                SizedBox(
                                  width: itemSize,
                                  child: _NavItem(
                                    icon: Icons.notifications_outlined,
                                    activeIcon: Icons.notifications_rounded,
                                    isSelected: widget.currentIndex == 2,
                                    activeColor: activeGreen,
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      widget.onTap(2);
                                    },
                                  ),
                                ),
                                // Divider 2
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: dividerColor,
                                ),
                                // Settings (Index 3)
                                SizedBox(
                                  width: itemSize,
                                  child: _NavItem(
                                    icon: Icons.settings_outlined,
                                    activeIcon: Icons.settings_rounded,
                                    isSelected: widget.currentIndex == 3,
                                    activeColor: activeGreen,
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      widget.onTap(3);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // ═══════════════════════════════════════════
              // ── 2. Right Floating Scan Circle Button ──
              // ═══════════════════════════════════════════
              _ScanButton(
                isActive: widget.currentIndex == 1,
                activeGreen: activeGreen,
                activeGlow: activeGlow,
                borderColor: borderColor,
                pillBgColor: pillBgColor,
                shadowColor: shadowColor,
                pulseController: _scanPulseController,
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onTap(1);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}

// ════════════════════════════════════════════════════════════════════
//  Individual Nav Item with icon + dot indicator
// ════════════════════════════════════════════════════════════════════

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          AnimatedScale(
            scale: isSelected ? 1.08 : 0.92,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: Icon(
              isSelected ? activeIcon : icon,
              color: isSelected
                  ? const Color(0xFF121212)
                  : (isDark ? Colors.white.withValues(alpha: 0.70) : const Color(0xFF0F172A).withValues(alpha: 0.70)),
              size: 23,
            ),
          ),
          const SizedBox(height: 5),
          // Green glow dot below active item
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: isSelected ? 5 : 4,
            height: isSelected ? 5 : 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? activeColor
                  : (isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFF0F172A).withValues(alpha: 0.15)),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  Floating Scan Button with green glow ring
// ════════════════════════════════════════════════════════════════════

class _ScanButton extends StatelessWidget {
  final bool isActive;
  final Color activeGreen;
  final Color activeGlow;
  final Color borderColor;
  final Color pillBgColor;
  final Color shadowColor;
  final AnimationController pulseController;
  final VoidCallback onTap;

  const _ScanButton({
    required this.isActive,
    required this.activeGreen,
    required this.activeGlow,
    required this.borderColor,
    required this.pillBgColor,
    required this.shadowColor,
    required this.pulseController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isActive ? 1.05 : 0.95,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: AnimatedBuilder(
          animation: pulseController,
          builder: (context, child) {
            final pulseValue =
                isActive ? 0.15 + (pulseController.value * 0.15) : 0.0;
            return Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Green glow ring around the button
                boxShadow: [
                  BoxShadow(
                    color: isActive
                        ? activeGlow.withValues(alpha: pulseValue + 0.25)
                        : shadowColor.withValues(alpha: 0.25),
                    blurRadius: isActive ? 22 : 18,
                    spreadRadius: isActive ? 2 : 0,
                    offset: const Offset(0, 6),
                  ),
                  if (isActive)
                    BoxShadow(
                      color: activeGreen.withValues(alpha: pulseValue),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                ],
              ),
              child: child,
            );
          },
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive
                    ? activeGreen.withValues(alpha: 0.5)
                    : borderColor,
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(31),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? activeGreen : pillBgColor,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: isActive
                          ? const Color(0xFF121212)
                          : (isDark ? Colors.white.withValues(alpha: 0.70) : const Color(0xFF0F172A).withValues(alpha: 0.70)),
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
