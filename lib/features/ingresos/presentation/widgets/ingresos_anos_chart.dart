import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';

class IngresosAnosChart extends StatelessWidget {
  final List<({int anio, double total})> data;

  const IngresosAnosChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxY = data.map((d) => d.total).fold(0.0, (m, v) => v > m ? v : m);
    final currentYear = DateTime.now().year;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            maxY: maxY * 1.2,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, _, rod, __) {
                  final item = data[group.x];
                  return BarTooltipItem(
                    '${item.anio}\n${CurrencyFormatter.compact(rod.toY)}',
                    const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 52,
                  getTitlesWidget: (value, _) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(CurrencyFormatter.compact(value),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (value, _) {
                    final i = value.toInt();
                    if (i < 0 || i >= data.length) return const SizedBox.shrink();
                    if (data.length > 6 && i % 2 != 0 && data[i].anio != currentYear) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('${data[i].anio}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)),
                    );
                  },
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.surfaceBorder, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barGroups: data.asMap().entries.map((e) {
              final isCurrentYear = e.value.anio == currentYear;
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.total,
                    color: isCurrentYear ? AppColors.success : AppColors.success.withValues(alpha: 0.45),
                    width: data.length <= 5 ? 32 : 18,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
