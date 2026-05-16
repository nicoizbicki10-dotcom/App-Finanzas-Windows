import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/gasto.dart';

class GastosPieChart extends StatefulWidget {
  final Map<CategoriaGasto, double> data;

  const GastosPieChart({super.key, required this.data});

  @override
  State<GastosPieChart> createState() => _GastosPieChartState();
}

class _GastosPieChartState extends State<GastosPieChart> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final entries = widget.data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold(0.0, (sum, e) => sum + e.value);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            response == null ||
                            response.touchedSection == null) {
                          _touched = -1;
                          return;
                        }
                        _touched =
                            response.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  sections: List.generate(entries.length, (i) {
                    final isTouched = i == _touched;
                    final color = AppColors.chartPalette[
                        i % AppColors.chartPalette.length];
                    return PieChartSectionData(
                      color: color,
                      value: entries[i].value,
                      radius: isTouched ? 65 : 52,
                      title: isTouched
                          ? '${(entries[i].value / total * 100).toStringAsFixed(0)}%'
                          : '',
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }),
                  centerSpaceRadius: 35,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Leyenda top 5
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: entries.take(5).toList().asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                final color =
                    AppColors.chartPalette[i % AppColors.chartPalette.length];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text(e.key.emoji, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          e.key.label,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.compact(e.value),
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
