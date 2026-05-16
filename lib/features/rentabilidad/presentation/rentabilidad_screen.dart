import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/percentage_badge.dart';
import '../../../core/widgets/section_header.dart';
import '../domain/asset_performance.dart';
import 'providers/rentabilidad_provider.dart';

class RentabilidadScreen extends ConsumerWidget {
  const RentabilidadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodo = ref.watch(periodoSeleccionadoProvider);
    final rentabilidadAsync = ref.watch(rentabilidadProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mayor Rentabilidad')),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Selector de período ───────────────────────────────────
                _PeriodSelector(
                  selected: periodo,
                  onChanged: (p) =>
                      ref.read(periodoSeleccionadoProvider.notifier).state = p,
                ),
                const SizedBox(height: AppSpacing.sectionSpacing),

                rentabilidadAsync.when(
                  loading: () => const Column(
                    children: [
                      CardShimmer(),
                      SizedBox(height: 12),
                      CardShimmer(),
                      SizedBox(height: 12),
                      CardShimmer(),
                    ],
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Error al calcular rentabilidad: $e',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  data: (performances) {
                    if (performances.isEmpty) {
                      return _EmptyRentabilidad();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Podium Top 3 ────────────────────────────────
                        if (performances.isNotEmpty) ...[
                          const SectionHeader(title: 'TOP INVERSIONES'),
                          const SizedBox(height: AppSpacing.sm),
                          _PodiumWidget(performances: performances.take(3).toList()),
                          const SizedBox(height: AppSpacing.sectionSpacing),
                        ],

                        // ── Gráfico de barras ─────────────────────────
                        if (performances.length >= 2) ...[
                          const SectionHeader(title: 'COMPARATIVA'),
                          const SizedBox(height: AppSpacing.sm),
                          AppCard(
                            child: _RentabilidadBarChart(
                              performances: performances.take(8).toList(),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sectionSpacing),
                        ],

                        // ── Lista completa ────────────────────────────
                        const SectionHeader(title: 'RANKING COMPLETO'),
                        const SizedBox(height: AppSpacing.sm),
                        ...performances.asMap().entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _RankingTile(
                            rank: entry.key + 1,
                            performance: entry.value,
                          ),
                        )),
                        const SizedBox(height: 100),
                      ],
                    );
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Selector de período ────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final PeriodoRentabilidad selected;
  final ValueChanged<PeriodoRentabilidad> onChanged;

  const _PeriodSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: PeriodoRentabilidad.values.map((p) {
          final isSelected = p == selected;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilterChip(
              label: Text(p.label),
              selected: isSelected,
              onSelected: (_) => onChanged(p),
              backgroundColor: AppColors.surfaceElevated,
              selectedColor: AppColors.primary.withOpacity(0.2),
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Podium Top 3 ────────────────────────────────────────────────────────────

class _PodiumWidget extends StatelessWidget {
  final List<AssetPerformance> performances;

  const _PodiumWidget({required this.performances});

  @override
  Widget build(BuildContext context) {
    final medals = ['🥇', '🥈', '🥉'];
    final colors = [AppColors.warning, AppColors.textSecondary, const Color(0xFFCD7F32)];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: performances.asMap().entries.map((entry) {
        final i = entry.key;
        final p = entry.value;
        final isFirst = i == 0;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: i == 0 ? 0 : 4,
              right: i == performances.length - 1 ? 0 : 4,
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors[i].withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(color: colors[i].withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(medals[i], style: TextStyle(fontSize: isFirst ? 28 : 22)),
                  const SizedBox(height: 6),
                  Text(
                    p.emoji,
                    style: TextStyle(fontSize: isFirst ? 20 : 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.nombre,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: isFirst ? 14 : 12,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    p.tipo,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 6),
                  PercentageBadge(
                    percentage: p.rentabilidadPct,
                    fontSize: isFirst ? 14 : 11,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Gráfico de barras horizontal ────────────────────────────────────────────

class _RentabilidadBarChart extends StatelessWidget {
  final List<AssetPerformance> performances;

  const _RentabilidadBarChart({required this.performances});

  @override
  Widget build(BuildContext context) {
    final maxAbs = performances
        .map((p) => p.rentabilidadPct.abs())
        .fold(0.0, (max, v) => v > max ? v : max);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: SizedBox(
        height: performances.length * 44.0,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.center,
            maxY: maxAbs * 1.2,
            minY: -(maxAbs * 1.2),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, _, rod, __) {
                  final p = performances[group.x];
                  return BarTooltipItem(
                    '${p.nombre}\n${CurrencyFormatter.percentage(p.rentabilidadPct)}',
                    const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
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
                  reservedSize: 70,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= performances.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${performances[index].emoji} ${performances[index].nombre}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, _) => Text(
                    '${value.toInt()}%',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              drawHorizontalLine: false,
              getDrawingVerticalLine: (v) => FlLine(
                color: v == 0 ? AppColors.textDisabled : AppColors.surfaceBorder,
                strokeWidth: v == 0 ? 1.5 : 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: performances.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: p.rentabilidadPct,
                    fromY: 0,
                    color: p.isPositive ? AppColors.success : AppColors.danger,
                    width: 18,
                    borderRadius: BorderRadius.circular(4),
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

// ─── Tile de ranking ─────────────────────────────────────────────────────────

class _RankingTile extends StatelessWidget {
  final int rank;
  final AssetPerformance performance;

  const _RankingTile({required this.rank, required this.performance});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          // Número de ranking
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: rank <= 3 ? AppColors.warning : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          // Emoji e info
          Text(performance.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  performance.nombre,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  performance.tipo,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          // Rentabilidad
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PercentageBadge(percentage: performance.rentabilidadPct),
              const SizedBox(height: 2),
              Text(
                CurrencyFormatter.usd(performance.valorActualUSD),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Estado vacío ─────────────────────────────────────────────────────────────

class _EmptyRentabilidad extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const Text('📊', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            'No hay inversiones para comparar',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Agregá acciones, cripto o inmuebles\nen la sección Inversiones',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
