import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/providers/display_currency_provider.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/currency_selector.dart';
import '../../../core/widgets/section_header.dart';
import '../../inversiones/presentation/providers/inversiones_provider.dart';
import '../../market_data/providers/market_data_providers.dart';
import 'widgets/patrimony_evolution_chart.dart';
import 'widgets/patrimony_pie_chart.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final totalPatrimonioAsync = ref.watch(totalPatrimonioUSDProvider);
    final distribucionAsync = ref.watch(distribucionPortfolioProvider);
    final historial12 = ref.watch(patrimonioUltimos12MesesProvider);
    final historial10 = ref.watch(patrimonioUltimos10AnosProvider);
    final dolarAsync = ref.watch(dolarProvider);

    // Guardar snapshot del mes actual cuando el patrimonio esté disponible
    ref.listen<AsyncValue<double>>(totalPatrimonioUSDProvider, (_, next) {
      next.whenData((valor) {
        if (valor > 0) {
          ref.read(patrimonioHistoryRepositoryProvider).guardarMesActual(valor);
        }
      });
    });

    // Guardar snapshots por sección para calcular variación anual
    ref.listen<AsyncValue<Map<String, double>>>(seccionValoresUSDProvider, (_, next) {
      next.whenData((valores) {
        if (valores.values.any((v) => v > 0)) {
          ref.read(patrimonioHistoryRepositoryProvider).guardarSecciones(valores);
        }
      });
    });

    final dolarBlue = dolarAsync.whenOrNull(
          data: (dolares) => dolares
              .where((d) => d.casa.toLowerCase() == 'blue')
              .map((d) => d.venta)
              .firstOrNull,
        ) ??
        0.0;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            pinned: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Patrimonio'),
                Text(
                  DateFormatter.monthYear(now),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Patrimonio total ─────────────────────────────────────────
                totalPatrimonioAsync.when(
                  loading: () => const CardShimmer(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (total) => _PatrimonioTotalCard(
                    totalUSD: total,
                    dolarBlue: dolarBlue,
                  ),
                ),
                const SizedBox(height: AppSpacing.sectionSpacing),

                // ── Distribución / composición ───────────────────────────────
                const SectionHeader(title: 'COMPOSICIÓN DEL PATRIMONIO'),
                const SizedBox(height: AppSpacing.sm),
                distribucionAsync.when(
                  loading: () => const CardShimmer(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (distribucion) => distribucion.isEmpty
                      ? _EmptyPortfolioCard()
                      : AppCard(
                          child: PatrimonyPieChart(
                            data: distribucion,
                            totalUSD: totalPatrimonioAsync.value,
                          ),
                        ),
                ),
                const SizedBox(height: AppSpacing.sectionSpacing),

                // ── Evolución 12 meses ───────────────────────────────────────
                const SectionHeader(
                  title: 'EVOLUCIÓN — ÚLTIMOS 12 MESES',
                  subtitle: 'Promedio mensual en USD',
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  child: PatrimonyEvolution12MesesChart(data: historial12),
                ),
                const SizedBox(height: AppSpacing.sectionSpacing),

                // ── Evolución 10 años ────────────────────────────────────────
                const SectionHeader(
                  title: 'EVOLUCIÓN — ÚLTIMOS 10 AÑOS',
                  subtitle: 'Promedio anual en USD · Año actual: último valor registrado',
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  child: PatrimonyEvolution10AnosChart(data: historial10),
                ),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Patrimonio total card ────────────────────────────────────────────────────

class _PatrimonioTotalCard extends ConsumerWidget {
  final double totalUSD;
  final double dolarBlue;

  const _PatrimonioTotalCard({
    required this.totalUSD,
    required this.dolarBlue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(displayCurrencyProvider);
    final btcPrice = ref.watch(btcPriceUSDProvider);
    final fiatRates = ref.watch(fiatRatesProvider).value ?? {};

    final primaryText = CurrencyFormatter.fromUSD(totalUSD, currency,
        dolarBlue: dolarBlue, btcPrice: btcPrice, fiatRates: fiatRates);
    final secondaryText = CurrencyFormatter.secondaryFromUSD(totalUSD, currency,
        dolarBlue: dolarBlue, btcPrice: btcPrice, fiatRates: fiatRates);

    return AppCard(
      gradient: AppColors.primaryGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'PATRIMONIO TOTAL',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              const CurrencySelector(),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              primaryText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
          ),
          if (dolarBlue > 0) ...[
            const SizedBox(height: 4),
            Text(
              secondaryText,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (dolarBlue > 0)
                _StatChip(
                  label: 'USD Blue',
                  value: '\$${dolarBlue.toStringAsFixed(0)}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8), fontSize: 11)),
          const SizedBox(width: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _EmptyPortfolioCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const Icon(Icons.pie_chart_outline,
              size: 40, color: AppColors.textDisabled),
          const SizedBox(height: 12),
          Text(
            'Agregá tus inversiones para ver la composición',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
