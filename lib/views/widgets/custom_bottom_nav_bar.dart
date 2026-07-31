import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

/// Shared floating navigation for the four functional areas of the app.
class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final background = context.bottomNavBg;
    final border = context.border;
    final inactive = context.textSecondary;

    const items = [
      _NavigationItem('Home', Icons.home_outlined, Icons.home_rounded),
      _NavigationItem('Scan', Icons.radar_outlined, Icons.radar),
      _NavigationItem(
        'Alerts',
        Icons.notifications_outlined,
        Icons.notifications_rounded,
      ),
      _NavigationItem(
        'Settings',
        Icons.settings_outlined,
        Icons.settings_rounded,
      ),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 290),
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(29),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Row(
              children: List.generate(
                items.length,
                (index) => Expanded(
                  flex: currentIndex == index ? 2 : 1,
                  child: _FloatingNavItem(
                    item: items[index],
                    selected: currentIndex == index,
                    inactiveColor: inactive,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onTap(index);
                    },
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

class _NavigationItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _NavigationItem(this.label, this.icon, this.activeIcon);
}

class _FloatingNavItem extends StatelessWidget {
  final _NavigationItem item;
  final bool selected;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _FloatingNavItem({
    required this.item,
    required this.selected,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeGreen = context.activeAccent;
    final activePillBg = context.hoverSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(23),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            height: 46,
            padding: EdgeInsets.symmetric(
              horizontal: selected ? 10 : 4,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: selected ? activePillBg : Colors.transparent,
              borderRadius: BorderRadius.circular(23),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: selected ? activeGreen : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: AnimatedScale(
                      scale: selected ? 1.05 : 1.0,
                      duration: const Duration(milliseconds: 240),
                      child: Icon(
                        selected ? item.activeIcon : item.icon,
                        color: selected
                            ? context.primaryButtonText
                            : inactiveColor,
                        size: 20,
                      ),
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 8),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
