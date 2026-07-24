import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../../../services/community_threat_service.dart';
import '../../../theme/app_theme.dart';

class ReporterReputationCard extends ConsumerStatefulWidget {
  const ReporterReputationCard({super.key});

  @override
  ConsumerState<ReporterReputationCard> createState() => _ReporterReputationCardState();
}

class _ReporterReputationCardState extends ConsumerState<ReporterReputationCard> {
  bool _isLoading = true;
  Map<String, dynamic> _reputation = {};

  @override
  void initState() {
    super.initState();
    _loadReputation();
  }

  Future<void> _loadReputation() async {
    try {
      final service = ref.read(communityThreatServiceProvider);
      final data = await service.getMyReputation();
      if (mounted) {
        setState(() {
          _reputation = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _badgeColor(String badge) {
    switch (badge) {
      case 'Elite Defender':
        return const Color(0xFFEAB308);
      case 'Trusted Reporter':
        return const Color(0xFF22C55E);
      case 'Active Contributor':
        return const Color(0xFF3B82F6);
      case 'Community Member':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  IconData _badgeIcon(String badge) {
    switch (badge) {
      case 'Elite Defender':
        return Icons.military_tech;
      case 'Trusted Reporter':
        return Icons.verified;
      case 'Active Contributor':
        return Icons.shield;
      case 'Community Member':
        return Icons.people;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = context.cardBg;
    final border = context.border;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final accent = context.activeAccent;

    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: const Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final trustScore = (_reputation['trust_score'] ?? 50) as int;
    final badge = (_reputation['badge'] ?? 'Newcomer') as String;
    final approvedReports = (_reputation['approved_reports'] ?? 0) as int;
    final rejectedReports = (_reputation['rejected_reports'] ?? 0) as int;
    final falseReports = (_reputation['false_reports'] ?? 0) as int;
    final totalSubmitted = (_reputation['total_reports_submitted'] ?? 0) as int;
    final totalVotes = (_reputation['total_votes_cast'] ?? 0) as int;
    final badgeClr = _badgeColor(badge);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_outlined, color: accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Community Reputation',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.refresh, size: 18, color: textSecondary),
                onPressed: () {
                  setState(() => _isLoading = true);
                  _loadReputation();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Badge + Trust Score
          Row(
            children: [
              // Trust Score Circular
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CircularProgressIndicator(
                        value: trustScore / 100.0,
                        strokeWidth: 6,
                        backgroundColor: border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          trustScore >= 75 ? Colors.green : trustScore >= 50 ? Colors.orange : Colors.red,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$trustScore',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'TRUST',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),

              // Badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: badgeClr.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: badgeClr.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_badgeIcon(badge), color: badgeClr, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            badge,
                            style: TextStyle(
                              color: badgeClr,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your reputation is determined by the quality of your threat reports and community votes.',
                      style: TextStyle(color: textSecondary, fontSize: 11, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: border, height: 1),
          const SizedBox(height: 16),

          // Stats Grid
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildStat('Reports', '$totalSubmitted', Icons.flag_outlined, accent, textPrimary, textSecondary, border),
              _buildStat('Votes', '$totalVotes', Icons.how_to_vote_outlined, const Color(0xFF8B5CF6), textPrimary, textSecondary, border),
              _buildStat('Approved', '$approvedReports', Icons.check_circle_outline, Colors.green, textPrimary, textSecondary, border),
              _buildStat('Rejected', '$rejectedReports', Icons.cancel_outlined, Colors.orange, textPrimary, textSecondary, border),
              if (falseReports > 0)
                _buildStat('False', '$falseReports', Icons.warning_amber_rounded, Colors.red, textPrimary, textSecondary, border),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(
    String label,
    String value,
    IconData icon,
    Color color,
    Color textPrimary,
    Color textSecondary,
    Color border,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
