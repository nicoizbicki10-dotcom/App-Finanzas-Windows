import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../market_data/providers/market_data_providers.dart';
import '../../data/currency_data.dart';
import '../../domain/inversion_models.dart';
import '../providers/inversiones_provider.dart';
import 'inversion_total_banner.dart';

class AlternativasTab extends ConsumerStatefulWidget {
  const AlternativasTab({super.key});

  @override
  ConsumerState<AlternativasTab> createState() => _AlternativasTabState();
}

enum _SortAlt {
  precioCompra('Precio de compra'),
  valorEstimado('Valor estimado'),
  variacion('Variación %');

  const _SortAlt(this.label);
  final String label;
}

class _AlternativasTabState extends ConsumerState<AlternativasTab> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  TipoAlternativa? _filterTipo;
  DateTime? _compraDesde;
  DateTime? _compraHasta;
  _SortAlt? _sort;
  bool _sortAsc = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    int c = 0;
    if (_filterTipo != null) c++;
    if (_compraDesde != null) c++;
    if (_compraHasta != null) c++;
    if (_sort != null) c++;
    return c;
  }

  List<InversionAlternativa> _apply(
      List<InversionAlternativa> source, double goldPerOz, double silverPerOz) {
    var list = source.where((a) {
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        if (!a.nombre.toLowerCase().contains(q) &&
            !a.tipo.label.toLowerCase().contains(q)) return false;
      }
      if (_filterTipo != null && a.tipo != _filterTipo) return false;
      if (_compraDesde != null && a.fechaCompra.isBefore(_compraDesde!)) return false;
      if (_compraHasta != null && a.fechaCompra.isAfter(_compraHasta!)) return false;
      return true;
    }).toList();

    if (_sort != null) {
      list.sort((a, b) {
        double va, vb;
        switch (_sort!) {
          case _SortAlt.precioCompra:
            va = a.precioCompra;
            vb = b.precioCompra;
          case _SortAlt.valorEstimado:
            va = a.valorEstimadoManual ??
                a.valorSpotUSD(goldPerOz: goldPerOz, silverPerOz: silverPerOz) ??
                a.precioCompra;
            vb = b.valorEstimadoManual ??
                b.valorSpotUSD(goldPerOz: goldPerOz, silverPerOz: silverPerOz) ??
                b.precioCompra;
          case _SortAlt.variacion:
            final spotA = a.valorSpotUSD(goldPerOz: goldPerOz, silverPerOz: silverPerOz);
            final valA = a.valorEstimadoManual ?? spotA ?? a.precioCompra;
            va = a.precioCompra > 0 ? (valA - a.precioCompra) / a.precioCompra * 100 : -9999;
            final spotB = b.valorSpotUSD(goldPerOz: goldPerOz, silverPerOz: silverPerOz);
            final valB = b.valorEstimadoManual ?? spotB ?? b.precioCompra;
            vb = b.precioCompra > 0 ? (valB - b.precioCompra) / b.precioCompra * 100 : -9999;
        }
        return _sortAsc ? va.compareTo(vb) : vb.compareTo(va);
      });
    }
    return list;
  }

  Future<void> _openFilters(BuildContext ctx) async {
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AltFilterSheet(
        initTipo: _filterTipo,
        initSort: _sort,
        initSortAsc: _sortAsc,
        initCompraDesde: _compraDesde,
        initCompraHasta: _compraHasta,
        onApply: (tipo, sort, sortAsc, compraDesde, compraHasta) => setState(() {
          _filterTipo = tipo;
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
    final alternativas = ref.watch(alternativasProvider);
    final goldPerOz = ref.watch(goldSpotPriceUSDProvider);
    final silverPerOz = ref.watch(silverSpotPriceUSDProvider);
    final filtered = _apply(alternativas, goldPerOz, silverPerOz);
    final totalAsync = ref.watch(valorAlternativasUSDProvider);
    final dolarVenta = ref.watch(dolarProvider).value
            ?.where((d) => d.casa.toLowerCase() == 'blue')
            .map((d) => d.venta)
            .firstOrNull ??
        1050.0;

    final varItemsAlt = alternativas.map((alt) {
      if (alt.valorEstimadoManual != null && alt.precioCompra > 0) {
        return (alt.valorEstimadoManual! - alt.precioCompra) / alt.precioCompra * 100;
      }
      final spotUSD = alt.valorSpotUSD(goldPerOz: goldPerOz, silverPerOz: silverPerOz);
      if (spotUSD != null && alt.precioCompra > 0 && alt.moneda == 'USD') {
        return (spotUSD - alt.precioCompra) / alt.precioCompra * 100;
      }
      return null;
    }).whereType<double>().toList();
    final avgVarAlt = varItemsAlt.isEmpty ? null : varItemsAlt.reduce((a, b) => a + b) / varItemsAlt.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InversionTotalBanner(
          totalUSD: totalAsync.value,
          dolarVenta: dolarVenta,
          seccionKey: 'Alternativas',
          variacionPromedio: avgVarAlt,
        ),

        Row(
          children: [
            if (alternativas.isNotEmpty)
              Text(
                '${alternativas.length} activo${alternativas.length == 1 ? '' : 's'}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            const Spacer(),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.tune,
                    color: _activeFilterCount > 0
                        ? AppColors.warning
                        : AppColors.textSecondary,
                  ),
                  tooltip: 'Filtros y orden',
                  onPressed: () => _openFilters(context),
                ),
                if (_activeFilterCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$_activeFilterCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                builder: (_) => const _AlternativaSheet(),
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

        if (alternativas.isNotEmpty) ...[
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o tipo...',
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () => setState(() {
                        _search = '';
                        _searchCtrl.clear();
                      }),
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],

        // Active filter chips
        if (_activeFilterCount > 0) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              if (_filterTipo != null)
                _ActiveChip(
                  label: '${_filterTipo!.emoji} ${_filterTipo!.label}',
                  onRemove: () => setState(() => _filterTipo = null),
                ),
              if (_compraDesde != null)
                _ActiveChip(
                  label: 'Desde ${DateFormat('dd/MM/yy').format(_compraDesde!)}',
                  onRemove: () => setState(() => _compraDesde = null),
                ),
              if (_compraHasta != null)
                _ActiveChip(
                  label: 'Hasta ${DateFormat('dd/MM/yy').format(_compraHasta!)}',
                  onRemove: () => setState(() => _compraHasta = null),
                ),
              if (_sort != null)
                _ActiveChip(
                  label: '${_sortAsc ? '↑' : '↓'} ${_sort!.label}',
                  onRemove: () => setState(() => _sort = null),
                ),
              TextButton(
                onPressed: () => setState(() {
                  _filterTipo = null;
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

        if (alternativas.isEmpty)
          Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.diamond_outlined, size: 40, color: AppColors.textDisabled),
              const SizedBox(height: 12),
              Text(
                'No hay inversiones alternativas registradas',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ]),
          )
        else if (filtered.isEmpty)
          Expanded(
            child: Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.search_off, size: 40, color: AppColors.textDisabled),
                const SizedBox(height: 12),
                const Text('Sin resultados', style: TextStyle(color: AppColors.textSecondary)),
                TextButton(
                  onPressed: () => setState(() {
                    _search = '';
                    _searchCtrl.clear();
                    _filterTipo = null;
                    _compraDesde = null;
                    _compraHasta = null;
                    _sort = null;
                  }),
                  child: const Text('Limpiar filtros'),
                ),
              ]),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) => _AlternativaCard(alt: filtered[i]),
            ),
          ),
      ],
    );
  }
}

// ─── Active filter chip ───────────────────────────────────────────────────────

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ActiveChip({required this.label, required this.onRemove});

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
                color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(width: 2),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.close, size: 13, color: AppColors.warning),
        ),
      ]),
    );
  }
}

// ─── Filter chip (inside sheet) ───────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

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
              color: selected ? AppColors.warning : AppColors.surfaceBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.warning : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ─── Filter sheet ─────────────────────────────────────────────────────────────

class _AltFilterSheet extends StatefulWidget {
  final TipoAlternativa? initTipo;
  final _SortAlt? initSort;
  final bool initSortAsc;
  final DateTime? initCompraDesde;
  final DateTime? initCompraHasta;
  final void Function(
    TipoAlternativa? tipo,
    _SortAlt? sort,
    bool sortAsc,
    DateTime? compraDesde,
    DateTime? compraHasta,
  ) onApply;

  const _AltFilterSheet({
    required this.initTipo,
    required this.initSort,
    required this.initSortAsc,
    required this.initCompraDesde,
    required this.initCompraHasta,
    required this.onApply,
  });

  @override
  State<_AltFilterSheet> createState() => _AltFilterSheetState();
}

class _AltFilterSheetState extends State<_AltFilterSheet> {
  TipoAlternativa? _tipo;
  _SortAlt? _sort;
  bool _sortAsc = false;
  DateTime? _compraDesde;
  DateTime? _compraHasta;

  @override
  void initState() {
    super.initState();
    _tipo = widget.initTipo;
    _sort = widget.initSort;
    _sortAsc = widget.initSortAsc;
    _compraDesde = widget.initCompraDesde;
    _compraHasta = widget.initCompraHasta;
  }

  void _clear() => setState(() {
        _tipo = null;
        _sort = null;
        _sortAsc = false;
        _compraDesde = null;
        _compraHasta = null;
      });

  void _apply() {
    widget.onApply(_tipo, _sort, _sortAsc, _compraDesde, _compraHasta);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: Text('Filtros y ordenar',
                    style: Theme.of(context).textTheme.headlineMedium),
              ),
              TextButton(
                onPressed: _clear,
                child: const Text('Limpiar',
                    style: TextStyle(color: AppColors.danger, fontSize: 13)),
              ),
            ]),
            const SizedBox(height: 20),

            // Tipo de activo
            _SectionLabel(label: 'Tipo de activo'),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _FilterChip(
                label: 'Todos',
                selected: _tipo == null,
                onTap: () => setState(() => _tipo = null),
              ),
              ...TipoAlternativa.values.map((t) => _FilterChip(
                    label: '${t.emoji} ${t.label}',
                    selected: _tipo == t,
                    onTap: () => setState(() => _tipo = _tipo == t ? null : t),
                  )),
            ]),
            const SizedBox(height: 20),

            // Rango de fecha de compra
            _SectionLabel(label: 'Rango de fecha de compra'),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month_outlined, size: 16),
                  label: Text(
                    _compraDesde != null ? fmt.format(_compraDesde!) : 'Desde',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _compraDesde != null
                        ? AppColors.warning
                        : AppColors.textSecondary,
                    side: BorderSide(
                      color: _compraDesde != null
                          ? AppColors.warning
                          : AppColors.surfaceBorder,
                    ),
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
                  label: Text(
                    _compraHasta != null ? fmt.format(_compraHasta!) : 'Hasta',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _compraHasta != null
                        ? AppColors.warning
                        : AppColors.textSecondary,
                    side: BorderSide(
                      color: _compraHasta != null
                          ? AppColors.warning
                          : AppColors.surfaceBorder,
                    ),
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
                  onPressed: () => setState(() {
                    _compraDesde = null;
                    _compraHasta = null;
                  }),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ]),
            const SizedBox(height: 20),

            // Ordenar por
            _SectionLabel(label: 'Ordenar por'),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _FilterChip(
                label: 'Sin ordenar',
                selected: _sort == null,
                onTap: () => setState(() => _sort = null),
              ),
              ..._SortAlt.values.map((s) => _FilterChip(
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
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('↓ Mayor primero'),
                  selected: !_sortAsc,
                  onSelected: (_) => setState(() => _sortAsc = false),
                  selectedColor: AppColors.warning.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: !_sortAsc ? AppColors.warning : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('↑ Menor primero'),
                  selected: _sortAsc,
                  onSelected: (_) => setState(() => _sortAsc = true),
                  selectedColor: AppColors.warning.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: _sortAsc ? AppColors.warning : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 28),

            ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Aplicar filtros',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

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

// ─── Card ─────────────────────────────────────────────────────────────────────

class _AlternativaCard extends ConsumerWidget {
  final InversionAlternativa alt;
  const _AlternativaCard({required this.alt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat('#,##0.##', 'es_AR');
    final fmtDate = DateFormat('dd/MM/yyyy');
    final info = monedaInfo(alt.moneda);

    final goldPerOz = ref.watch(goldSpotPriceUSDProvider);
    final silverPerOz = ref.watch(silverSpotPriceUSDProvider);
    final spotLoading = ref.watch(stockQuoteProvider('GC=F')).isLoading;

    final spotUSD = alt.valorSpotUSD(goldPerOz: goldPerOz, silverPerOz: silverPerOz);
    final precioCompraStr = '${info.simbolo} ${fmt.format(alt.precioCompra)}';

    // Variación: compara en la misma base
    double? variPct;
    if (alt.valorEstimadoManual != null && alt.precioCompra > 0) {
      variPct = (alt.valorEstimadoManual! - alt.precioCompra) / alt.precioCompra * 100;
    } else if (spotUSD != null && alt.precioCompra > 0 && alt.moneda == 'USD') {
      variPct = (spotUSD - alt.precioCompra) / alt.precioCompra * 100;
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(alt.tipo.emoji, style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alt.nombre, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      '${alt.tipo.label} · ${fmt.format(alt.cantidad)} ${alt.tipo.unidad}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
                color: AppColors.surfaceElevated,
                onSelected: (v) {
                  if (v == 'edit') {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _AlternativaSheet(alt: alt),
                    );
                  } else if (v == 'delete') {
                    ref.read(inversionesNotifierProvider.notifier).eliminarAlternativa(alt.id);
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

          _InfoRow(label: 'Precio de compra', value: precioCompraStr),
          const SizedBox(height: 6),
          _InfoRow(label: 'Fecha de compra', value: fmtDate.format(alt.fechaCompra)),
          const SizedBox(height: 6),

          // Valor actual
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Valor actual estimado',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              // Cargando spot (solo metales sin estimación manual)
              if (alt.tipo.esMetal && spotLoading && alt.valorEstimadoManual == null)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.warning),
                )
              // Estimación manual (cualquier tipo)
              else if (alt.valorEstimadoManual != null)
                Text(
                  '${info.simbolo} ${fmt.format(alt.valorEstimadoManual!)}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                )
              // Precio spot calculado para metales
              else if (spotUSD != null)
                Text(
                  'USD ${fmt.format(spotUSD)} (spot)',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                )
              // Metal sin precio spot disponible (API falló)
              else if (alt.tipo.esMetal)
                const Text(
                  'Sin precio spot',
                  style: TextStyle(color: AppColors.textDisabled, fontSize: 13),
                )
              // No-metal sin estimación
              else
                const Text(
                  '—',
                  style: TextStyle(color: AppColors.textDisabled, fontSize: 13),
                ),
            ],
          ),

          // Precio spot por gramo para metales
          if (alt.tipo.esOro && goldPerOz > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Spot: USD ${fmt.format(goldPerOz / 31.1035 * alt.tipo.pureza)}/g (${alt.tipo.label})',
              style: const TextStyle(color: AppColors.textDisabled, fontSize: 10),
            ),
          ],
          if (alt.tipo.esPlata && silverPerOz > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Spot: USD ${fmt.format(silverPerOz / 31.1035)}/g',
              style: const TextStyle(color: AppColors.textDisabled, fontSize: 10),
            ),
          ],

          // Variación
          if (variPct != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Variación vs compra',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                Row(children: [
                  Icon(
                    variPct >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 14,
                    color: variPct >= 0 ? AppColors.success : AppColors.danger,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${variPct >= 0 ? '+' : ''}${variPct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: variPct >= 0 ? AppColors.success : AppColors.danger,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ]),
              ],
            ),
          ],

          if (alt.notas != null && alt.notas!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              alt.notas!,
              style: const TextStyle(color: AppColors.textDisabled, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}

// ─── Sheet ────────────────────────────────────────────────────────────────────

class _AlternativaSheet extends ConsumerStatefulWidget {
  final InversionAlternativa? alt;
  const _AlternativaSheet({this.alt});

  @override
  ConsumerState<_AlternativaSheet> createState() => _AlternativaSheetState();
}

class _AlternativaSheetState extends ConsumerState<_AlternativaSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _valorEstCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  TipoAlternativa _tipo = TipoAlternativa.oro18k;
  String _moneda = 'USD';
  DateTime _fechaCompra = DateTime.now();
  bool _saving = false;
  bool _fetchingSpot = false;

  bool get _isEditing => widget.alt != null;

  @override
  void initState() {
    super.initState();
    final a = widget.alt;
    if (a != null) {
      _nombreCtrl.text = a.nombre;
      _cantidadCtrl.text = a.cantidad.toString();
      _precioCtrl.text = a.precioCompra.toString();
      if (a.valorEstimadoManual != null) {
        _valorEstCtrl.text = a.valorEstimadoManual.toString();
      }
      _notasCtrl.text = a.notas ?? '';
      _tipo = a.tipo;
      _moneda = a.moneda;
      _fechaCompra = a.fechaCompra;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _cantidadCtrl.dispose();
    _precioCtrl.dispose();
    _valorEstCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSpotPrice() async {
    setState(() => _fetchingSpot = true);
    try {
      // Leer el precio actual del stream de Yahoo Finance (GC=F / SI=F)
      final goldPerOz = ref.read(goldSpotPriceUSDProvider);
      final silverPerOz = ref.read(silverSpotPriceUSDProvider);
      final cantidad = double.tryParse(_cantidadCtrl.text.replaceAll(',', '.')) ?? 0.0;

      double? valorCalc;
      if (_tipo.esOro && goldPerOz > 0 && cantidad > 0) {
        valorCalc = cantidad * (goldPerOz / 31.1035) * _tipo.pureza;
      } else if (_tipo.esPlata && silverPerOz > 0 && cantidad > 0) {
        valorCalc = cantidad * (silverPerOz / 31.1035);
      }

      if (mounted) {
        setState(() {
          _fetchingSpot = false;
          if (valorCalc != null) {
            _valorEstCtrl.text = valorCalc.toStringAsFixed(2);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _fetchingSpot = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final alt = InversionAlternativa(
      id: widget.alt?.id,
      tipo: _tipo,
      nombre: _nombreCtrl.text.trim(),
      cantidad: double.tryParse(_cantidadCtrl.text.replaceAll(',', '.')) ?? 1.0,
      precioCompra: double.tryParse(_precioCtrl.text.replaceAll(',', '.')) ?? 0.0,
      moneda: _moneda,
      fechaCompra: _fechaCompra,
      valorEstimadoManual: _valorEstCtrl.text.isNotEmpty
          ? double.tryParse(_valorEstCtrl.text.replaceAll(',', '.'))
          : null,
      notas: _notasCtrl.text.trim().isNotEmpty ? _notasCtrl.text.trim() : null,
    );

    await ref.read(inversionesNotifierProvider.notifier).agregarAlternativa(alt);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final info = monedaInfo(_moneda);
    final goldPerOz = ref.watch(goldSpotPriceUSDProvider);
    final silverPerOz = ref.watch(silverSpotPriceUSDProvider);
    final cantidad = double.tryParse(_cantidadCtrl.text.replaceAll(',', '.')) ?? 0.0;

    double? spotValorCalc;
    if (_tipo.esOro && goldPerOz > 0 && cantidad > 0) {
      spotValorCalc = cantidad * (goldPerOz / 31.1035) * _tipo.pureza;
    } else if (_tipo.esPlata && silverPerOz > 0 && cantidad > 0) {
      spotValorCalc = cantidad * (silverPerOz / 31.1035);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _isEditing ? 'Editar Inversión Alternativa' : 'Agregar Inversión Alternativa',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Tipo
              DropdownButtonFormField<TipoAlternativa>(
                value: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo de activo'),
                dropdownColor: AppColors.surfaceElevated,
                items: TipoAlternativa.values.map((t) => DropdownMenuItem(
                  value: t,
                  child: Row(children: [
                    Text(t.emoji),
                    const SizedBox(width: 8),
                    Text(t.label),
                  ]),
                )).toList(),
                onChanged: (v) => setState(() {
                  _tipo = v!;
                  _valorEstCtrl.clear();
                }),
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

              // Cantidad
              TextFormField(
                controller: _cantidadCtrl,
                decoration: InputDecoration(
                  labelText: _tipo.esMetal ? 'Cantidad (gramos)' : 'Cantidad (unidades)',
                  suffixText: _tipo.unidad,
                  helperText: _tipo.esOro
                      ? 'Peso en gramos del metal (pureza: ${(_tipo.pureza * 100).toStringAsFixed(0)}%)'
                      : _tipo.esPlata
                          ? 'Peso en gramos de la plata'
                          : null,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Inválido';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Info spot price para metales
              if (_tipo.esMetal) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.trending_up, size: 16, color: AppColors.warning),
                          const SizedBox(width: 6),
                          const Text(
                            'Precio spot en tiempo real',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (ref.watch(stockQuoteProvider('GC=F')).isLoading)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.warning),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (_tipo.esOro && goldPerOz > 0) ...[
                        Text(
                          'Oro 24K: USD ${(goldPerOz / 31.1035).toStringAsFixed(2)}/g',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        if (_tipo != TipoAlternativa.oro24k)
                          Text(
                            '${_tipo.label}: USD ${(goldPerOz / 31.1035 * _tipo.pureza).toStringAsFixed(2)}/g',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        if (spotValorCalc != null)
                          Text(
                            'Valor de $cantidad ${_tipo.unidad}: USD ${spotValorCalc.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ] else if (_tipo.esPlata && silverPerOz > 0) ...[
                        Text(
                          'Plata: USD ${(silverPerOz / 31.1035).toStringAsFixed(2)}/g',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        if (spotValorCalc != null)
                          Text(
                            'Valor de $cantidad ${_tipo.unidad}: USD ${spotValorCalc.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ] else
                        const Text(
                          'Conectando con metals.live...',
                          style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Precio de compra + Moneda
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _precioCtrl,
                      decoration: InputDecoration(
                        labelText: 'Precio de compra (total)',
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
                      value: _moneda,
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

              // Valor estimado manual
              TextFormField(
                controller: _valorEstCtrl,
                decoration: InputDecoration(
                  labelText: 'Valor actual estimado (opcional)',
                  prefixText: '${info.simbolo} ',
                  helperText: _tipo.esMetal
                      ? 'Dejá vacío para usar el precio spot automáticamente'
                      : 'Si no se ingresa, se usa el precio de compra como referencia',
                  helperStyle: const TextStyle(fontSize: 11),
                  suffixIcon: _fetchingSpot
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

              // Botón "Usar precio spot" para metales
              if (_tipo.esMetal) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: const Text('Guardar precio spot como valor estimado',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _fetchingSpot ? null : _fetchSpotPrice,
                ),
              ],

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
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _isEditing ? 'Guardar Cambios' : 'Agregar Inversión',
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
