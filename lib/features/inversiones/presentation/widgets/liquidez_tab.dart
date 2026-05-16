import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../gastos/domain/gasto.dart';
import '../../../gastos/presentation/providers/gastos_provider.dart';
import '../../../market_data/providers/market_data_providers.dart';
import '../../data/currency_data.dart';
import '../../domain/inversion_models.dart';
import '../providers/inversiones_provider.dart';
import 'inversion_total_banner.dart';

enum _SortLiquidez {
  montoUSD('Monto (equiv. USD)'),
  tna('TNA %');

  const _SortLiquidez(this.label);
  final String label;
}

class LiquidezTab extends ConsumerStatefulWidget {
  const LiquidezTab({super.key});

  @override
  ConsumerState<LiquidezTab> createState() => _LiquidezTabState();
}

class _LiquidezTabState extends ConsumerState<LiquidezTab> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  TipoLiquidez? _filterTipo;
  _SortLiquidez? _sort;
  bool _sortAsc = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    int c = 0;
    if (_filterTipo != null) c++;
    if (_sort != null) c++;
    return c;
  }

  List<Liquidez> _apply(List<Liquidez> source, double dolarVenta) {
    var list = source.where((l) {
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        if (!l.nombre.toLowerCase().contains(q) &&
            !l.institucion.toLowerCase().contains(q)) return false;
      }
      if (_filterTipo != null && l.tipo != _filterTipo) return false;
      return true;
    }).toList();

    if (_sort != null) {
      list.sort((a, b) {
        double va, vb;
        switch (_sort!) {
          case _SortLiquidez.montoUSD:
            va = monedaToUSD(a.monto, a.moneda, dolarVenta);
            vb = monedaToUSD(b.monto, b.moneda, dolarVenta);
          case _SortLiquidez.tna:
            va = a.tasaAnualPct ?? 0;
            vb = b.tasaAnualPct ?? 0;
        }
        return _sortAsc ? va.compareTo(vb) : vb.compareTo(va);
      });
    }
    return list;
  }

  Future<void> _openFilters(BuildContext ctx, double dolarVenta) async {
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LiquidezFilterSheet(
        initTipo: _filterTipo,
        initSort: _sort,
        initSortAsc: _sortAsc,
        onApply: (tipo, sort, sortAsc) => setState(() {
          _filterTipo = tipo;
          _sort = sort;
          _sortAsc = sortAsc;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liquidez = ref.watch(liquidezProvider);
    final dolarAsync = ref.watch(dolarProvider);

    final dolarVenta = dolarAsync.value
            ?.where((d) => d.casa.toLowerCase() == 'blue')
            .map((d) => d.venta)
            .firstOrNull ??
        1050.0;

    final filtered = _apply(liquidez, dolarVenta);

    final totalUSD = liquidez.fold(
      0.0,
      (s, l) => s + monedaToUSD(l.monto, l.moneda, dolarVenta),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InversionTotalBanner(totalUSD: totalUSD, dolarVenta: dolarVenta, seccionKey: 'Liquidez'),
        Row(
          children: [
            const Spacer(),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Icon(Icons.tune,
                      color: _activeFilterCount > 0
                          ? AppColors.info
                          : AppColors.textSecondary),
                  tooltip: 'Filtros y orden',
                  onPressed: () => _openFilters(context, dolarVenta),
                ),
                if (_activeFilterCount > 0)
                  Positioned(
                    right: 4, top: 4,
                    child: Container(
                      width: 16, height: 16,
                      decoration: const BoxDecoration(
                          color: AppColors.info, shape: BoxShape.circle),
                      child: Center(
                        child: Text('$_activeFilterCount',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const _LiquidezSheet(),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Agregar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.info,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Buscar por nombre o institución...',
            prefixIcon:
                const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
            suffixIcon: _search.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () =>
                        setState(() {
                          _search = '';
                          _searchCtrl.clear();
                        }),
                  )
                : null,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
        const SizedBox(height: AppSpacing.xs),

        // Active filter chips
        if (_activeFilterCount > 0) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              if (_filterTipo != null)
                _LiqChip(
                    label: '${_filterTipo!.emoji} ${_filterTipo!.label}',
                    onRemove: () => setState(() => _filterTipo = null)),
              if (_sort != null)
                _LiqChip(
                    label: '${_sortAsc ? '↑' : '↓'} ${_sort!.label}',
                    onRemove: () => setState(() => _sort = null)),
              TextButton(
                onPressed: () => setState(() {
                  _filterTipo = null;
                  _sort = null;
                }),
                child: const Text('Limpiar',
                    style: TextStyle(fontSize: 11, color: AppColors.danger)),
              ),
            ]),
          ),
          const SizedBox(height: 4),
        ],

        if (liquidez.isEmpty)
          Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.account_balance_outlined,
                  size: 40, color: AppColors.textDisabled),
              const SizedBox(height: 12),
              Text('No tenés cuentas ni efectivo registrado',
                  style: Theme.of(context).textTheme.bodyMedium),
            ]),
          )
        else if (filtered.isEmpty)
          Expanded(
            child: Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.search_off, size: 40, color: AppColors.textDisabled),
                const SizedBox(height: 12),
                const Text('Sin resultados',
                    style: TextStyle(color: AppColors.textSecondary)),
                TextButton(
                    onPressed: () => setState(() {
                          _search = '';
                          _searchCtrl.clear();
                          _filterTipo = null;
                          _sort = null;
                        }),
                    child: const Text('Limpiar filtros')),
              ]),
            ),
          )
        else ...[
          // Group filtered entries by tipoLabel (no duplicates shown)
          Builder(builder: (_) {
            final Map<String, List<Liquidez>> grouped = {};
            for (final l in filtered) {
              (grouped[l.tipoLabel] ??= []).add(l);
            }
            final groups = grouped.entries.toList();
            return Expanded(
              child: ListView.separated(
                itemCount: groups.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) => _LiquidezTipoCard(
                  tipoLabel: groups[i].key,
                  cuentas: groups[i].value,
                  dolarVenta: dolarVenta,
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _LiqChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _LiqChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.info,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
        const SizedBox(width: 2),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.close, size: 13, color: AppColors.info),
        ),
      ]),
    );
  }
}

class _LiquidezFilterSheet extends StatefulWidget {
  final TipoLiquidez? initTipo;
  final _SortLiquidez? initSort;
  final bool initSortAsc;
  final void Function(TipoLiquidez? tipo, _SortLiquidez? sort, bool sortAsc) onApply;

  const _LiquidezFilterSheet({
    required this.initTipo,
    required this.initSort,
    required this.initSortAsc,
    required this.onApply,
  });

  @override
  State<_LiquidezFilterSheet> createState() => _LiquidezFilterSheetState();
}

class _LiquidezFilterSheetState extends State<_LiquidezFilterSheet> {
  TipoLiquidez? _tipo;
  _SortLiquidez? _sort;
  bool _sortAsc = false;

  @override
  void initState() {
    super.initState();
    _tipo = widget.initTipo;
    _sort = widget.initSort;
    _sortAsc = widget.initSortAsc;
  }

  void _clear() => setState(() {
        _tipo = null;
        _sort = null;
        _sortAsc = false;
      });

  void _apply() {
    widget.onApply(_tipo, _sort, _sortAsc);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
                child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.surfaceBorder,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: Text('Filtros y ordenar',
                      style: Theme.of(context).textTheme.headlineMedium)),
              TextButton(
                  onPressed: _clear,
                  child: const Text('Limpiar',
                      style: TextStyle(color: AppColors.danger, fontSize: 13))),
            ]),
            const SizedBox(height: 20),

            _LiqSectionLabel(label: 'Tipo de cuenta'),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _LiqFilterChip(
                  label: 'Todos',
                  selected: _tipo == null,
                  onTap: () => setState(() => _tipo = null)),
              ...TipoLiquidez.values.map((t) => _LiqFilterChip(
                    label: '${t.emoji} ${t.label}',
                    selected: _tipo == t,
                    onTap: () =>
                        setState(() => _tipo = _tipo == t ? null : t),
                  )),
            ]),
            const SizedBox(height: 20),

            _LiqSectionLabel(label: 'Ordenar por'),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _LiqFilterChip(
                  label: 'Sin ordenar',
                  selected: _sort == null,
                  onTap: () => setState(() => _sort = null)),
              ..._SortLiquidez.values.map((s) => _LiqFilterChip(
                    label: s.label,
                    selected: _sort == s,
                    onTap: () =>
                        setState(() => _sort = _sort == s ? null : s),
                  )),
            ]),
            if (_sort != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Text('Dirección:',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('↓ Mayor primero'),
                  selected: !_sortAsc,
                  onSelected: (_) => setState(() => _sortAsc = false),
                  selectedColor: AppColors.info.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                      color: !_sortAsc ? AppColors.info : AppColors.textSecondary,
                      fontSize: 12),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('↑ Menor primero'),
                  selected: _sortAsc,
                  onSelected: (_) => setState(() => _sortAsc = true),
                  selectedColor: AppColors.info.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                      color: _sortAsc ? AppColors.info : AppColors.textSecondary,
                      fontSize: 12),
                ),
              ]),
            ],
            const SizedBox(height: 28),

            ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.info,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Aplicar filtros',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiqSectionLabel extends StatelessWidget {
  final String label;
  const _LiqSectionLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label,
          style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5)),
    );
  }
}

class _LiqFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LiqFilterChip(
      {required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.info.withValues(alpha: 0.15)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.info : AppColors.surfaceBorder),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? AppColors.info : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _LiquidezTipoCard extends StatelessWidget {
  final String tipoLabel;
  final List<Liquidez> cuentas;
  final double dolarVenta;
  const _LiquidezTipoCard(
      {required this.tipoLabel, required this.cuentas, required this.dolarVenta});

  @override
  Widget build(BuildContext context) {
    final totalUSD = cuentas.fold(
        0.0, (s, l) => s + monedaToUSD(l.monto, l.moneda, dolarVenta));
    final totalARS = totalUSD * dolarVenta;
    final emoji = cuentas.first.tipo.emoji;
    final n = cuentas.length;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tipoLabel, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  n == 1 ? '1 cuenta' : '$n cuentas',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.usd(totalUSD),
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
              Text(
                '≈ ${CurrencyFormatter.compact(totalARS)} ARS',
                style: const TextStyle(color: AppColors.warning, fontSize: 11),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.history, size: 20, color: AppColors.textSecondary),
            tooltip: 'Ver cuentas',
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _LiquidezCuentasSheet(
                tipoLabel: tipoLabel,
                cuentas: cuentas,
                dolarVenta: dolarVenta,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiquidezCuentasSheet extends ConsumerWidget {
  final String tipoLabel;
  final List<Liquidez> cuentas;
  final double dolarVenta;
  const _LiquidezCuentasSheet(
      {required this.tipoLabel, required this.cuentas, required this.dolarVenta});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cuentaIds = cuentas.map((l) => l.id).toSet();
    final gastos = ref
        .watch(gastosProvider)
        .where((g) => g.medioPagoId != null && cuentaIds.contains(g.medioPagoId))
        .toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));

    final isEmpty = cuentas.isEmpty && gastos.isEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(tipoLabel, style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const _SheetSectionLabel(label: 'OPERACIONES'),
            if (isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Sin operaciones registradas',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...cuentas.map((l) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _SaldoTile(liquidez: l, dolarVenta: dolarVenta),
                          )),
                      ...gastos.map((g) => _GastoTile(gasto: g, dolarVenta: dolarVenta)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SheetSectionLabel extends StatelessWidget {
  final String label;
  const _SheetSectionLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8),
      ),
    );
  }
}

class _SaldoTile extends ConsumerWidget {
  final Liquidez liquidez;
  final double dolarVenta;
  const _SaldoTile({required this.liquidez, required this.dolarVenta});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = monedaInfo(liquidez.moneda);
    final valorUSD = monedaToUSD(liquidez.monto, liquidez.moneda, dolarVenta);

    String primaryAmount;
    if (liquidez.moneda == 'ARS') {
      primaryAmount = CurrencyFormatter.compact(liquidez.monto);
    } else if (liquidez.moneda == 'USD') {
      primaryAmount = CurrencyFormatter.usd(liquidez.monto);
    } else {
      final fmt = NumberFormat('#,##0.00', 'es_AR');
      primaryAmount = '${info.simbolo} ${fmt.format(liquidez.monto)}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Text(liquidez.tipo.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  liquidez.nombre,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Saldo',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+ $primaryAmount',
                style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              if (liquidez.moneda != 'USD')
                Text(
                  '≈ ${CurrencyFormatter.usd(valorUSD)}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                size: 16, color: AppColors.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _LiquidezSheet(liquidez: liquidez),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 16, color: AppColors.textDisabled),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => ref
                .read(inversionesNotifierProvider.notifier)
                .eliminarLiquidez(liquidez.id),
          ),
        ],
      ),
    );
  }
}

class _GastoTile extends StatelessWidget {
  final Gasto gasto;
  final double dolarVenta;
  const _GastoTile({required this.gasto, required this.dolarVenta});

  @override
  Widget build(BuildContext context) {
    final montoARS =
        gasto.esUSD ? gasto.monto * dolarVenta : gasto.monto;
    final montoUSD =
        gasto.esUSD ? gasto.monto : gasto.monto / dolarVenta;
    final fechaStr =
        DateFormat('dd/MM/yyyy', 'es_AR').format(gasto.fecha);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          children: [
            Text(gasto.categoria.emoji,
                style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(gasto.descripcion,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                  Text(fechaStr,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '- ${CurrencyFormatter.compact(montoARS)}',
                  style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  '≈ ${CurrencyFormatter.usd(montoUSD)}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LiquidezSheet extends ConsumerStatefulWidget {
  final Liquidez? liquidez;
  const _LiquidezSheet({this.liquidez});

  @override
  ConsumerState<_LiquidezSheet> createState() => _LiquidezSheetState();
}

class _LiquidezSheetState extends ConsumerState<_LiquidezSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _institucionCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  final _tasaCtrl = TextEditingController();
  final _tipoPersonalizadoCtrl = TextEditingController();
  TipoLiquidez _tipo = TipoLiquidez.cajaAhorroARS;
  String _moneda = 'ARS';
  bool _saving = false;

  bool get _isEditing => widget.liquidez != null;

  @override
  void initState() {
    super.initState();
    final l = widget.liquidez;
    if (l != null) {
      _nombreCtrl.text = l.nombre;
      _institucionCtrl.text = l.institucion;
      _montoCtrl.text = l.monto > 0 ? l.monto.toString() : '';
      _moneda = l.moneda;
      if (l.tasaAnualPct != null) _tasaCtrl.text = l.tasaAnualPct.toString();
      _tipo = l.tipo;
      if (l.tipoPersonalizado != null) _tipoPersonalizadoCtrl.text = l.tipoPersonalizado!;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _institucionCtrl.dispose();
    _montoCtrl.dispose();
    _tasaCtrl.dispose();
    _tipoPersonalizadoCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final l = Liquidez(
      id: widget.liquidez?.id,
      nombre: _nombreCtrl.text.trim(),
      monto: double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ?? 0,
      moneda: _moneda,
      institucion: _institucionCtrl.text.trim(),
      tipo: _tipo,
      tipoPersonalizado: _tipo == TipoLiquidez.personalizado && _tipoPersonalizadoCtrl.text.trim().isNotEmpty
          ? _tipoPersonalizadoCtrl.text.trim()
          : null,
      tasaAnualPct: _tasaCtrl.text.isNotEmpty
          ? double.tryParse(_tasaCtrl.text.replaceAll(',', '.'))
          : null,
    );

    await ref.read(inversionesNotifierProvider.notifier).agregarLiquidez(l);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: sc,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
            ),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.surfaceBorder,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(_isEditing ? 'Editar Liquidez' : 'Agregar Liquidez',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.lg),

              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre / Alias'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              DropdownButtonFormField<TipoLiquidez>(
                value: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                dropdownColor: AppColors.surfaceElevated,
                isExpanded: true,
                items: TipoLiquidez.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Row(children: [
                            Text(t.emoji),
                            const SizedBox(width: 8),
                            Text(t.label, overflow: TextOverflow.ellipsis),
                          ]),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _tipo = v!),
              ),
              if (_tipo == TipoLiquidez.personalizado) ...[
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _tipoPersonalizadoCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre del tipo'),
                  validator: (v) => _tipo == TipoLiquidez.personalizado && (v == null || v.isEmpty)
                      ? 'Ingresá un nombre para el tipo'
                      : null,
                ),
              ],
              const SizedBox(height: AppSpacing.md),

              TextFormField(
                controller: _institucionCtrl,
                decoration: const InputDecoration(labelText: 'Institución / Banco'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // Monto + Moneda
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _montoCtrl,
                      decoration: const InputDecoration(labelText: 'Monto'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requerido';
                        if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Inválido';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _moneda,
                      decoration: const InputDecoration(labelText: 'Moneda'),
                      dropdownColor: AppColors.surfaceElevated,
                      isExpanded: true,
                      items: kMonedas
                          .map((m) => DropdownMenuItem(
                                value: m.codigo,
                                child: Text('${m.codigo} ${m.simbolo}',
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _moneda = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              if (_tipo == TipoLiquidez.plazoFijo || _tipo == TipoLiquidez.fondoComun)
                TextFormField(
                  controller: _tasaCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Tasa Anual (TNA %)', suffixText: '%'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),

              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.info,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isEditing ? 'Guardar Cambios' : 'Agregar Cuenta',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
