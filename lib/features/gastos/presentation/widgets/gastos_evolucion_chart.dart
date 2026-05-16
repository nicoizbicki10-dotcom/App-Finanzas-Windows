import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';

/// Gráfico de barras: evolución de gastos en los últimos 12 meses
class Gastos12MesesChart extends StatelessWidget {
  final List<({DateTime mes, double total})> data;

  const Gastos12MesesChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxY = data.map((d) => d.total).fold(0.0, (m, v) => v > m ? v : m);
    final barWidth = 14.0;

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
                    '${DateFormat('MMM yy', 'es_AR').format(item.mes)}\n${CurrencyFormatter.compact(rod.toY)}',
                    const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
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
                    child: Text(
                      CurrencyFormatter.compact(value),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 9,
                      ),
                    ),
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
                    final mes = data[i].mes;
                    // Solo mostrar etiqueta cada 3 meses para no saturar
                    if (i % 3 != 0 && i != data.length - 1) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        DateFormat('MMM', 'es_AR').format(mes),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 9,
                        ),
                      ),
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
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: data.asMap().entries.map((e) {
              final isCurrentMonth = e.key == data.length - 1;
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.total,
                    color: isCurrentMonth
                        ? AppColors.danger
                        : AppColors.danger.withValues(alpha: 0.5),
                    width: barWidth,
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

/// Gráfico de barras: evolución de gastos en los últimos 10 años
class Gastos10AnosChart extends StatelessWidget {
  final List<({int anio, double total})> data;

  const Gastos10AnosChart({super.key, required this.data});

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
                    if (i % 2 != 0 && data[i].anio != currentYear) return const SizedBox.shrink();
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
                    color: isCurrentYear ? AppColors.danger : AppColors.danger.withValues(alpha: 0.45),
                    width: 18,
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

/// Gráfico de barras: evolución de gastos en los últimos 5 años
class Gastos5AnosChart extends StatelessWidget {
  final List<({int anio, double total})> data;

  const Gastos5AnosChart({super.key, required this.data});

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
                    const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
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
                    child: Text(
                      CurrencyFormatter.compact(value),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 9,
                      ),
                    ),
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
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${data[i].anio}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
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
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: data.asMap().entries.map((e) {
              final isCurrentYear = e.value.anio == currentYear;
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.total,
                    color: isCurrentYear
                        ? AppColors.warning
                        : AppColors.warning.withValues(alpha: 0.5),
                    width: 32,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
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
