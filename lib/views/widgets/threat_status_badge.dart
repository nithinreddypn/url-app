import 'package:flutter/material.dart';

class ThreatStatusBadge extends StatefulWidget {
  final String status;
  final bool animate;

  const ThreatStatusBadge({
    super.key,
    required this.status,
    this.animate = true,
  });

  @override
  State<ThreatStatusBadge> createState() => _ThreatStatusBadgeState();
}

class _ThreatStatusBadgeState extends State<ThreatStatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.animate && _isPendingState(widget.status)) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant ThreatStatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != oldWidget.status) {
      if (widget.animate && _isPendingState(widget.status)) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  bool _isPendingState(String status) {
    final s = status.toLowerCase();
    return s == 'pending' || s == 'needs_review' || s == 'high_risk' || s == 'queued';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'verified':
      case 'high_risk':
        return const Color(0xFFEF4444); // Red
      case 'pending':
      case 'queued':
      case 'verification':
        return const Color(0xFFEAB308); // Yellow
      case 'needs_review':
        return const Color(0xFFF97316); // Orange
      case 'rejected':
      case 'closed':
      case 'safe':
        return const Color(0xFF22C55E); // Green (resolved/safe)
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'verified':
      case 'high_risk':
        return Icons.gpp_bad;
      case 'pending':
      case 'queued':
      case 'verification':
        return Icons.hourglass_empty;
      case 'needs_review':
        return Icons.rate_review;
      case 'rejected':
      case 'closed':
      case 'safe':
        return Icons.verified_user;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'verified':
        return 'Verified Dangerous';
      case 'high_risk':
        return 'High Risk Threat';
      case 'pending':
      case 'queued':
      case 'verification':
        return 'Verification In Progress';
      case 'needs_review':
        return 'Needs Manual Review';
      case 'rejected':
      case 'closed':
      case 'safe':
        return 'Report Closed - Safe';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(widget.status);
    final icon = _getStatusIcon(widget.status);
    final text = _getStatusText(widget.status);
    final isPending = _isPendingState(widget.status);

    Widget badgeContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPending && widget.animate)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _pulseAnimation.value,
                  child: Icon(icon, color: color, size: 14),
                );
              },
            )
          else
            Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    return badgeContent;
  }
}
