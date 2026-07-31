import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../providers/app_providers.dart';
import '../../../models/url_scan_model.dart';

class MonthlyActivityChart extends ConsumerWidget {
  const MonthlyActivityChart({super.key});

  Map<String, int> _getMonthlyScanCounts(List<UrlScanModel> scans) {
    final Map<String, int> counts = {};
    final now = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    // Initialize last 6 months with 0
    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final key = months[date.month - 1];
      counts[key] = 0;
    }
    
    for (final scan in scans) {
      if (scan.scannedAt == null) continue;
      final diffMonths = (now.year - scan.scannedAt!.year) * 12 + now.month - scan.scannedAt!.month;
      if (diffMonths >= 0 && diffMonths < 6) {
        final key = months[scan.scannedAt!.month - 1];
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scansAsync = ref.watch(scanHistoryProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final barColor = const Color(0xFF3B82F6);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monthly activity',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'LAST 6 MONTHS',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Chart Display
          scansAsync.when(
            data: (scans) {
              final monthlyData = _getMonthlyScanCounts(scans);
              final isAllZero = monthlyData.values.every((val) => val == 0);

              if (isAllZero) {
                // Empty State Box
                return Container(
                  height: 192,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: borderColor,
                      style: BorderStyle.solid, // Simulated dashed border via design aesthetics
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bar_chart_rounded, color: textSecondary.withOpacity(0.5), size: 40),
                        const SizedBox(height: 12),
                        Text(
                          'No scans yet',
                          style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Run your first scan to start building history.',
                          style: TextStyle(color: textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Compute Y axis max value
              final maxVal = monthlyData.values.reduce((a, b) => a > b ? a : b);
              final double maxY = maxVal > 0 ? (maxVal * 1.2).ceilToDouble() : 10;

              final listKeys = monthlyData.keys.toList();
              final listValues = monthlyData.values.toList();

              return SizedBox(
                height: 192,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (group) => isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '${rod.toY.round()} scans',
                            TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 11),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            if (value != value.roundToDouble()) {
                              return const SizedBox.shrink();
                            }
                            final idx = value.toInt();
                            if (idx < 0 || idx >= listKeys.length) return const SizedBox.shrink();
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              space: 8,
                              child: Text(
                                listKeys[idx],
                                style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                          reservedSize: 24,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            if (value != value.roundToDouble()) {
                              return const SizedBox.shrink();
                            }
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              space: 6,
                              child: Text(
                                value.toInt().toString(),
                                style: TextStyle(color: textSecondary, fontSize: 9),
                              ),
                            );
                          },
                          reservedSize: 24,
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: (maxY / 4).ceilToDouble().clamp(1.0, double.infinity),
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: borderColor.withOpacity(0.5),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        );
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(listKeys.length, (index) {
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: listValues[index].toDouble(),
                            color: barColor,
                            width: 16,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              );
            },
            loading: () => const SizedBox(
              height: 192,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => SizedBox(
              height: 192,
              child: Center(
                child: Text(
                  'Error loading chart data',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
