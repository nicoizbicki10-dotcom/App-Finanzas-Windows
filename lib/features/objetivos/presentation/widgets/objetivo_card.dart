import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/objetivo.dart';
import '../providers/objetivos_provider.dart';

class ObjetivoCard extends ConsumerWidget {
  final Objetivo objetivo;
  final bool isCompletado;

  const ObjetivoCard({
    super.key,
    required this.objetivo,
    this.isCompletado = false,
  });

  Color _accentColor() {
    if (objetivo.colorHex != null) {
      try {
        return Color(int.parse(objetivo.colorHex!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    return AppColors.warning;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = _accentColor();
    final pct = objetivo.progresoPct;
    final monedaPrefix = objetivo.moneda == MonedaObjetivo.ars ? '\$' : 'USD ';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(objetivo.tipo.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      objetivo.nombre,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (objetivo.descripcion.isNotEmpty)
                      Text(
                        objetivo.descripcion,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (objetivo.link != null && objetivo.link!.isNotEmpty)
                      GestureDetector(
                        onTap: () async {
                          final uri = Uri.tryParse(objetivo.link!);
                          if (uri != null && await canLaunchUrl(uri)) launchUrl(uri);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.open_in_new, size: 10, color: accent),
                            const SizedBox(width: 3),
                            Text('Ver referencia',
                                style: TextStyle(color: accent, fontSize: 10,
                                    decoration: TextDecoration.underline,
                                    decorationColor: accent)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (isCompletado)
                const Icon(Icons.check_circle, color: AppColors.success, size: 22)
              else
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
                  color: AppColors.surfaceElevated,
                  onSelected: (value) async {
                    if (value == 'delete') {
                      ref.read(objetivosNotifierProvider.notifier).eliminar(objetivo.id);
                    } else if (value == 'update') {
                      _showUpdateMontoDialog(context, ref);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'update',
                      child: Row(children: [
                        Icon(Icons.add_circle_outline, size: 16, color: AppColors.success),
                        SizedBox(width: 8),
                        Text('Actualizar monto'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                        SizedBox(width: 8),
                        Text('Eliminar', style: TextStyle(color: AppColors.danger)),
                      ]),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Barra de progreso
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$monedaPrefix${objetivo.montoActual >= 1000000 ? CurrencyFormatter.compact(objetivo.montoActual).replaceFirst('\$', '') : objetivo.montoActual.toStringAsFixed(0)}',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              Text(
                '${(pct * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$monedaPrefix${objetivo.montoMeta >= 1000000 ? CurrencyFormatter.compact(objetivo.montoMeta).replaceFirst('\$', '') : objetivo.montoMeta.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: accent.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 12),

          // Footer con fechas e info adicional
          Row(
            children: [
              if (!isCompletado) ...[
                Icon(Icons.schedule, size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  objetivo.diasRestantes > 0
                      ? '${objetivo.diasRestantes} días restantes'
                      : 'Meta vencida',
                  style: TextStyle(
                    color: objetivo.diasRestantes < 30
                        ? AppColors.warning
                        : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (objetivo.ahorroMensualRequerido > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${objetivo.moneda == MonedaObjetivo.ars ? '\$' : 'USD '}'
                      '${objetivo.ahorroMensualRequerido.toStringAsFixed(0)}/mes',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ] else ...[
                const Icon(Icons.check_circle_outline, size: 13, color: AppColors.success),
                const SizedBox(width: 4),
                Text(
                  '¡Objetivo completado!',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.success),
                ),
                const Spacer(),
                Text(
                  DateFormatter.short(objetivo.fechaMeta),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),

          // Mini gráfico de evolución si hay historial
          if (objetivo.historialMensual.length >= 3) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.surfaceBorder),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: _MiniProgressChart(
                historial: objetivo.historialMensual,
                meta: objetivo.montoMeta,
                color: accent,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showUpdateMontoDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(
      text: objetivo.montoActual.toStringAsFixed(0),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Actualizar "${objetivo.nombre}"'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Monto actual ${objetivo.moneda == MonedaObjetivo.ars ? "(ARS)" : "(USD)"}',
            prefixText: objetivo.moneda == MonedaObjetivo.ars ? '\$ ' : 'USD ',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final monto = double.tryParse(controller.text.replaceAll(',', '.'));
              if (monto != null && monto >= 0) {
                ref.read(objetivosNotifierProvider.notifier).actualizarMonto(objetivo.id, monto);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _MiniProgressChart extends StatelessWidget {
  final List<double> historial;
  final double meta;
  final Color color;

  const _MiniProgressChart({
    required this.historial,
    required this.meta,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final spots = historial
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          // Línea de progreso
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withOpacity(0.15),
            ),
          ),
          // Línea de meta (punteada)
          LineChartBarData(
            spots: [
              FlSpot(0, meta),
              FlSpot((historial.length - 1).toDouble(), meta),
            ],
            isCurved: false,
            color: AppColors.textDisabled,
            barWidth: 1,
            dashArray: [4, 4],
            dotData: const FlDotData(show: false),
          ),
        ],
        minY: 0,
        maxY: meta * 1.1,
      ),
    );
  }
}
