import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';

class PatrimonyEvolution12MesesChart extends StatelessWidget {
  final List<({DateTime mes, double valorUSD})> data;

  const PatrimonyEvolution12MesesChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.every((d) => d.valorUSD == 0)) {
      return const _SinDatosWidget(
          mensaje: 'Los datos de evolución se acumulan mes a mes');
    }

    final maxY = data.map((d) => d.valorUSD).reduce((a, b) => a > b ? a : b);
    final now = DateTime.now();

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceElevated,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final item = data[group.x];
                return BarTooltipItem(
                  '${DateFormat('MMM yy', 'es_AR').format(item.mes)}\n',
                  const TextStyle(
                      color: AppColors.textSecondary, fontSize: 10),
                  children: [
                    TextSpan(
                      text: CurrencyFormatter.usdCompact(item.valorUSD),
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  if (i % 3 != 0 && i != data.length - 1) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    DateFormat('MMM', 'es_AR').format(data[i].mes),
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 9),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: AppColors.surfaceBorder,
              strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: data.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final isCurrent =
                item.mes.year == now.year && item.mes.month == now.month;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: item.valorUSD,
                  color: isCurrent
                      ? AppColors.primary
                      : AppColors.primary.withOpacity(0.4),
                  width: 14,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class PatrimonyEvolution10AnosChart extends StatelessWidget {
  final List<({int anio, double valorUSD})> data;

  const PatrimonyEvolution10AnosChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.every((d) => d.valorUSD == 0)) {
      return const _SinDatosWidget(
          mensaje: 'Los datos anuales se acumulan a medida que usás la app');
    }

    final maxY = data.map((d) => d.valorUSD).reduce((a, b) => a > b ? a : b);
    final now = DateTime.now();

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceElevated,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final item = data[group.x];
                return BarTooltipItem(
                  '${item.anio}\n',
                  const TextStyle(
                      color: AppColors.textSecondary, fontSize: 10),
                  children: [
                    TextSpan(
                      text: CurrencyFormatter.usdCompact(item.valorUSD),
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  return Text(
                    '${data[i].anio}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 9),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: AppColors.surfaceBorder,
              strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: data.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final isCurrent = item.anio == now.year;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: item.valorUSD,
                  color: isCurrent
                      ? AppColors.secondary
                      : AppColors.secondary.withOpacity(0.4),
                  width: 22,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SinDatosWidget extends StatelessWidget {
  final String mensaje;
  const _SinDatosWidget({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.show_chart, color: AppColors.textDisabled, size: 32),
          const SizedBox(height: 8),
          Text(
            mensaje,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
