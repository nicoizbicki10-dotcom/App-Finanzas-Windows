import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/providers/display_currency_provider.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/currency_selector.dart';
import '../../../core/widgets/section_header.dart';
import '../../gastos/presentation/providers/gastos_provider.dart';
import '../../ingresos/presentation/providers/ingresos_provider.dart';
import '../../inversiones/domain/inversion_models.dart';
import '../../inversiones/presentation/providers/inversiones_provider.dart';
import '../../market_data/providers/market_data_providers.dart';

// Datos para el gráfico de evolución anual
class _AnioData {
  final int anio;
  final double ingresos;
  final double gastos;
  const _AnioData({required this.anio, required this.ingresos, required this.gastos});
}

class CajaScreen extends ConsumerWidget {
  const CajaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();

    final totalIngresos = ref.watch(totalIngresosMesProvider);
    final totalGastos = ref.watch(totalGastosMesProvider);
    final saldoMes = totalIngresos - totalGastos;
    final liquidez = ref.watch(liquidezProvider);
    final dolarBlue = ref.watch(dolarBlueVentaProvider);

    final ingresosFijos = ref.watch(ingresosFijosProvider);
    final gastosFijos = ref.watch(gastosFijosProvider);
    final totalIngFijos = ingresosFijos.fold(0.0, (s, i) => s + i.monto);
    final totalGastFijos = gastosFijos.fold(0.0, (s, g) => s + g.monto);
    final balanceFijo = totalIngFijos - totalGastFijos;

    // Historial mensual para flujo anual y gráfico (12 meses)
    final historialGastos = ref.watch(historial12MesesGastosProvider);
    final historialIngresos = ref.watch(historialIngresosProvider);

    // Historial anual para evolución multi-año
    final historialIngresosAnual = ref.watch(historial5AnosIngresosProvider);
    final historialGastosAnual = ref.watch(historial5AnosGastosProvider);

    // Flujo de caja del año actual (mes a mes)
    final flujoPorMes = _calcularFlujoPorMes(historialIngresos, historialGastos, now.year);
    final flujoAnual = flujoPorMes.fold(0.0, (s, m) => s + m.saldo);

    // Evolución anual (últimos 5 años)
    final ingAnual = {for (final e in historialIngresosAnual) e.anio: e.total};
    final gstAnual = {for (final e in historialGastosAnual) e.anio: e.total};
    final evolucionAnual = historialIngresosAnual.map((e) => _AnioData(
          anio: e.anio,
          ingresos: ingAnual[e.anio] ?? 0,
          gastos: gstAnual[e.anio] ?? 0,
        )).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Caja'),
                Text(DateFormatter.monthYear(now),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Balance mensual ──────────────────────────────────────────
                _BalanceMensualCard(
                  totalIngresos: totalIngresos,
                  totalGastos: totalGastos,
                  saldo: saldoMes,
                ),
                const SizedBox(height: AppSpacing.sm),

                // ── Balance fijo ─────────────────────────────────────────────
                _BalanceFijoCard(
                  ingresosFijos: totalIngFijos,
                  gastosFijos: totalGastFijos,
                  balance: balanceFijo,
                  dolarBlue: dolarBlue,
                ),
                const SizedBox(height: AppSpacing.sectionSpacing),

                // ── Medios de pago ───────────────────────────────────────────
                if (liquidez.isNotEmpty) ...[
                  const SectionHeader(
                    title: 'MEDIOS DE PAGO',
                    subtitle: 'Saldo por cuenta',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _MediosDePagoCard(liquidez: liquidez, dolarBlue: dolarBlue),
                  const SizedBox(height: AppSpacing.sectionSpacing),
                ],

                // ── Flujo anual ──────────────────────────────────────────────
                const SectionHeader(
                  title: 'FLUJO ANUAL',
                  subtitle: 'Balance acumulado del año',
                ),
                const SizedBox(height: AppSpacing.sm),
                _FlujoAnualCard(
                  flujoAnual: flujoAnual,
                  anio: now.year,
                  dolarBlue: dolarBlue,
                ),
                const SizedBox(height: AppSpacing.sectionSpacing),

                // ── Evolución mensual (año actual) ───────────────────────────
                const SectionHeader(
                  title: 'EVOLUCIÓN MENSUAL',
                  subtitle: 'Ingresos vs. Gastos',
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  child: _CashflowChart(meses: flujoPorMes),
                ),
                const SizedBox(height: AppSpacing.sectionSpacing),

                // ── Evolución anual (últimos 5 años) ─────────────────────────
                const SectionHeader(
                  title: 'EVOLUCIÓN ANUAL',
                  subtitle: 'Ingresos vs. Gastos por año',
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  child: _EvolucionAnualChart(data: evolucionAnual),
                ),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  List<_MesData> _calcularFlujoPorMes(
    List<({DateTime mes, double total})> ingresos,
    List<({DateTime mes, double total})> gastos,
    int anio,
  ) {
    final result = <_MesData>[];
    // Usar historial de 12 meses
    final ing = {for (final e in ingresos) '${e.mes.year}-${e.mes.month}': e.total};
    final gst = {for (final e in gastos) '${e.mes.year}-${e.mes.month}': e.total};

    for (int m = 1; m <= 12; m++) {
      final mes = DateTime(anio, m, 1);
      final key = '$anio-$m';
      final i = ing[key] ?? 0.0;
      final g = gst[key] ?? 0.0;
      result.add(_MesData(mes: mes, ingresos: i, gastos: g, saldo: i - g));
    }
    return result;
  }
}

// ─── Data class ──────────────────────────────────────────────────────────────

class _MesData {
  final DateTime mes;
  final double ingresos;
  final double gastos;
  final double saldo;
  const _MesData({
    required this.mes,
    required this.ingresos,
    required this.gastos,
    required this.saldo,
  });
}

// ─── Cards ───────────────────────────────────────────────────────────────────

class _MediosDePagoCard extends ConsumerWidget {
  final List<Liquidez> liquidez;
  final double dolarBlue;

  const _MediosDePagoCard({
    required this.liquidez,
    required this.dolarBlue,
  });

  double _toARS(double monto, String moneda) {
    if (moneda == 'ARS') return monto;
    if (dolarBlue > 0) return monto * dolarBlue;
    return monto;
  }

  double _toUSD(double monto, String moneda) {
    if (moneda == 'USD') return monto;
    if (dolarBlue > 0) return monto / dolarBlue;
    return 0;
  }

  String _fmtAmount(double monto, String moneda) {
    if (moneda == 'ARS') return CurrencyFormatter.ars(monto);
    return '$moneda ${monto.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(displayCurrencyProvider);
    final btcPrice = ref.watch(btcPriceUSDProvider);
    final fiatRates = ref.watch(fiatRatesProvider).value ?? {};

    // Group by tipoLabel (preserving order of first occurrence)
    final Map<String, List<Liquidez>> byTipo = {};
    for (final l in liquidez) {
      (byTipo[l.tipoLabel] ??= []).add(l);
    }

    // Total overall
    final totalARS = liquidez.fold(0.0, (s, l) => s + _toARS(l.monto, l.moneda));
    final totalUSD = liquidez.fold(0.0, (s, l) => s + _toUSD(l.monto, l.moneda));

    final primaryTotal = CurrencyFormatter.fromUSD(totalUSD, currency,
        dolarBlue: dolarBlue, btcPrice: btcPrice, fiatRates: fiatRates);
    final secondaryTotal = CurrencyFormatter.secondaryFromUSD(totalUSD, currency,
        dolarBlue: dolarBlue, btcPrice: btcPrice, fiatRates: fiatRates);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Totales globales ──
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('TOTAL $currency',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11,
                        fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(primaryTotal,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                if (secondaryTotal.isNotEmpty)
                  Text(secondaryTotal,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ]),
            ),
            CurrencySelector(color: AppColors.textSecondary),
          ]),
          const Divider(height: 20, color: AppColors.surfaceBorder),

          // ── Secciones por tipo ──
          ...byTipo.entries.map((entry) {
            final tipoLabel = entry.key;
            final cuentas = entry.value;
            final emoji = cuentas.first.tipo.emoji;

            final Map<String, double> totalsPorMoneda = {};
            for (final l in cuentas) {
              totalsPorMoneda[l.moneda] = (totalsPorMoneda[l.moneda] ?? 0) + l.monto;
            }
            final tipoTotalARS = cuentas.fold(0.0, (s, l) => s + _toARS(l.monto, l.moneda));
            final pct = totalARS > 0 ? tipoTotalARS / totalARS : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(emoji, style: const TextStyle(fontSize: 15)),
                    const SizedBox(width: 6),
                    Text(tipoLabel.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8)),
                    const SizedBox(width: 8),
                    const Expanded(child: Divider(color: AppColors.surfaceBorder)),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: totalsPorMoneda.entries.map((e) => Text(
                        _fmtAmount(e.value, e.key),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      )).toList(),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      minHeight: 3,
                      backgroundColor: AppColors.surfaceElevated,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _BalanceMensualCard extends ConsumerWidget {
  final double totalIngresos;
  final double totalGastos;
  final double saldo;

  const _BalanceMensualCard({
    required this.totalIngresos,
    required this.totalGastos,
    required this.saldo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(displayCurrencyProvider);
    final dolarBlue = ref.watch(dolarBlueVentaProvider);
    final btcPrice = ref.watch(btcPriceUSDProvider);
    final fiatRates = ref.watch(fiatRatesProvider).value ?? {};
    final isPositive = saldo >= 0;

    final saldoUSD = dolarBlue > 0 ? saldo / dolarBlue : 0.0;
    final ingresosUSD = dolarBlue > 0 ? totalIngresos / dolarBlue : 0.0;
    final gastosUSD = dolarBlue > 0 ? totalGastos / dolarBlue : 0.0;

    final primarySaldo = CurrencyFormatter.fromUSD(saldoUSD, currency,
        dolarBlue: dolarBlue, btcPrice: btcPrice, fiatRates: fiatRates);
    final secondarySaldo = CurrencyFormatter.secondaryFromUSD(saldoUSD, currency,
        dolarBlue: dolarBlue, btcPrice: btcPrice, fiatRates: fiatRates);
    final fmtIngresos = CurrencyFormatter.fromUSD(ingresosUSD, currency,
        dolarBlue: dolarBlue, btcPrice: btcPrice, fiatRates: fiatRates);
    final fmtGastos = CurrencyFormatter.fromUSD(gastosUSD, currency,
        dolarBlue: dolarBlue, btcPrice: btcPrice, fiatRates: fiatRates);

    return AppCard(
      gradient: isPositive ? AppColors.successGradient : AppColors.dangerGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(
              'BALANCE DEL MES',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            const CurrencySelector(),
          ]),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              primarySaldo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
            ),
          ),
          Text(secondarySaldo,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _MiniStat(
                  label: 'Ingresos',
                  value: fmtIngresos,
                  icon: Icons.arrow_downward,
                  color: Colors.white)),
              Expanded(child: _MiniStat(
                  label: 'Gastos',
                  value: fmtGastos,
                  icon: Icons.arrow_upward,
                  color: Colors.white.withValues(alpha: 0.8))),
              Expanded(child: _MiniStat(
                  label: 'Ahorro',
                  value: totalIngresos > 0
                      ? '${(saldo / totalIngresos * 100).toStringAsFixed(1)}%'
                      : '—',
                  icon: Icons.savings,
                  color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceFijoCard extends ConsumerWidget {
  final double ingresosFijos;
  final double gastosFijos;
  final double balance;
  final double dolarBlue;

  const _BalanceFijoCard({
    required this.ingresosFijos,
    required this.gastosFijos,
    required this.balance,
    required this.dolarBlue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(displayCurrencyProvider);
    final btcPrice = ref.watch(btcPriceUSDProvider);
    final fiatRates = ref.watch(fiatRatesProvider).value ?? {};
    final isPositive = balance >= 0;

    String toFmt(double ars) {
      final usd = dolarBlue > 0 ? ars / dolarBlue : 0.0;
      return CurrencyFormatter.fromUSD(usd, currency,
          dolarBlue: dolarBlue, btcPrice: btcPrice, fiatRates: fiatRates);
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.repeat, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              const Text('BALANCE FIJO',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8)),
              const Spacer(),
              Text(
                toFmt(balance),
                style: TextStyle(
                    color: isPositive ? AppColors.success : AppColors.danger,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              CurrencySelector(color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _FixedStat(
                  label: 'Ing. fijos',
                  formattedAmount: toFmt(ingresosFijos),
                  color: AppColors.success,
                  icon: Icons.arrow_downward)),
              Expanded(child: _FixedStat(
                  label: 'Gas. fijos',
                  formattedAmount: toFmt(gastosFijos),
                  color: AppColors.danger,
                  icon: Icons.arrow_upward)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlujoAnualCard extends ConsumerWidget {
  final double flujoAnual;
  final int anio;
  final double dolarBlue;

  const _FlujoAnualCard({
    required this.flujoAnual,
    required this.anio,
    required this.dolarBlue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(displayCurrencyProvider);
    final btcPrice = ref.watch(btcPriceUSDProvider);
    final fiatRates = ref.watch(fiatRatesProvider).value ?? {};
    final isPositive = flujoAnual >= 0;

    final usd = dolarBlue > 0 ? flujoAnual / dolarBlue : 0.0;
    final primaryText = CurrencyFormatter.fromUSD(usd, currency,
        dolarBlue: dolarBlue, btcPrice: btcPrice, fiatRates: fiatRates);

    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isPositive ? AppColors.success : AppColors.danger)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPositive ? Icons.trending_up : Icons.trending_down,
              color: isPositive ? AppColors.success : AppColors.danger,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Flujo neto $anio',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                Text(
                  primaryText,
                  style: TextStyle(
                    color: isPositive ? AppColors.success : AppColors.danger,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          CurrencySelector(color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

// ─── Chart ───────────────────────────────────────────────────────────────────

class _CashflowChart extends StatelessWidget {
  final List<_MesData> meses;

  const _CashflowChart({required this.meses});

  @override
  Widget build(BuildContext context) {
    if (meses.every((m) => m.ingresos == 0 && m.gastos == 0)) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Text(
            'Sin datos de ingresos/gastos registrados',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
      );
    }

    final allValues = meses.expand((m) => [m.ingresos, m.gastos]);
    final maxY = allValues.reduce((a, b) => a > b ? a : b) * 1.2;
    final now = DateTime.now();

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceElevated,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final m = meses[group.x];
                final label = rodIndex == 0 ? 'Ingresos' : 'Gastos';
                final amount = rodIndex == 0 ? m.ingresos : m.gastos;
                return BarTooltipItem(
                  '$label\n',
                  const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                  children: [
                    TextSpan(
                      text: CurrencyFormatter.compact(amount),
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
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, _) {
                  final i = value.toInt();
                  if (i < 0 || i >= meses.length) return const SizedBox.shrink();
                  return Text(
                    DateFormat('MMM', 'es_AR').format(meses[i].mes),
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
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.surfaceBorder, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          barGroups: meses.asMap().entries.map((entry) {
            final i = entry.key;
            final m = entry.value;
            final isCurrent =
                m.mes.year == now.year && m.mes.month == now.month;
            final opacity = isCurrent ? 1.0 : 0.5;
            return BarChartGroupData(
              x: i,
              barsSpace: 2,
              barRods: [
                BarChartRodData(
                  toY: m.ingresos,
                  color: AppColors.success.withOpacity(opacity),
                  width: 8,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(3)),
                ),
                BarChartRodData(
                  toY: m.gastos,
                  color: AppColors.danger.withOpacity(opacity),
                  width: 8,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: color.withOpacity(0.7)),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _FixedStat extends StatelessWidget {
  final String label;
  final String formattedAmount;
  final Color color;
  final IconData icon;

  const _FixedStat({
    required this.label,
    required this.formattedAmount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
            Text(formattedAmount,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

class _EvolucionAnualChart extends StatelessWidget {
  final List<_AnioData> data;

  const _EvolucionAnualChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.every((d) => d.ingresos == 0 && d.gastos == 0)) {
      return const SizedBox(
        height: 80,
        child: Center(child: Text('Sin datos anuales registrados',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
      );
    }

    final allVals = data.expand((d) => [d.ingresos, d.gastos]);
    final maxY = allVals.fold(0.0, (a, b) => a > b ? a : b) * 1.2;
    final currentYear = DateTime.now().year;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceElevated,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final d = data[group.x];
                final label = rodIndex == 0 ? 'Ingresos' : 'Gastos';
                final amount = rodIndex == 0 ? d.ingresos : d.gastos;
                return BarTooltipItem(
                  '$label\n',
                  const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                  children: [TextSpan(
                    text: CurrencyFormatter.compact(amount),
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                  )],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, _) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  return Text('${data[i].anio}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 10));
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.surfaceBorder, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          barGroups: data.asMap().entries.map((entry) {
            final d = entry.value;
            final isCurrent = d.anio == currentYear;
            final alpha = isCurrent ? 1.0 : 0.5;
            return BarChartGroupData(
              x: entry.key,
              barsSpace: 3,
              barRods: [
                BarChartRodData(
                  toY: d.ingresos,
                  color: AppColors.success.withValues(alpha: alpha),
                  width: 12,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                ),
                BarChartRodData(
                  toY: d.gastos,
                  color: AppColors.danger.withValues(alpha: alpha),
                  width: 12,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
