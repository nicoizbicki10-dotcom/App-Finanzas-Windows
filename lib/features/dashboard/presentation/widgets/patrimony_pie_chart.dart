import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';

class PatrimonyPieChart extends StatefulWidget {
  final Map<String, double> data; // label -> porcentaje
  final double? totalUSD;

  const PatrimonyPieChart({super.key, required this.data, this.totalUSD});

  @override
  State<PatrimonyPieChart> createState() => _PatrimonyPieChartState();
}

class _PatrimonyPieChartState extends State<PatrimonyPieChart> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final entries = widget.data.entries.toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Gráfico de torta
          Expanded(
            child: SizedBox(
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
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
                            _touched = response.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      sections: List.generate(entries.length, (i) {
                        final isTouched = i == _touched;
                        final color = AppColors.chartPalette[i % AppColors.chartPalette.length];
                        final pct = entries[i].value;
                        return PieChartSectionData(
                          color: color,
                          value: pct,
                          radius: isTouched ? 70 : 58,
                          title: isTouched ? '${pct.toStringAsFixed(1)}%' : '',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }),
                      centerSpaceRadius: 44,
                      sectionsSpace: 2,
                    ),
                  ),
                  if (widget.totalUSD != null)
                    SizedBox(
                      width: 80,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              CurrencyFormatter.usdCompact(widget.totalUSD!),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const Text(
                            'total',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Leyenda
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: List.generate(entries.length, (i) {
                final color = AppColors.chartPalette[i % AppColors.chartPalette.length];
                final pct = entries[i].value;
                final amountUSD = widget.totalUSD != null ? widget.totalUSD! * pct / 100 : null;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          entries[i].key,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${pct.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (amountUSD != null)
                            Text(
                              CurrencyFormatter.usdCompact(amountUSD),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
