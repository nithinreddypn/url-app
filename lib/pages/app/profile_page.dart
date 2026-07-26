import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/app_providers.dart';
import '../../models/user_model.dart';
import 'profile/profile_header.dart';
import 'profile/stats_section.dart';
import 'profile/monthly_chart.dart';
import 'profile/activity_log.dart';
import 'profile/account_card.dart';
import 'profile/subscription_card.dart';
import 'profile/reporter_reputation_card.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (user == null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 640 && screenWidth < 1024;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Security Profile',
          style: TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Profile Header Section
              ProfileHeader(user: user),
              const SizedBox(height: 24),

              // 2. Responsive grid layout
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column (2/3 width)
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const StatsSection(),
                          const SizedBox(height: 24),
                          const MonthlyActivityChart(),
                          const SizedBox(height: 24),
                          const ActivityLog(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Right Column (1/3 width)
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AccountCard(user: user),
                          const SizedBox(height: 24),
                          const SubscriptionCard(),
                          const SizedBox(height: 24),
                          const ReporterReputationCard(),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const StatsSection(),
                    const SizedBox(height: 16),
                    const MonthlyActivityChart(),
                    const SizedBox(height: 16),
                    const ActivityLog(),
                    const SizedBox(height: 16),
                    AccountCard(user: user),
                    const SizedBox(height: 16),
                    const SubscriptionCard(),
                    const SizedBox(height: 16),
                    const ReporterReputationCard(),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
