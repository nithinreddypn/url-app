import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class CommunityProtectionCard extends StatelessWidget {
  final Map<String, dynamic> stats;

  const CommunityProtectionCard({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final accentGreen = const Color(0xFF16A34A);

    final totalReports = stats['total_reports'] ?? 0;
    final verifiedCount = stats['verified_count'] ?? 0;
    final pendingCount = stats['pending_count'] ?? 0;
    final protectedCount = stats['active_reporters'] ?? 0;

    return Semantics(
      label: 'Community Protection Status. Verified threats: $verifiedCount. Under investigation: $pendingCount.',
      container: true,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accentGreen,
                accentGreen.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "You're protected by the community.",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Stay informed with verified threat intelligence.",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem('$verifiedCount', 'Verified Threats'),
                  _buildStatDivider(),
                  _buildStatItem('$pendingCount', 'Under Investigation'),
                  _buildStatDivider(),
                  _buildStatItem('$protectedCount', 'Active Contributors'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String val, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          val,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white30,
    );
  }
}
