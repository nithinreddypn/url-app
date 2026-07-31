import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'error_handler.dart';

enum AlertType { success, error, warning, info }

/// Presents short, non-persistent feedback above the application shell.
///
/// Persistent threat notifications remain part of the Alerts screen. This
/// service is intentionally limited to action feedback, validation messages,
/// and recoverable errors.
///
/// Redesigned with premium dark-themed toast system featuring:
/// - State-specific whisper-tinted backgrounds
/// - Spring-based entrance/exit animations
/// - Card-deck stacking with subtle tilt
/// - Auto-dismiss with draining progress bar (pauses on hover)
/// - Icon pulse emphasis for danger/warning
/// - Full light + dark mode support from shared token set
class AlertService {
  static final List<_ToastEntry> _activeEntries = [];

  /// Maximum visible toasts at once.
  static const int _maxVisible = 4;

  static void showAlert(
    BuildContext context, {
    required AlertType type,
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 5),
  }) {
    if (!context.mounted) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    // If we're over the limit, dismiss the oldest one
    while (_activeEntries.length >= _maxVisible) {
      final oldest = _activeEntries.first;
      oldest.controller._dismiss();
    }

    late final OverlayEntry entry;
    late final _ToastEntry toastEntry;
    final controller = _ToastController();

    entry = OverlayEntry(
      builder: (overlayContext) => _ToastOverlay(
        index: _activeEntries.indexOf(toastEntry),
        totalCount: _activeEntries.length,
        type: type,
        title: title,
        description: description,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
        controller: controller,
        onDismiss: () {
          if (entry.mounted) entry.remove();
          _activeEntries.remove(toastEntry);
          _rebuildAll();
        },
      ),
    );

    toastEntry = _ToastEntry(entry: entry, controller: controller);
    _activeEntries.add(toastEntry);
    overlay.insert(entry);
    _rebuildAll();
  }

  static void _rebuildAll() {
    // Force all overlays to rebuild so stacking indices update
    for (final te in _activeEntries) {
      te.entry.markNeedsBuild();
    }
  }

  static void showSuccess(
    BuildContext context,
    String title,
    String description,
  ) {
    showAlert(
      context,
      type: AlertType.success,
      title: title,
      description: description,
    );
  }

  static void showError(
    BuildContext context,
    dynamic error, {
    String? customTitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final mapped = ErrorHandler.handle(error);
    showAlert(
      context,
      type: AlertType.error,
      title: customTitle ?? mapped.title,
      description: mapped.message,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: const Duration(seconds: 6),
    );
  }

  static void showWarning(
    BuildContext context,
    String title,
    String description,
  ) {
    showAlert(
      context,
      type: AlertType.warning,
      title: title,
      description: description,
    );
  }

  static void showInfo(BuildContext context, String title, String description) {
    showAlert(
      context,
      type: AlertType.info,
      title: title,
      description: description,
    );
  }
}

// ────────────────────────────────────────────────────────
// Internal models
// ────────────────────────────────────────────────────────

class _ToastEntry {
  final OverlayEntry entry;
  final _ToastController controller;

  _ToastEntry({required this.entry, required this.controller});
}

class _ToastController {
  VoidCallback? _dismissCallback;

  void _dismiss() {
    _dismissCallback?.call();
  }
}

// ────────────────────────────────────────────────────────
// Toast Overlay Widget
// ────────────────────────────────────────────────────────

class _ToastOverlay extends StatefulWidget {
  const _ToastOverlay({
    required this.index,
    required this.totalCount,
    required this.type,
    required this.title,
    required this.description,
    required this.duration,
    required this.onDismiss,
    required this.controller,
    this.actionLabel,
    this.onAction,
  });

  final int index;
  final int totalCount;
  final AlertType type;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final VoidCallback onDismiss;
  final _ToastController controller;

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _progressController;
  late final AnimationController _exitController;
  late final AnimationController _iconPulseController;

  late Animation<double> _entranceScale;
  late Animation<double> _entranceOpacity;
  late Animation<Offset> _entranceSlide;

  bool _isDismissing = false;
  bool _isHovered = false;

  // Close button hover/press state
  bool _closeHovered = false;
  bool _closePressed = false;

  @override
  void initState() {
    super.initState();

    // Entrance: spring-like overshoot 250ms
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Custom spring curve with slight overshoot
    final springCurve = CurvedAnimation(
      parent: _entranceController,
      curve: _SpringCurve(),
    );

    _entranceScale = Tween<double>(begin: 0.92, end: 1.0).animate(springCurve);
    _entranceOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _entranceSlide = Tween<Offset>(
      begin: const Offset(0.4, -0.15),
      end: Offset.zero,
    ).animate(springCurve);

    // Exit: slide right + fade + height collapse
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    // Progress bar for auto-dismiss
    _progressController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // Icon pulse for danger/warning
    _iconPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Wire up controller dismiss callback
    widget.controller._dismissCallback = _dismiss;

    // Start animations
    _entranceController.forward().then((_) {
      // After entrance settles, pulse icon for danger/warning
      if (widget.type == AlertType.error || widget.type == AlertType.warning) {
        _iconPulseController.forward();
      }
    });
    _progressController.forward();

    // Auto-dismiss when progress completes
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _dismiss();
      }
    });
  }

  Future<void> _dismiss() async {
    if (_isDismissing) return;
    _isDismissing = true;

    // Stop auto-dismiss timer
    _progressController.stop();

    // Exit animation
    if (mounted) {
      await _exitController.forward();
    }
    widget.onDismiss();
  }

  void _handleAction() {
    widget.onAction?.call();
    _dismiss();
  }

  void _onHoverEnter() {
    if (_isHovered) return;
    setState(() => _isHovered = true);
    _progressController.stop();
  }

  void _onHoverExit() {
    if (!_isHovered) return;
    setState(() => _isHovered = false);
    if (!_isDismissing) {
      _progressController.forward();
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _progressController.dispose();
    _exitController.dispose();
    _iconPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visuals = _ToastVisuals.forType(widget.type, isDark: isDark);

    // Stacking: calculate position based on index from top of list
    // Newest toast is at the end of the list (highest index), displayed on top
    final int reverseIndex = math.max(0, widget.totalCount - 1 - widget.index);
    final double stackOffset =
        reverseIndex * 8.0; // vertical offset per card back
    final double stackScale = 1.0 - (reverseIndex * 0.03).clamp(0.0, 0.12);
    final double stackOpacity = (1.0 - reverseIndex * 0.15).clamp(0.4, 1.0);
    final double stackTilt = reverseIndex * 0.5; // degrees, very subtle

    return Positioned.fill(
      child: SafeArea(
        bottom: false,
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 380;
            final horizontalInset = constraints.maxWidth >= 600 ? 24.0 : 4.0;

            return Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.only(
                  right: horizontalInset,
                  left: horizontalInset,
                  top: stackOffset,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _entranceController,
                      _exitController,
                    ]),
                    builder: (context, child) {
                      // Entrance animations
                      final entranceComplete =
                          _entranceController.status ==
                          AnimationStatus.completed;

                      // Exit animations
                      final exitProgress = _exitController.value;
                      final exitSlide = Offset(exitProgress * 1.2, 0);
                      final exitOpacity = 1.0 - exitProgress;
                      final exitScale = 1.0 - (exitProgress * 0.05);
                      final heightFactor = 1.0 - (exitProgress * 0.6);

                      return SlideTransition(
                        position: entranceComplete
                            ? AlwaysStoppedAnimation(exitSlide)
                            : _entranceSlide,
                        child: Opacity(
                          opacity: entranceComplete
                              ? (exitOpacity * stackOpacity).clamp(0.0, 1.0)
                              : (_entranceOpacity.value * stackOpacity).clamp(
                                  0.0,
                                  1.0,
                                ),
                          child: Transform(
                            alignment: Alignment.topRight,
                            transform: Matrix4.identity()
                              ..scaleByDouble(
                                entranceComplete
                                    ? exitScale * stackScale
                                    : _entranceScale.value * stackScale,
                                entranceComplete
                                    ? exitScale * stackScale
                                    : _entranceScale.value * stackScale,
                                1,
                                1,
                              )
                              ..rotateZ(stackTilt * math.pi / 180),
                            child: ClipRect(
                              child: Align(
                                alignment: Alignment.topCenter,
                                heightFactor: entranceComplete
                                    ? heightFactor.clamp(0.0, 1.0)
                                    : 1.0,
                                child: child,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: MouseRegion(
                      onEnter: (_) => _onHoverEnter(),
                      onExit: (_) => _onHoverExit(),
                      child: GestureDetector(
                        onHorizontalDragEnd: (details) {
                          if ((details.primaryVelocity ?? 0).abs() > 320) {
                            _dismiss();
                          }
                        },
                        child: Semantics(
                          container: true,
                          liveRegion: true,
                          label: '${widget.title}. ${widget.description}',
                          child: Material(
                            color: Colors.transparent,
                            child: Container(
                              width: double.infinity,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: visuals.background,
                                borderRadius: BorderRadius.circular(
                                  isCompact ? 14 : 16,
                                ),
                                border: Border.all(color: visuals.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.14),
                                    blurRadius: isCompact ? 20 : 32,
                                    offset: const Offset(0, 12),
                                  ),
                                  // Subtle accent glow for danger/warning
                                  if (widget.type == AlertType.error ||
                                      widget.type == AlertType.warning)
                                    BoxShadow(
                                      color: visuals.accent.withOpacity(isDark ? 0.08 : 0.05),
                                      blurRadius: 24,
                                      offset: const Offset(0, 4),
                                    ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  // Left accent bar (full height, 4px)
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 4,
                                      decoration: BoxDecoration(
                                        color: visuals.accent,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(16),
                                          bottomLeft: Radius.circular(16),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Main content
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      isCompact ? 14 : 18,
                                      isCompact ? 12 : 14,
                                      isCompact ? 8 : 10,
                                      isCompact ? 14 : 16,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Icon badge with pulse
                                        _buildIconBadge(visuals, isCompact),
                                        SizedBox(width: isCompact ? 10 : 12),

                                        // Title + description + action
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  widget.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: visuals.primaryText,
                                                    fontSize: isCompact
                                                        ? 13.5
                                                        : 14.5,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: -0.2,
                                                    height: 1.2,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  widget.description,
                                                  maxLines: isCompact ? 2 : 3,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color:
                                                        visuals.secondaryText,
                                                    fontSize: isCompact
                                                        ? 11.5
                                                        : 12.5,
                                                    height: 1.45,
                                                  ),
                                                ),
                                                if (widget.actionLabel !=
                                                        null &&
                                                    widget.onAction !=
                                                        null) ...[
                                                  const SizedBox(height: 10),
                                                  TextButton(
                                                    onPressed: _handleAction,
                                                    style: TextButton.styleFrom(
                                                      foregroundColor:
                                                          visuals.accent,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 6,
                                                          ),
                                                      minimumSize: Size.zero,
                                                      tapTargetSize:
                                                          MaterialTapTargetSize
                                                              .shrinkWrap,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      backgroundColor: visuals
                                                          .accent
                                                          .withOpacity(isDark
                                                                ? 0.12
                                                                : 0.08,),
                                                    ),
                                                    child: Text(
                                                      widget.actionLabel!,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),

                                        // Close button with hover effect
                                        _buildCloseButton(visuals, isDark),
                                      ],
                                    ),
                                  ),

                                  // Progress bar (bottom edge, drains left-to-right)
                                  Positioned(
                                    left: 4,
                                    right: 0,
                                    bottom: 0,
                                    child: AnimatedBuilder(
                                      animation: _progressController,
                                      builder: (context, child) => Align(
                                        alignment: Alignment.centerLeft,
                                        child: FractionallySizedBox(
                                          widthFactor:
                                              1 - _progressController.value,
                                          child: Container(
                                            height: 3,
                                            decoration: BoxDecoration(
                                              color: visuals.accent.withOpacity(_isHovered ? 0.4 : 0.7),
                                              borderRadius:
                                                  BorderRadius.circular(1.5),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Icon badge with single pulse for danger/warning emphasis
  Widget _buildIconBadge(_ToastVisuals visuals, bool isCompact) {
    final size = isCompact ? 38.0 : 42.0;

    return AnimatedBuilder(
      animation: _iconPulseController,
      builder: (context, child) {
        // Single pulse: scale 1 → 1.15 → 1, opacity flicker
        double pulseScale = 1.0;
        double pulseOpacity = 1.0;
        if (_iconPulseController.isAnimating) {
          final t = _iconPulseController.value;
          // Bell curve for scale
          pulseScale = 1.0 + 0.15 * math.sin(t * math.pi);
          // Subtle opacity flicker
          pulseOpacity = 0.85 + 0.15 * math.cos(t * math.pi * 2);
        }

        return Transform.scale(
          scale: pulseScale,
          child: Opacity(opacity: pulseOpacity, child: child),
        );
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: visuals.iconBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Icon(
          visuals.icon,
          color: visuals.accent,
          size: isCompact ? 20 : 22,
        ),
      ),
    );
  }

  /// Close (×) button with hover highlight and tactile press
  Widget _buildCloseButton(_ToastVisuals visuals, bool isDark) {
    double scale = 1.0;
    if (_closePressed) {
      scale = 0.9;
    } else if (_closeHovered) {
      scale = 1.1;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _closeHovered = true),
      onExit: (_) => setState(() {
        _closeHovered = false;
        _closePressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _closePressed = true),
        onTapUp: (_) {
          setState(() => _closePressed = false);
          _dismiss();
        },
        onTapCancel: () => setState(() => _closePressed = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _closeHovered
                  ? (isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.06))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.close_rounded,
              color: _closeHovered
                  ? visuals.primaryText
                  : visuals.secondaryText,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────
// Spring Curve (slight overshoot, not linear ease)
// ────────────────────────────────────────────────────────

class _SpringCurve extends Curve {
  @override
  double transformInternal(double t) {
    // Attempt a spring-like overshoot: arrives at ~1.03 then settles to 1.0
    // Using a damped spring formula approximation
    const double frequency = 3.5;
    const double damping = 0.7;
    return 1.0 -
        math.pow(math.e, -damping * t * 10) * math.cos(frequency * t * math.pi);
  }
}

// ────────────────────────────────────────────────────────
// Visual Tokens (light + dark from one shared token set)
// ────────────────────────────────────────────────────────

class _ToastVisuals {
  const _ToastVisuals({
    required this.accent,
    required this.background,
    required this.iconBackground,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
    required this.icon,
  });

  final Color accent;
  final Color background;
  final Color iconBackground;
  final Color border;
  final Color primaryText;
  final Color secondaryText;
  final IconData icon;

  factory _ToastVisuals.forType(AlertType type, {required bool isDark}) {
    final icon = switch (type) {
      AlertType.success => Icons.check_circle_rounded,
      AlertType.error => Icons.error_rounded,
      AlertType.warning => Icons.warning_rounded,
      AlertType.info => Icons.info_rounded,
    };

    // Accent colors — exact user token spec
    final accent = switch (type) {
      AlertType.success =>
        isDark ? const Color(0xFF22C55E) : const Color(0xFF16A34A), // --accent-green
      AlertType.error =>
        isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626), // --danger
      AlertType.warning =>
        isDark ? const Color(0xFFFACC15) : const Color(0xFFD97706), // --warning
      AlertType.info =>
        isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB), // --accent-blue
    };

    // Background: whisper-tinted per state
    // Dark base: --bg-surface #111827 / --bg-card #18181B
    // Light base: --bg-card #FFFFFF / --bg-surface-alt #F1F5F9
    final background = switch (type) {
      AlertType.success =>
        isDark
            ? const Color(0xFF0D1811) // dark: #18181B + green whisper
            : const Color(0xFFF0FAF3), // light: pale green tint
      AlertType.error =>
        isDark
            ? const Color(0xFF1C0D0D) // dark: #18181B + red whisper
            : const Color(0xFFFDF2F2), // light: pale red tint
      AlertType.warning =>
        isDark
            ? const Color(0xFF1A1600) // dark: #18181B + amber whisper
            : const Color(0xFFFEF9EE), // light: pale amber tint
      AlertType.info =>
        isDark
            ? const Color(0xFF18181B) // --bg-card dark, no tint
            : const Color(0xFFFFFFFF), // --bg-card light, no tint
    };

    // Icon badge background: fully saturated but low alpha
    final iconBg = accent.withOpacity(isDark ? 0.15 : 0.10);

    // Borders — exact user token spec
    final border = isDark
        ? Colors.white.withOpacity(0.06)   // --border dark
        : const Color(0xFFE2E8F0);               // --border light

    // Text — exact user token spec
    final primaryText = isDark
        ? const Color(0xFFFFFFFF)   // --text-primary dark
        : const Color(0xFF0F172A);  // --text-primary light
    final secondaryText = isDark
        ? const Color(0xFFCBD5E1)   // --text-secondary dark
        : const Color(0xFF475569);  // --text-secondary light

    return _ToastVisuals(
      accent: accent,
      background: background,
      iconBackground: iconBg,
      border: border,
      primaryText: primaryText,
      secondaryText: secondaryText,
      icon: icon,
    );
  }
}
