import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../market_data/domain/dolar_quote.dart';

class DolarRatesWidget extends StatelessWidget {
  final List<DolarQuote> dolares;

  const DolarRatesWidget({super.key, required this.dolares});

  static const _tiposRelevantes = [
    'oficial',
    'blue',
    'bolsa',
    'contadoconliqui',
    'mayorista',
    'cripto',
  ];

  @override
  Widget build(BuildContext context) {
    final filtrados = dolares
        .where((d) => _tiposRelevantes.contains(d.casa.toLowerCase()))
        .toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filtrados.map((d) => _DolarCard(dolar: d)).toList(),
      ),
    );
  }
}

class _DolarCard extends StatelessWidget {
  final DolarQuote dolar;

  const _DolarCard({required this.dolar});

  Color get _accentColor {
    switch (dolar.casa.toLowerCase()) {
      case 'blue':
        return AppColors.primary;
      case 'oficial':
        return AppColors.success;
      case 'bolsa':
        return AppColors.secondary;
      case 'cripto':
        return AppColors.warning;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                dolar.nombre.split(' ').last,
                style: TextStyle(
                  color: _accentColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '\$${dolar.venta.toStringAsFixed(0)}',
              style: TextStyle(
                color: _accentColor,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Compra: \$${dolar.compra.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              DateFormatter.relativeTime(dolar.fechaActualizacion),
              style: TextStyle(
                color: AppColors.textDisabled,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
