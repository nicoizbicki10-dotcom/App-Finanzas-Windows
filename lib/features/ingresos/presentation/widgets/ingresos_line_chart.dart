import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';

class IngresosLineChart extends StatelessWidget {
  final List<({DateTime mes, double total})> historial;

  const IngresosLineChart({super.key, required this.historial});

  @override
  Widget build(BuildContext context) {
    if (historial.isEmpty || historial.every((h) => h.total == 0)) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Sin datos suficientes',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final maxVal =
        historial.map((h) => h.total).fold(0.0, (max, v) => v > max ? v : max);
    final spots = historial.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.total);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        height: 160,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppColors.surfaceBorder,
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= historial.length) {
                      return const SizedBox.shrink();
                    }
                    // Mostrar solo cada 3 meses en listas largas
                    if (historial.length > 6 && index % 3 != 0) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        DateFormat('MMM', 'es_AR').format(historial[index].mes),
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
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.35,
                color: AppColors.success,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.success.withOpacity(0.3),
                      AppColors.success.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ],
            minY: 0,
            maxY: maxVal * 1.2,
          ),
        ),
      ),
    );
  }
}
