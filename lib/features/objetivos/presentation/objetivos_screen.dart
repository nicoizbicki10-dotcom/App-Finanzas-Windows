import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_header.dart';
import '../domain/objetivo.dart';
import 'providers/objetivos_provider.dart';
import 'widgets/add_objetivo_sheet.dart';
import 'widgets/objetivo_card.dart';

class ObjetivosScreen extends ConsumerWidget {
  const ObjetivosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activos = ref.watch(objetivosActivosProvider);
    final completados = ref.watch(objetivosCompletadosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Objetivos Financieros')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const AddObjetivoSheet(),
        ),
        backgroundColor: AppColors.warning,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Resumen ──────────────────────────────────────────────
                if (activos.isNotEmpty) ...[
                  _ObjetivosResumen(activos: activos),
                  const SizedBox(height: AppSpacing.sectionSpacing),
                ],

                // ── Objetivos activos ────────────────────────────────────
                SectionHeader(
                  title: 'EN PROGRESO',
                  subtitle: '${activos.length} objetivo${activos.length != 1 ? 's' : ''}',
                ),
                const SizedBox(height: AppSpacing.sm),
                if (activos.isEmpty)
                  _EmptyObjetivos()
                else
                  ...activos.map((o) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: ObjetivoCard(objetivo: o),
                      )),

                // ── Completados ──────────────────────────────────────────
                if (completados.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sectionSpacing),
                  SectionHeader(
                    title: 'COMPLETADOS',
                    subtitle: '${completados.length} objetivo${completados.length != 1 ? 's' : ''}',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...completados.map(
                    (o) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ObjetivoCard(objetivo: o, isCompletado: true),
                    ),
                  ),
                ],
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ObjetivosResumen extends StatelessWidget {
  final List<Objetivo> activos;
  const _ObjetivosResumen({required this.activos});

  @override
  Widget build(BuildContext context) {
    final totalMeta = activos.fold(0.0, (s, o) {
      if (o.moneda == MonedaObjetivo.ars) return s + o.montoMeta;
      return s;
    });
    final totalActual = activos.fold(0.0, (s, o) {
      if (o.moneda == MonedaObjetivo.ars) return s + o.montoActual;
      return s;
    });
    final progresoGlobal = totalMeta > 0 ? totalActual / totalMeta : 0.0;

    return AppCard(
      gradient: const LinearGradient(
        colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag, color: AppColors.warning, size: 18),
              const SizedBox(width: 8),
              Text(
                'PROGRESO GLOBAL',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progresoGlobal.clamp(0.0, 1.0),
              backgroundColor: AppColors.surfaceBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.warning),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                CurrencyFormatter.compact(totalActual),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              Text(
                '${(progresoGlobal * 100).toStringAsFixed(1)}% completado',
                style: const TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                CurrencyFormatter.compact(totalMeta),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyObjetivos extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const Text('🎯', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            'No tenés objetivos activos',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Creá tu primer objetivo financiero\ntocando el botón +',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
