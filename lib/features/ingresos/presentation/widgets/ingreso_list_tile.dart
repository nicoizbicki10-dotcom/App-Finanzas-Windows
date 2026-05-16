import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../market_data/providers/market_data_providers.dart';
import '../../domain/ingreso.dart';
import 'add_ingreso_sheet.dart';

class IngresoListTile extends ConsumerWidget {
  final Ingreso ingreso;
  final VoidCallback? onDelete;

  const IngresoListTile({super.key, required this.ingreso, this.onDelete});

  void _openEdit(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddIngresoSheet(ingreso: ingreso),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar ingreso'),
        content: Text('¿Querés eliminar "${ingreso.descripcion}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) onDelete?.call();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dolarBlue = ref.watch(dolarBlueVentaProvider);

    return Dismissible(
      key: Key(ingreso.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.danger.withOpacity(0.2),
        child: const Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Eliminar ingreso'),
            content: Text('¿Querés eliminar "${ingreso.descripcion}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Eliminar',
                    style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete?.call(),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(ingreso.categoria.emoji, style: const TextStyle(fontSize: 18)),
          ),
        ),
        title: Text(
          ingreso.descripcion,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(ingreso.categoria.label, style: Theme.of(context).textTheme.bodySmall),
            const Text(' · ', style: TextStyle(color: AppColors.textDisabled)),
            Text(DateFormatter.dayMonth(ingreso.fecha),
                style: Theme.of(context).textTheme.bodySmall),
            if (ingreso.recurrente) ...[
              const Text(' · ', style: TextStyle(color: AppColors.textDisabled)),
              const Icon(Icons.repeat, size: 12, color: AppColors.info),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  ingreso.esUSD
                      ? 'USD ${ingreso.monto.toStringAsFixed(2)}'
                      : CurrencyFormatter.ars(ingreso.monto),
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  ingreso.esUSD
                      ? '≈ ${CurrencyFormatter.compact(ingreso.monto * dolarBlue)}'
                      : '≈ USD ${(ingreso.monto / dolarBlue).toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
              onPressed: () => _openEdit(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
              onPressed: () => _confirmDelete(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}
