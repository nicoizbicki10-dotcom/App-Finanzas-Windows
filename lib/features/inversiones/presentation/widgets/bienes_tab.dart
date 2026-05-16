import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../market_data/providers/market_data_providers.dart';
import '../../data/currency_data.dart';
import '../../domain/inversion_models.dart';
import '../providers/inversiones_provider.dart';
import 'inversion_total_banner.dart';

enum _SortBien {
  precioCompra('Precio de compra'),
  valorEstimado('Valor estimado'),
  variacion('Variación %');

  const _SortBien(this.label);
  final String label;
}

class BienesTab extends ConsumerStatefulWidget {
  const BienesTab({super.key});

  @override
  ConsumerState<BienesTab> createState() => _BienesTabState();
}

class _BienesTabState extends ConsumerState<BienesTab> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  TipoBienDeUso? _filterTipo;
  int? _filterAnio;
  DateTime? _compraDesde;
  DateTime? _compraHasta;
  _SortBien? _sort;
  bool _sortAsc = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    int c = 0;
    if (_filterTipo != null) c++;
    if (_filterAnio != null) c++;
    if (_compraDesde != null) c++;
    if (_compraHasta != null) c++;
    if (_sort != null) c++;
    return c;
  }

  List<BienDeUso> _apply(List<BienDeUso> source) {
    var list = source.where((b) {
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        if (!b.nombre.toLowerCase().contains(q) &&
            !b.modelo.toLowerCase().contains(q)) return false;
      }
      if (_filterTipo != null && b.tipo != _filterTipo) return false;
      if (_filterAnio != null && b.anio != _filterAnio) return false;
      if (_compraDesde != null && b.fechaCompra.isBefore(_compraDesde!)) return false;
      if (_compraHasta != null && b.fechaCompra.isAfter(_compraHasta!)) return false;
      return true;
    }).toList();

    if (_sort != null) {
      list.sort((a, b) {
        double va, vb;
        switch (_sort!) {
          case _SortBien.precioCompra:
            va = a.precioCompra; vb = b.precioCompra;
          case _SortBien.valorEstimado:
            va = a.valorEstimadoActual ?? 0;
            vb = b.valorEstimadoActual ?? 0;
          case _SortBien.variacion:
            va = a.variacionPct ?? -9999;
            vb = b.variacionPct ?? -9999;
        }
        return _sortAsc ? va.compareTo(vb) : vb.compareTo(va);
      });
    }
    return list;
  }

  Future<void> _openFilters(BuildContext ctx, List<int> years) async {
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BienFilterSheet(
        initTipo: _filterTipo,
        initAnio: _filterAnio,
        availableYears: years,
        initSort: _sort,
        initSortAsc: _sortAsc,
        initCompraDesde: _compraDesde,
        initCompraHasta: _compraHasta,
        onApply: (tipo, anio, sort, sortAsc, compraDesde, compraHasta) => setState(() {
          _filterTipo = tipo;
          _filterAnio = anio;
          _sort = sort;
          _sortAsc = sortAsc;
          _compraDesde = compraDesde;
          _compraHasta = compraHasta;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bienes = ref.watch(bienesProvider);
    final filtered = _apply(bienes);
    final years = bienes.map((b) => b.anio).toSet().toList()..sort((a, b) => b.compareTo(a));
    final totalBienesAsync = ref.watch(valorBienesUSDProvider);
    final dolarVenta = ref.watch(dolarProvider).value
            ?.where((d) => d.casa.toLowerCase() == 'blue')
            .map((d) => d.venta)
            .firstOrNull ??
        1050.0;

    final varItems = bienes.map((b) => b.variacionPct).whereType<double>().toList();
    final avgVar = varItems.isEmpty ? null : varItems.reduce((a, b) => a + b) / varItems.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InversionTotalBanner(
          totalUSD: totalBienesAsync.value,
          dolarVenta: dolarVenta,
          seccionKey: 'Bienes',
          variacionPromedio: avgVar,
        ),
        Row(
          children: [
            if (bienes.isNotEmpty)
              Text(
                '${bienes.length} bien${bienes.length == 1 ? '' : 'es'}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
            const Spacer(),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Icon(Icons.tune,
                      color: _activeFilterCount > 0
                          ? AppColors.warning
                          : AppColors.textSecondary),
                  tooltip: 'Filtros y orden',
                  onPressed: () => _openFilters(context, years),
                ),
                if (_activeFilterCount > 0)
                  Positioned(
                    right: 4, top: 4,
                    child: Container(
                      width: 16, height: 16,
                      decoration: const BoxDecoration(
                          color: AppColors.warning, shape: BoxShape.circle),
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
                builder: (_) => const _BienSheet(),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Agregar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
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
            hintText: 'Buscar por nombre o modelo...',
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

        // Active chips
        if (_activeFilterCount > 0) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              if (_filterTipo != null)
                _BienChip(
                    label: '${_filterTipo!.emoji} ${_filterTipo!.label}',
                    onRemove: () => setState(() => _filterTipo = null)),
              if (_filterAnio != null)
                _BienChip(
                    label: '📅 $_filterAnio',
                    onRemove: () => setState(() => _filterAnio = null)),
              if (_compraDesde != null)
                _BienChip(
                    label: 'Compra desde ${DateFormat('dd/MM/yy').format(_compraDesde!)}',
                    onRemove: () => setState(() => _compraDesde = null)),
              if (_compraHasta != null)
                _BienChip(
                    label: 'Compra hasta ${DateFormat('dd/MM/yy').format(_compraHasta!)}',
                    onRemove: () => setState(() => _compraHasta = null)),
              if (_sort != null)
                _BienChip(
                    label: '${_sortAsc ? '↑' : '↓'} ${_sort!.label}',
                    onRemove: () => setState(() => _sort = null)),
              TextButton(
                onPressed: () => setState(() {
                  _filterTipo = null;
                  _filterAnio = null;
                  _compraDesde = null;
                  _compraHasta = null;
                  _sort = null;
                }),
                child: const Text('Limpiar',
                    style: TextStyle(fontSize: 11, color: AppColors.danger)),
              ),
            ]),
          ),
          const SizedBox(height: 4),
        ],

        if (bienes.isEmpty)
          Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.directions_car_outlined,
                  size: 40, color: AppColors.textDisabled),
              const SizedBox(height: 12),
              Text('No hay bienes de uso registrados',
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
                          _filterAnio = null;
                          _compraDesde = null;
                          _compraHasta = null;
                          _sort = null;
                        }),
                    child: const Text('Limpiar filtros')),
              ]),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) => _BienCard(bien: filtered[i]),
            ),
          ),
      ],
    );
  }
}

class _BienChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _BienChip({required this.label, required this.onRemove});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.warning,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
        const SizedBox(width: 2),
        GestureDetector(
          onTap: onRemove,
          child:
              const Icon(Icons.close, size: 13, color: AppColors.warning),
        ),
      ]),
    );
  }
}

class _BienFilterSheet extends StatefulWidget {
  final TipoBienDeUso? initTipo;
  final int? initAnio;
  final List<int> availableYears;
  final _SortBien? initSort;
  final bool initSortAsc;
  final DateTime? initCompraDesde;
  final DateTime? initCompraHasta;
  final void Function(TipoBienDeUso? tipo, int? anio, _SortBien? sort, bool sortAsc,
      DateTime? compraDesde, DateTime? compraHasta) onApply;

  const _BienFilterSheet({
    required this.initTipo,
    required this.initAnio,
    required this.availableYears,
    required this.initSort,
    required this.initSortAsc,
    required this.initCompraDesde,
    required this.initCompraHasta,
    required this.onApply,
  });

  @override
  State<_BienFilterSheet> createState() => _BienFilterSheetState();
}

class _BienFilterSheetState extends State<_BienFilterSheet> {
  TipoBienDeUso? _tipo;
  int? _anio;
  _SortBien? _sort;
  bool _sortAsc = false;
  DateTime? _compraDesde;
  DateTime? _compraHasta;

  @override
  void initState() {
    super.initState();
    _tipo = widget.initTipo;
    _anio = widget.initAnio;
    _sort = widget.initSort;
    _sortAsc = widget.initSortAsc;
    _compraDesde = widget.initCompraDesde;
    _compraHasta = widget.initCompraHasta;
  }

  void _clear() => setState(() {
        _tipo = null;
        _anio = null;
        _sort = null;
        _sortAsc = false;
        _compraDesde = null;
        _compraHasta = null;
      });

  void _apply() {
    widget.onApply(_tipo, _anio, _sort, _sortAsc, _compraDesde, _compraHasta);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
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
                      style:
                          TextStyle(color: AppColors.danger, fontSize: 13))),
            ]),
            const SizedBox(height: 20),

            _BienSectionLabel(label: 'Tipo de bien'),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _BienFilterChip(
                  label: 'Todos',
                  selected: _tipo == null,
                  onTap: () => setState(() => _tipo = null)),
              ...TipoBienDeUso.values.map((t) => _BienFilterChip(
                    label: '${t.emoji} ${t.label}',
                    selected: _tipo == t,
                    onTap: () =>
                        setState(() => _tipo = _tipo == t ? null : t),
                  )),
            ]),
            const SizedBox(height: 20),

            if (widget.availableYears.isNotEmpty) ...[
              _BienSectionLabel(label: 'Año del bien'),
              Wrap(spacing: 8, runSpacing: 6, children: [
                _BienFilterChip(
                    label: 'Todos',
                    selected: _anio == null,
                    onTap: () => setState(() => _anio = null)),
                ...widget.availableYears.map((y) => _BienFilterChip(
                      label: '$y',
                      selected: _anio == y,
                      onTap: () =>
                          setState(() => _anio = _anio == y ? null : y),
                    )),
              ]),
              const SizedBox(height: 20),
            ],

            _BienSectionLabel(label: 'Rango de fecha de compra'),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month_outlined, size: 16),
                  label: Text(_compraDesde != null ? fmt.format(_compraDesde!) : 'Desde',
                      style: const TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _compraDesde != null ? AppColors.warning : AppColors.textSecondary,
                    side: BorderSide(
                        color: _compraDesde != null ? AppColors.warning : AppColors.surfaceBorder),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _compraDesde ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _compraDesde = d);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month_outlined, size: 16),
                  label: Text(_compraHasta != null ? fmt.format(_compraHasta!) : 'Hasta',
                      style: const TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _compraHasta != null ? AppColors.warning : AppColors.textSecondary,
                    side: BorderSide(
                        color: _compraHasta != null ? AppColors.warning : AppColors.surfaceBorder),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _compraHasta ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _compraHasta = d);
                  },
                ),
              ),
              if (_compraDesde != null || _compraHasta != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: AppColors.textDisabled),
                  onPressed: () => setState(() { _compraDesde = null; _compraHasta = null; }),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ]),
            const SizedBox(height: 20),

            _BienSectionLabel(label: 'Ordenar por'),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _BienFilterChip(
                  label: 'Sin ordenar',
                  selected: _sort == null,
                  onTap: () => setState(() => _sort = null)),
              ..._SortBien.values.map((s) => _BienFilterChip(
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
                  selectedColor: AppColors.warning.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                      color: !_sortAsc
                          ? AppColors.warning
                          : AppColors.textSecondary,
                      fontSize: 12),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('↑ Menor primero'),
                  selected: _sortAsc,
                  onSelected: (_) => setState(() => _sortAsc = true),
                  selectedColor: AppColors.warning.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                      color: _sortAsc
                          ? AppColors.warning
                          : AppColors.textSecondary,
                      fontSize: 12),
                ),
              ]),
            ],
            const SizedBox(height: 28),

            ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Aplicar filtros',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BienSectionLabel extends StatelessWidget {
  final String label;
  const _BienSectionLabel({required this.label});
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

class _BienFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _BienFilterChip(
      {required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.warning.withValues(alpha: 0.15)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? AppColors.warning
                  : AppColors.surfaceBorder),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected
                    ? AppColors.warning
                    : AppColors.textSecondary,
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _BienCard extends ConsumerWidget {
  final BienDeUso bien;
  const _BienCard({required this.bien});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = monedaInfo(bien.moneda);
    final fmt = NumberFormat('#,##0.##', 'es_AR');

    String formatMonto(double v) => '${info.simbolo} ${fmt.format(v)}';

    final variMonto = bien.variacionMonto;
    final variPct = bien.variacionPct;
    final isPositive = (variMonto ?? 0) >= 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(bien.tipo.emoji, style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bien.nombre, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      '${bien.tipo.label} · ${bien.modelo} · ${bien.anio}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
                color: AppColors.surfaceElevated,
                onSelected: (v) async {
                  if (v == 'edit') {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _BienSheet(bien: bien),
                    );
                  } else if (v == 'delete') {
                    ref.read(inversionesNotifierProvider.notifier).eliminarBien(bien.id);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Editar'),
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
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.surfaceBorder),
          const SizedBox(height: 12),

          // Precio de compra
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Precio de compra',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              Text(formatMonto(bien.precioCompra),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),

          // Valor actual (con auto-fetch de ML si no hay valor manual)
          _ValorActualRow(bien: bien),

          // Variación
          if (variMonto != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Variación vs compra',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                Row(
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 14,
                      color: isPositive ? AppColors.success : AppColors.danger,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${formatMonto(variMonto.abs())} (${variPct!.abs().toStringAsFixed(1)}%)',
                      style: TextStyle(
                        color: isPositive ? AppColors.success : AppColors.danger,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Widget de valor actual con auto-fetch ────────────────────────────────────

class _ValorActualRow extends ConsumerStatefulWidget {
  final BienDeUso bien;
  const _ValorActualRow({required this.bien});

  @override
  ConsumerState<_ValorActualRow> createState() => _ValorActualRowState();
}

class _ValorActualRowState extends ConsumerState<_ValorActualRow> {
  bool _autoSaved = false;

  @override
  Widget build(BuildContext context) {
    final info = monedaInfo(widget.bien.moneda);
    final fmt = NumberFormat('#,##0.##', 'es_AR');
    String formatMonto(double v) => '${info.simbolo} ${fmt.format(v)}';

    if (widget.bien.valorEstimadoActual != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Valor actual estimado',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text(
            formatMonto(widget.bien.valorEstimadoActual!),
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
          ),
        ],
      );
    }

    final mlKey = '${widget.bien.modelo}|${widget.bien.anio}';
    final precioAsync = ref.watch(precioVehiculoProvider(mlKey));

    ref.listen<AsyncValue<double?>>(precioVehiculoProvider(mlKey), (_, next) {
      if (!_autoSaved && next.hasValue && next.value != null) {
        _autoSaved = true;
        final updated = widget.bien.copyWith(valorEstimadoActual: next.value);
        ref.read(inversionesNotifierProvider.notifier).agregarBien(updated);
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Valor actual estimado',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            precioAsync.when(
              loading: () => const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.warning),
              ),
              error: (_, __) => TextButton(
                onPressed: () => showModalBottomSheet(
                  context: context, isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _BienSheet(bien: widget.bien),
                ),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero, minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Text('+ Ingresar valor',
                    style: TextStyle(fontSize: 12, color: AppColors.primary)),
              ),
              data: (precio) => precio == null
                  ? TextButton(
                      onPressed: () => showModalBottomSheet(
                        context: context, isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _BienSheet(bien: widget.bien),
                      ),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero, minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: const Text('+ Ingresar valor',
                          style: TextStyle(fontSize: 12, color: AppColors.primary)),
                    )
                  : Text(
                      '${formatMonto(precio)} (ML)',
                      style: const TextStyle(
                          color: AppColors.warning, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
            ),
          ],
        ),
        if (precioAsync.value != null)
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text('Estimado vía MercadoLibre · guardando automáticamente...',
                style: TextStyle(color: AppColors.textDisabled, fontSize: 10)),
          ),
      ],
    );
  }
}

// ─── Sheet ──────────────────────────────────────────────────────────────────

class _BienSheet extends ConsumerStatefulWidget {
  final BienDeUso? bien;
  const _BienSheet({this.bien});

  @override
  ConsumerState<_BienSheet> createState() => _BienSheetState();
}

class _BienSheetState extends ConsumerState<_BienSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _anioCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _valorEstCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  TipoBienDeUso _tipo = TipoBienDeUso.auto;
  String _moneda = 'USD';
  DateTime _fechaCompra = DateTime.now();
  bool _saving = false;
  Timer? _debounce;
  bool _fetchingPrecio = false;

  bool get _isEditing => widget.bien != null;

  @override
  void initState() {
    super.initState();
    final b = widget.bien;
    if (b != null) {
      _nombreCtrl.text = b.nombre;
      _modeloCtrl.text = b.modelo;
      _anioCtrl.text = b.anio.toString();
      _precioCtrl.text = b.precioCompra.toString();
      if (b.valorEstimadoActual != null) {
        _valorEstCtrl.text = b.valorEstimadoActual.toString();
      }
      _notasCtrl.text = b.notas ?? '';
      _tipo = b.tipo;
      _moneda = b.moneda;
      _fechaCompra = b.fechaCompra;
    } else {
      _anioCtrl.text = DateTime.now().year.toString();
    }
    _modeloCtrl.addListener(_onModeloAnioChanged);
    _anioCtrl.addListener(_onModeloAnioChanged);
    if (widget.bien == null || widget.bien!.valorEstimadoActual == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoFetchPrecio());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nombreCtrl.dispose(); _modeloCtrl.dispose(); _anioCtrl.dispose();
    _precioCtrl.dispose(); _valorEstCtrl.dispose(); _notasCtrl.dispose();
    super.dispose();
  }

  void _onModeloAnioChanged() {
    if (_valorEstCtrl.text.isNotEmpty) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 900), _autoFetchPrecio);
  }

  Future<void> _autoFetchPrecio() async {
    final modelo = _modeloCtrl.text.trim();
    final anio = int.tryParse(_anioCtrl.text.trim());
    if (modelo.isEmpty || anio == null) return;
    if (_valorEstCtrl.text.isNotEmpty) return;
    setState(() => _fetchingPrecio = true);
    final ds = ref.read(mercadoLibreDatasourceProvider);
    final precio = await ds.fetchPrecioVehiculo(modelo, anio);
    if (mounted) {
      setState(() {
        _fetchingPrecio = false;
        if (precio != null && _valorEstCtrl.text.isEmpty) {
          _valorEstCtrl.text = precio.toStringAsFixed(0);
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final bien = BienDeUso(
      id: widget.bien?.id,
      nombre: _nombreCtrl.text.trim(),
      tipo: _tipo,
      modelo: _modeloCtrl.text.trim(),
      anio: int.tryParse(_anioCtrl.text) ?? DateTime.now().year,
      fechaCompra: _fechaCompra,
      precioCompra: double.tryParse(_precioCtrl.text.replaceAll(',', '.')) ?? 0,
      moneda: _moneda,
      valorEstimadoActual: _valorEstCtrl.text.isNotEmpty
          ? double.tryParse(_valorEstCtrl.text.replaceAll(',', '.'))
          : null,
      notas: _notasCtrl.text.trim().isNotEmpty ? _notasCtrl.text.trim() : null,
    );

    await ref.read(inversionesNotifierProvider.notifier).agregarBien(bien);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final info = monedaInfo(_moneda);

    return DraggableScrollableSheet(
      initialChildSize: 0.92, maxChildSize: 0.97,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: sc,
            padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md,
                MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.surfaceBorder,
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: AppSpacing.md),
              Text(_isEditing ? 'Editar Bien' : 'Agregar Bien de Uso',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.lg),

              // Tipo
              DropdownButtonFormField<TipoBienDeUso>(
                initialValue: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo de bien'),
                dropdownColor: AppColors.surfaceElevated,
                items: TipoBienDeUso.values.map((t) => DropdownMenuItem(
                  value: t,
                  child: Row(children: [
                    Text(t.emoji), const SizedBox(width: 8), Text(t.label),
                  ]),
                )).toList(),
                onChanged: (v) => setState(() => _tipo = v!),
              ),
              const SizedBox(height: AppSpacing.md),

              // Nombre
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre / Descripción'),
                textCapitalization: TextCapitalization.words,
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // Modelo + Año
              Row(children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _modeloCtrl,
                    decoration: const InputDecoration(labelText: 'Marca / Modelo'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _anioCtrl,
                    decoration: const InputDecoration(labelText: 'Año'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1900 || n > DateTime.now().year + 1) {
                        return 'Año inválido';
                      }
                      return null;
                    },
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.md),

              // Precio de compra + Moneda
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _precioCtrl,
                      decoration: InputDecoration(
                        labelText: 'Precio de compra',
                        prefixText: '${info.simbolo} ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
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
                      initialValue: _moneda,
                      decoration: const InputDecoration(labelText: 'Moneda'),
                      dropdownColor: AppColors.surfaceElevated,
                      isExpanded: true,
                      items: kMonedas.map((m) => DropdownMenuItem(
                        value: m.codigo,
                        child: Text('${m.codigo} ${m.simbolo}',
                            overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (v) => setState(() => _moneda = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Valor actual estimado
              TextFormField(
                controller: _valorEstCtrl,
                decoration: InputDecoration(
                  labelText: 'Valor actual estimado (opcional)',
                  prefixText: '${info.simbolo} ',
                  helperText: _fetchingPrecio
                      ? 'Buscando precio en MercadoLibre...'
                      : 'Ingresalo manualmente — se busca automáticamente',
                  helperStyle: TextStyle(
                      fontSize: 11,
                      color: _fetchingPrecio ? AppColors.warning : null),
                  suffixIcon: _fetchingPrecio
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: AppColors.warning),
                          ),
                        )
                      : null,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                icon: const Icon(Icons.search, size: 14),
                label: const Text('Buscar en web', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  final modelo = _modeloCtrl.text.trim();
                  final anio = _anioCtrl.text.trim();
                  if (modelo.isEmpty) return;
                  final query = Uri.encodeComponent('$modelo $anio precio Argentina');
                  final url = Uri.parse('https://www.google.com/search?q=$query');
                  launchUrl(url, mode: LaunchMode.externalApplication);
                },
              ),

              // Preview variación
              if (_valorEstCtrl.text.isNotEmpty && _precioCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 6),
                Builder(builder: (_) {
                  final val = double.tryParse(_valorEstCtrl.text.replaceAll(',', '.'));
                  final costo = double.tryParse(_precioCtrl.text.replaceAll(',', '.'));
                  if (val == null || costo == null || costo == 0) return const SizedBox.shrink();
                  final diff = val - costo;
                  final pct = diff / costo * 100;
                  final isPos = diff >= 0;
                  return Row(
                    children: [
                      Icon(
                        isPos ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 14,
                        color: isPos ? AppColors.success : AppColors.danger,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${isPos ? '+' : ''}${pct.toStringAsFixed(1)}% vs precio de compra',
                        style: TextStyle(
                          color: isPos ? AppColors.success : AppColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                }),
              ],
              const SizedBox(height: AppSpacing.md),

              // Fecha de compra
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined, color: AppColors.warning),
                title: Text(DateFormat('dd/MM/yyyy').format(_fechaCompra)),
                subtitle: const Text('Fecha de compra'),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _fechaCompra,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() => _fechaCompra = d);
                },
              ),
              const SizedBox(height: AppSpacing.md),

              TextFormField(
                controller: _notasCtrl,
                decoration: const InputDecoration(labelText: 'Notas (opcional)'),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.lg),

              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        _isEditing ? 'Guardar Cambios' : 'Agregar Bien',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
