import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/display_currency_provider.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/currency_selector.dart';
import '../../../market_data/providers/market_data_providers.dart';
import '../providers/inversiones_provider.dart';

class InversionTotalBanner extends ConsumerWidget {
  /// Total en USD. Null = cargando.
  final double? totalUSD;
  final double? dolarVenta;
  /// Clave en distribucionPortfolioProvider ('Inmuebles', 'Acciones', etc.)
  final String? seccionKey;
  /// Promedio de variación vs compra para mostrar debajo del % patrimonio. Null = no mostrar.
  final double? variacionPromedio;

  const InversionTotalBanner({super.key, this.totalUSD, this.dolarVenta, this.seccionKey, this.variacionPromedio});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(displayCurrencyProvider);
    final btcPrice = ref.watch(btcPriceUSDProvider);
    final fiatRates = ref.watch(fiatRatesProvider).value ?? {};
    final dolar = dolarVenta ?? 0.0;
    final distribucion = ref.watch(distribucionPortfolioProvider).value ?? {};
    final pct = seccionKey != null ? distribucion[seccionKey] : null;
    final storageKey = seccionKey?.toLowerCase();
    final variacionAsync = storageKey != null
        ? ref.watch(variacionAnualSeccionProvider(storageKey))
        : null;
    final variacion = variacionAsync?.value;

    if (totalUSD == null) {
      return Container(
        width: double.infinity,
        height: 80,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.success),
          ),
        ),
      );
    }

    final primaryText = CurrencyFormatter.fromUSD(totalUSD!, currency,
        dolarBlue: dolar, btcPrice: btcPrice, fiatRates: fiatRates);
    final secondaryText = CurrencyFormatter.secondaryFromUSD(totalUSD!, currency,
        dolarBlue: dolar, btcPrice: btcPrice, fiatRates: fiatRates);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOTAL EN $currency',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (pct != null && pct > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${pct.toStringAsFixed(1)}% del patrimonio',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      CurrencySelector(color: AppColors.textSecondary),
                    ],
                  ),
                  if (variacionPromedio != null) ...[
                    const SizedBox(height: 4),
                    _VarVsCompraChip(variacion: variacionPromedio!),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            primaryText,
            style: const TextStyle(
              color: AppColors.success,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          if (secondaryText.isNotEmpty || variacion != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (secondaryText.isNotEmpty)
                  Text(
                    secondaryText,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                const Spacer(),
                if (variacion != null) _VariacionChip(variacion: variacion),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _VarVsCompraChip extends StatelessWidget {
  final double variacion;
  const _VarVsCompraChip({required this.variacion});

  @override
  Widget build(BuildContext context) {
    final isPositive = variacion >= 0;
    final color = isPositive ? AppColors.success : AppColors.danger;
    final icon = isPositive ? Icons.arrow_upward : Icons.arrow_downward;
    final sign = isPositive ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            'Var. vs compra $sign${variacion.toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _VariacionChip extends StatelessWidget {
  final double variacion;
  const _VariacionChip({required this.variacion});

  @override
  Widget build(BuildContext context) {
    final isPositive = variacion >= 0;
    final color = isPositive ? AppColors.success : AppColors.danger;
    final icon = isPositive ? Icons.arrow_upward : Icons.arrow_downward;
    final sign = isPositive ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            '$sign${variacion.toStringAsFixed(1)}% anual',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
