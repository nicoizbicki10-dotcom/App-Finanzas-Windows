import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../market_data/providers/market_data_providers.dart';
import '../../domain/gasto.dart';
import 'add_gasto_sheet.dart';

class GastoListTile extends ConsumerWidget {
  final Gasto gasto;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const GastoListTile({
    super.key,
    required this.gasto,
    this.onDelete,
    this.onEdit,
  });

  void _openEdit(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddGastoSheet(gasto: gasto),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar gasto'),
        content: Text('¿Querés eliminar "${gasto.descripcion}"?'),
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
      key: Key(gasto.id),
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
            title: const Text('Eliminar gasto'),
            content: Text('¿Querés eliminar "${gasto.descripcion}"?'),
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
      },
      onDismissed: (_) => onDelete?.call(),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(gasto.categoria.emoji, style: const TextStyle(fontSize: 18)),
          ),
        ),
        title: Text(
          gasto.descripcion,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(gasto.categoria.label, style: Theme.of(context).textTheme.bodySmall),
            const Text(' · ', style: TextStyle(color: AppColors.textDisabled)),
            Text(DateFormatter.dayMonth(gasto.fecha), style: Theme.of(context).textTheme.bodySmall),
            if (gasto.recurrente) ...[
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
                  gasto.esUSD
                      ? 'USD ${gasto.monto.toStringAsFixed(2)}'
                      : CurrencyFormatter.ars(gasto.monto),
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  gasto.esUSD
                      ? '≈ ${CurrencyFormatter.compact(gasto.monto * dolarBlue)}'
                      : '≈ USD ${(gasto.monto / dolarBlue).toStringAsFixed(0)}',
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
