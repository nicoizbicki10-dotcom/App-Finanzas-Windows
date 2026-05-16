import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/percentage_badge.dart';
import '../../../market_data/data/precios_barrios.dart';
import '../../../market_data/providers/market_data_providers.dart';
import '../../data/currency_data.dart';
import '../../domain/inversion_models.dart';
import '../providers/inversiones_provider.dart';
import 'inversion_total_banner.dart';

// ─── Sort enum ─────────────────────────────────────────────────────────────

enum _SortInmueble {
  valorEstimado('Valor estimado'),
  costoCompra('Costo de compra'),
  variacion('Variación %'),
  superficie('Superficie m²');

  const _SortInmueble(this.label);
  final String label;
}

// ─── Helpers ───────────────────────────────────────────────────────────────

String _slugify(String text) {
  const accents = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'ñ': 'n', 'ç': 'c',
  };
  var s = text.toLowerCase();
  accents.forEach((k, v) => s = s.replaceAll(k, v));
  return s
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

double? _valorMercado(Inmueble i) {
  if (i.valorEstimadoUSD > 0) return i.valorEstimadoUSD;
  final p = i.barrio != null && i.barrio!.isNotEmpty
      ? PreciosBarrios.getPrecioM2(i.barrio!)
      : null;
  return p != null ? i.superficieM2 * p : null;
}

double? _variacionPct(Inmueble i) {
  final v = _valorMercado(i);
  if (v == null || i.costoOriginalUSD <= 0) return null;
  return (v - i.costoOriginalUSD) / i.costoOriginalUSD * 100;
}

// ─── Tab ───────────────────────────────────────────────────────────────────

class InmueblesTab extends ConsumerStatefulWidget {
  const InmueblesTab({super.key});

  @override
  ConsumerState<InmueblesTab> createState() => _InmueblesTabState();
}

class _InmueblesTabState extends ConsumerState<InmueblesTab> {
  final _nombreCtrl = TextEditingController();

  String _searchNombre = '';
  String _searchUbic = '';
  EstadoInmueble? _filterEstado;
  int? _filterAmbientes;
  int? _anioDesde;
  int? _anioHasta;
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  _SortInmueble? _sort;
  bool _sortAsc = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    int c = 0;
    if (_searchUbic.isNotEmpty) c++;
    if (_filterEstado != null) c++;
    if (_filterAmbientes != null) c++;
    if (_anioDesde != null || _anioHasta != null) c++;
    if (_fechaDesde != null || _fechaHasta != null) c++;
    if (_sort != null) c++;
    return c;
  }

  List<Inmueble> _apply(List<Inmueble> source) {
    var list = source.where((i) {
      if (_searchNombre.isNotEmpty &&
          !i.nombre.toLowerCase().contains(_searchNombre.toLowerCase())) return false;
      if (_searchUbic.isNotEmpty) {
        final q = _searchUbic.toLowerCase();
        if (!(i.direccion.toLowerCase().contains(q) ||
            (i.barrio?.toLowerCase().contains(q) ?? false))) return false;
      }
      if (_filterEstado != null && i.estadoInmueble != _filterEstado) return false;
      if (_filterAmbientes != null && i.ambientes != _filterAmbientes) return false;
      if (_anioDesde != null &&
          (i.anioConstru == null || i.anioConstru! < _anioDesde!)) return false;
      if (_anioHasta != null &&
          (i.anioConstru == null || i.anioConstru! > _anioHasta!)) return false;
      if (_fechaDesde != null && i.fechaAdquisicion.isBefore(_fechaDesde!)) return false;
      if (_fechaHasta != null &&
          i.fechaAdquisicion.isAfter(_fechaHasta!.add(const Duration(days: 1)))) return false;
      return true;
    }).toList();

    if (_sort != null) {
      list.sort((a, b) {
        final double va, vb;
        switch (_sort!) {
          case _SortInmueble.valorEstimado:
            va = _valorMercado(a) ?? 0;
            vb = _valorMercado(b) ?? 0;
          case _SortInmueble.costoCompra:
            va = a.costoOriginalUSD;
            vb = b.costoOriginalUSD;
          case _SortInmueble.variacion:
            va = _variacionPct(a) ?? -9999;
            vb = _variacionPct(b) ?? -9999;
          case _SortInmueble.superficie:
            va = a.superficieM2;
            vb = b.superficieM2;
        }
        return _sortAsc ? va.compareTo(vb) : vb.compareTo(va);
      });
    }
    return list;
  }

  void _clearAll() => setState(() {
        _searchNombre = '';
        _nombreCtrl.clear();
        _searchUbic = '';
        _filterEstado = null;
        _filterAmbientes = null;
        _anioDesde = null;
        _anioHasta = null;
        _fechaDesde = null;
        _fechaHasta = null;
        _sort = null;
      });

  Future<void> _openFilters(BuildContext ctx) async {
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InmuebleFilterSheet(
        initUbic: _searchUbic,
        initEstado: _filterEstado,
        initAmbientes: _filterAmbientes,
        initAnioDesde: _anioDesde,
        initAnioHasta: _anioHasta,
        initFechaDesde: _fechaDesde,
        initFechaHasta: _fechaHasta,
        initSort: _sort,
        initSortAsc: _sortAsc,
        onApply: (ubic, estado, amb, anioD, anioH, fechaD, fechaH, sort, sortAsc) =>
            setState(() {
              _searchUbic = ubic;
              _filterEstado = estado;
              _filterAmbientes = amb;
              _anioDesde = anioD;
              _anioHasta = anioH;
              _fechaDesde = fechaD;
              _fechaHasta = fechaH;
              _sort = sort;
              _sortAsc = sortAsc;
            }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inmuebles = ref.watch(inmueblesProvider);
    final filtered = _apply(inmuebles);
    final totalAsync = ref.watch(valorInmueblesUSDProvider);
    final dolarVenta = ref.watch(dolarProvider).value
            ?.where((d) => d.casa.toLowerCase() == 'blue')
            .map((d) => d.venta)
            .firstOrNull ??
        1050.0;

    final varItemsInm = inmuebles.map(_variacionPct).whereType<double>().toList();
    final avgVarInm = varItemsInm.isEmpty ? null : varItemsInm.reduce((a, b) => a + b) / varItemsInm.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InversionTotalBanner(
          totalUSD: totalAsync.value,
          dolarVenta: dolarVenta,
          seccionKey: 'Inmuebles',
          variacionPromedio: avgVarInm,
        ),
        // ── Top bar ──────────────────────────────────────────────────────
        Row(children: [
          Expanded(
            child: TextField(
              controller: _nombreCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre...',
                prefixIcon:
                    const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                suffixIcon: _searchNombre.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () =>
                            setState(() {
                              _searchNombre = '';
                              _nombreCtrl.clear();
                            }),
                      )
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
              onChanged: (v) => setState(() => _searchNombre = v),
            ),
          ),
          const SizedBox(width: 8),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: Icon(Icons.tune,
                    color: _activeFilterCount > 0
                        ? AppColors.primary
                        : AppColors.textSecondary),
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
                        color: AppColors.primary, shape: BoxShape.circle),
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
              builder: (_) => const _InmuebleSheet(),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Agregar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ]),
        const SizedBox(height: 4),

        // ── Active filter chips ──────────────────────────────────────────
        if (_activeFilterCount > 0) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              if (_searchUbic.isNotEmpty)
                _ActiveChip(
                    label: '📍 $_searchUbic',
                    onRemove: () => setState(() => _searchUbic = '')),
              if (_filterEstado != null)
                _ActiveChip(
                    label: '${_filterEstado!.emoji} ${_filterEstado!.label}',
                    onRemove: () => setState(() => _filterEstado = null)),
              if (_filterAmbientes != null)
                _ActiveChip(
                    label: _filterAmbientes == 1
                        ? 'Monoambiente'
                        : '$_filterAmbientes amb.',
                    onRemove: () => setState(() => _filterAmbientes = null)),
              if (_anioDesde != null || _anioHasta != null)
                _ActiveChip(
                    label: 'Año: ${_anioDesde ?? '?'}–${_anioHasta ?? '?'}',
                    onRemove: () =>
                        setState(() {
                          _anioDesde = null;
                          _anioHasta = null;
                        })),
              if (_fechaDesde != null || _fechaHasta != null)
                _ActiveChip(
                    label:
                        'Compra: ${_fechaDesde != null ? DateFormat('MM/yy').format(_fechaDesde!) : '?'}–${_fechaHasta != null ? DateFormat('MM/yy').format(_fechaHasta!) : '?'}',
                    onRemove: () =>
                        setState(() {
                          _fechaDesde = null;
                          _fechaHasta = null;
                        })),
              if (_sort != null)
                _ActiveChip(
                    label: '${_sortAsc ? '↑' : '↓'} ${_sort!.label}',
                    onRemove: () => setState(() => _sort = null)),
              TextButton(
                onPressed: _clearAll,
                child: const Text('Limpiar todo',
                    style: TextStyle(fontSize: 11, color: AppColors.danger)),
              ),
            ]),
          ),
          const SizedBox(height: 4),
        ],

        // ── Results count ────────────────────────────────────────────────
        if (inmuebles.isNotEmpty && _activeFilterCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('${filtered.length} de ${inmuebles.length} propiedades',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
          ),

        // ── List ─────────────────────────────────────────────────────────
        if (inmuebles.isEmpty)
          Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.home_outlined,
                  size: 40, color: AppColors.textDisabled),
              const SizedBox(height: 12),
              Text('No tenés inmuebles registrados',
                  style: Theme.of(context).textTheme.bodyMedium),
            ]),
          )
        else if (filtered.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search_off,
                        size: 40, color: AppColors.textDisabled),
                    const SizedBox(height: 12),
                    const Text('Sin resultados para los filtros aplicados',
                        style: TextStyle(color: AppColors.textSecondary)),
                    TextButton(
                        onPressed: _clearAll,
                        child: const Text('Limpiar filtros')),
                  ]),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) => _InmuebleCard(inmueble: filtered[i]),
            ),
          ),
      ],
    );
  }
}

// ─── Filter sheet ──────────────────────────────────────────────────────────

class _InmuebleFilterSheet extends StatefulWidget {
  final String initUbic;
  final EstadoInmueble? initEstado;
  final int? initAmbientes;
  final int? initAnioDesde;
  final int? initAnioHasta;
  final DateTime? initFechaDesde;
  final DateTime? initFechaHasta;
  final _SortInmueble? initSort;
  final bool initSortAsc;
  final void Function(
    String ubic,
    EstadoInmueble? estado,
    int? ambientes,
    int? anioDesde,
    int? anioHasta,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    _SortInmueble? sort,
    bool sortAsc,
  ) onApply;

  const _InmuebleFilterSheet({
    required this.initUbic,
    required this.initEstado,
    required this.initAmbientes,
    required this.initAnioDesde,
    required this.initAnioHasta,
    required this.initFechaDesde,
    required this.initFechaHasta,
    required this.initSort,
    required this.initSortAsc,
    required this.onApply,
  });

  @override
  State<_InmuebleFilterSheet> createState() => _InmuebleFilterSheetState();
}

class _InmuebleFilterSheetState extends State<_InmuebleFilterSheet> {
  late final TextEditingController _ubicCtrl;
  late final TextEditingController _anioDesdeCtrl;
  late final TextEditingController _anioHastaCtrl;
  EstadoInmueble? _estado;
  int? _ambientes;
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  _SortInmueble? _sort;
  bool _sortAsc = false;

  @override
  void initState() {
    super.initState();
    _ubicCtrl = TextEditingController(text: widget.initUbic);
    _anioDesdeCtrl =
        TextEditingController(text: widget.initAnioDesde?.toString() ?? '');
    _anioHastaCtrl =
        TextEditingController(text: widget.initAnioHasta?.toString() ?? '');
    _estado = widget.initEstado;
    _ambientes = widget.initAmbientes;
    _fechaDesde = widget.initFechaDesde;
    _fechaHasta = widget.initFechaHasta;
    _sort = widget.initSort;
    _sortAsc = widget.initSortAsc;
  }

  @override
  void dispose() {
    _ubicCtrl.dispose();
    _anioDesdeCtrl.dispose();
    _anioHastaCtrl.dispose();
    super.dispose();
  }

  void _clear() => setState(() {
        _ubicCtrl.clear();
        _anioDesdeCtrl.clear();
        _anioHastaCtrl.clear();
        _estado = null;
        _ambientes = null;
        _fechaDesde = null;
        _fechaHasta = null;
        _sort = null;
        _sortAsc = false;
      });

  void _apply() {
    widget.onApply(
      _ubicCtrl.text.trim(),
      _estado,
      _ambientes,
      int.tryParse(_anioDesdeCtrl.text.trim()),
      int.tryParse(_anioHastaCtrl.text.trim()),
      _fechaDesde,
      _fechaHasta,
      _sort,
      _sortAsc,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.97,
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

            // ── Ubicación ─────────────────────────────────────────────
            const _SectionLabel(label: 'Buscar por ubicación'),
            TextField(
              controller: _ubicCtrl,
              decoration: const InputDecoration(
                hintText: 'Dirección, barrio, localidad...',
                prefixIcon:
                    Icon(Icons.location_on_outlined, size: 18),
                isDense: true,
              ),
            ),
            const SizedBox(height: 20),

            // ── Estado ────────────────────────────────────────────────
            const _SectionLabel(label: 'Estado del inmueble'),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _FilterChip2(
                  label: 'Todos',
                  selected: _estado == null,
                  onTap: () => setState(() => _estado = null)),
              ...EstadoInmueble.values.map((e) => _FilterChip2(
                    label: '${e.emoji} ${e.label}',
                    selected: _estado == e,
                    onTap: () =>
                        setState(() => _estado = _estado == e ? null : e),
                  )),
            ]),
            const SizedBox(height: 20),

            // ── Ambientes ─────────────────────────────────────────────
            const _SectionLabel(label: 'Cantidad de ambientes'),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _FilterChip2(
                  label: 'Todos',
                  selected: _ambientes == null,
                  onTap: () => setState(() => _ambientes = null)),
              ...List.generate(6, (i) => i + 1).map((n) => _FilterChip2(
                    label: n == 1 ? 'Mono' : '$n amb.',
                    selected: _ambientes == n,
                    onTap: () => setState(
                        () => _ambientes = _ambientes == n ? null : n),
                  )),
            ]),
            const SizedBox(height: 20),

            // ── Año construcción ─────────────────────────────────────
            const _SectionLabel(label: 'Año de construcción'),
            Row(children: [
              Expanded(
                  child: TextField(
                controller: _anioDesdeCtrl,
                decoration: const InputDecoration(
                    labelText: 'Desde',
                    hintText: '1990',
                    isDense: true),
                keyboardType: TextInputType.number,
              )),
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('–',
                      style: TextStyle(color: AppColors.textSecondary))),
              Expanded(
                  child: TextField(
                controller: _anioHastaCtrl,
                decoration: const InputDecoration(
                    labelText: 'Hasta',
                    hintText: '2026',
                    isDense: true),
                keyboardType: TextInputType.number,
              )),
            ]),
            const SizedBox(height: 20),

            // ── Fecha de compra ───────────────────────────────────────
            const _SectionLabel(label: 'Fecha de compra'),
            Row(children: [
              Expanded(
                  child: _DateButton(
                label: 'Desde',
                date: _fechaDesde,
                onTap: () async {
                  final d = await showDatePicker(
                      context: context,
                      initialDate: _fechaDesde ?? DateTime(2020),
                      firstDate: DateTime(1980),
                      lastDate: DateTime.now());
                  if (d != null) setState(() => _fechaDesde = d);
                },
                onClear: _fechaDesde != null
                    ? () => setState(() => _fechaDesde = null)
                    : null,
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _DateButton(
                label: 'Hasta',
                date: _fechaHasta,
                onTap: () async {
                  final d = await showDatePicker(
                      context: context,
                      initialDate: _fechaHasta ?? DateTime.now(),
                      firstDate: DateTime(1980),
                      lastDate: DateTime.now());
                  if (d != null) setState(() => _fechaHasta = d);
                },
                onClear: _fechaHasta != null
                    ? () => setState(() => _fechaHasta = null)
                    : null,
              )),
            ]),
            const SizedBox(height: 20),

            // ── Ordenar por ───────────────────────────────────────────
            const _SectionLabel(label: 'Ordenar por'),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _FilterChip2(
                  label: 'Sin ordenar',
                  selected: _sort == null,
                  onTap: () => setState(() => _sort = null)),
              ..._SortInmueble.values.map((s) => _FilterChip2(
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
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  labelStyle: TextStyle(
                      color:
                          !_sortAsc ? AppColors.primary : AppColors.textSecondary,
                      fontSize: 12),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('↑ Menor primero'),
                  selected: _sortAsc,
                  onSelected: (_) => setState(() => _sortAsc = true),
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  labelStyle: TextStyle(
                      color:
                          _sortAsc ? AppColors.primary : AppColors.textSecondary,
                      fontSize: 12),
                ),
              ]),
            ],
            const SizedBox(height: 28),

            ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Aplicar filtros',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Card ──────────────────────────────────────────────────────────────────

class _InmuebleCard extends ConsumerWidget {
  final Inmueble inmueble;
  const _InmuebleCard({required this.inmueble});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final precioM2Tabla = inmueble.barrio != null && inmueble.barrio!.isNotEmpty
        ? PreciosBarrios.getPrecioM2(inmueble.barrio!)
        : null;
    final valorTabla =
        precioM2Tabla != null ? inmueble.superficieM2 * precioM2Tabla : null;
    final variacionAnualPct =
        inmueble.barrio != null && inmueble.barrio!.isNotEmpty
            ? PreciosBarrios.getVariacionAnualPct(inmueble.barrio!)
            : null;

    final valorMercado = inmueble.valorEstimadoUSD > 0
        ? inmueble.valorEstimadoUSD
        : valorTabla;
    final esDeTabla = inmueble.valorEstimadoUSD <= 0 && valorTabla != null;

    // Variación entre costo de compra y valor actual de mercado
    final variacionVsCompra = valorMercado != null && inmueble.costoOriginalUSD > 0
        ? (valorMercado - inmueble.costoOriginalUSD) / inmueble.costoOriginalUSD * 100
        : null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.home, color: AppColors.secondary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(inmueble.nombre,
                      style: Theme.of(context).textTheme.titleMedium),
                  GestureDetector(
                    onTap: () async {
                      final query = Uri.encodeComponent(
                          '${inmueble.direccion}${inmueble.barrio != null ? ', ${inmueble.barrio}' : ''}');
                      final uri = Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=$query');
                      if (await canLaunchUrl(uri)) launchUrl(uri);
                    },
                    child: Row(children: [
                      Flexible(
                        child: Text(inmueble.direccion,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.primary,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.primary,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.open_in_new,
                          size: 10, color: AppColors.primary),
                    ]),
                  ),
                  if (inmueble.barrio != null && inmueble.barrio!.isNotEmpty)
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 11, color: AppColors.textSecondary),
                      const SizedBox(width: 2),
                      Text(inmueble.barrio!,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11)),
                    ]),
                  if (inmueble.parteIndivisaPct < 100)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Parte indivisa: ${inmueble.parteIndivisaPct.toStringAsFixed(0)}%',
                        style: const TextStyle(
                            color: AppColors.warning,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (inmueble.ambientes != null ||
                      inmueble.anioConstru != null ||
                      inmueble.estadoInmueble != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(spacing: 4, runSpacing: 2, children: [
                        if (inmueble.ambientes != null)
                          _MiniChip(
                            label: inmueble.ambientes == 1
                                ? 'Monoambiente'
                                : '${inmueble.ambientes} amb.',
                            color: AppColors.textSecondary,
                          ),
                        if (inmueble.anioConstru != null)
                          _MiniChip(
                            label: '${inmueble.anioConstru}',
                            color: AppColors.textSecondary,
                          ),
                        if (inmueble.estadoInmueble != null)
                          _MiniChip(
                            label:
                                '${inmueble.estadoInmueble!.emoji} ${inmueble.estadoInmueble!.label}',
                            color: inmueble.estadoInmueble ==
                                    EstadoInmueble.finalizado
                                ? AppColors.success
                                : AppColors.secondary,
                          ),
                      ]),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 18, color: AppColors.textSecondary),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _InmuebleSheet(inmueble: inmueble),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: AppColors.textDisabled),
              onPressed: () => ref
                  .read(inversionesNotifierProvider.notifier)
                  .eliminarInmueble(inmueble.id),
            ),
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.surfaceBorder),
          const SizedBox(height: 12),

          // Valor de mercado banner
          if (valorMercado != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.trending_up, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Valor de mercado: ${CurrencyFormatter.usd(valorMercado)}',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                      Row(children: [
                        Expanded(
                          child: Text(
                            esDeTabla
                                ? 'USD ${precioM2Tabla!.toStringAsFixed(0)}/m² · Tabla ${PreciosBarrios.ultimaActualizacion}'
                                : 'Valor ingresado manualmente',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 10),
                          ),
                        ),
                        if (variacionAnualPct != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: variacionAnualPct >= 0
                                  ? AppColors.success.withOpacity(0.12)
                                  : AppColors.danger.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${variacionAnualPct >= 0 ? '+' : ''}${variacionAnualPct.toStringAsFixed(1)}% YoY',
                              style: TextStyle(
                                color: variacionAnualPct >= 0
                                    ? AppColors.success
                                    : AppColors.danger,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ]),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),
          ] else if (inmueble.barrio != null &&
              inmueble.barrio!.isNotEmpty) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline,
                    size: 14, color: AppColors.textDisabled),
                SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'Barrio sin datos en tabla — ingresá el valor manualmente',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11))),
              ]),
            ),
            const SizedBox(height: 10),
          ],

          // Info row: costo original | variación vs compra | superficie
          Row(children: [
            Expanded(
              child: _InfoItem(
                  label: 'Costo Original',
                  value: CurrencyFormatter.usd(inmueble.costoOriginalUSD)),
            ),
            Expanded(child: _VariacionItem(pct: variacionVsCompra)),
            Expanded(
              child: _InfoItem(
                  label: 'Superficie',
                  value: '${inmueble.superficieM2.toStringAsFixed(0)} m²'),
            ),
          ]),

          if (inmueble.alquilerMensualUSD != null) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.payments_outlined,
                    size: 14, color: AppColors.success),
                const SizedBox(width: 6),
                Text(
                  'Alquiler: ${CurrencyFormatter.usd(inmueble.alquilerMensualUSD!)} / mes',
                  style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ]),
            ),
          ],
          if (inmueble.barrio != null && inmueble.barrio!.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                final slug = _slugify(inmueble.barrio!);
                final amb = inmueble.ambientes;
                final url = amb != null
                    ? Uri.parse(
                        'https://www.zonaprop.com.ar/departamentos-venta-$slug-$amb-ambientes.html')
                    : Uri.parse(
                        'https://www.zonaprop.com.ar/departamentos-venta-$slug.html');
                launchUrl(url, mode: LaunchMode.externalApplication);
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.open_in_new, size: 11, color: AppColors.textSecondary),
                  SizedBox(width: 4),
                  Text(
                    'Ver similares en ZonaProp',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Shared small widgets ──────────────────────────────────────────────────

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
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
        const SizedBox(width: 2),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.close, size: 13, color: AppColors.primary),
        ),
      ]),
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

class _FilterChip2 extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip2(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.15)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.surfaceBorder),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _DateButton(
      {required this.label,
      required this.date,
      required this.onTap,
      this.onClear});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: date != null
              ? AppColors.primary.withOpacity(0.08)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: date != null ? AppColors.primary : AppColors.surfaceBorder),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary)),
              Text(
                date != null
                    ? DateFormat('dd/MM/yyyy').format(date!)
                    : 'Seleccionar',
                style: TextStyle(
                    fontSize: 12,
                    color: date != null
                        ? AppColors.primary
                        : AppColors.textDisabled,
                    fontWeight: date != null ? FontWeight.w500 : FontWeight.normal),
              ),
            ]),
          ),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.clear, size: 14, color: AppColors.textDisabled),
            )
          else
            const Icon(Icons.calendar_today_outlined,
                size: 14, color: AppColors.textDisabled),
        ]),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  const _InfoItem({required this.label, required this.value, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10)),
        Text(value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12)),
        if (subtitle != null)
          Text(subtitle!,
              style: const TextStyle(
                  color: AppColors.textDisabled, fontSize: 9)),
      ],
    );
  }
}

class _VariacionItem extends StatelessWidget {
  final double? pct;
  const _VariacionItem({this.pct});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Var. vs compra',
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10)),
        if (pct == null)
          const Text('—',
              style: TextStyle(
                  color: AppColors.textDisabled,
                  fontSize: 12,
                  fontWeight: FontWeight.w600))
        else
          Row(children: [
            Icon(
              pct! >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
              size: 11,
              color: pct! >= 0 ? AppColors.success : AppColors.danger,
            ),
            Text(
              '${pct! >= 0 ? '+' : ''}${pct!.toStringAsFixed(1)}%',
              style: TextStyle(
                  color: pct! >= 0 ? AppColors.success : AppColors.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
          ]),
      ],
    );
  }
}

// ─── Form sheet ────────────────────────────────────────────────────────────

class _InmuebleSheet extends ConsumerStatefulWidget {
  final Inmueble? inmueble;
  const _InmuebleSheet({this.inmueble});

  @override
  ConsumerState<_InmuebleSheet> createState() => _InmuebleSheetState();
}

class _InmuebleSheetState extends ConsumerState<_InmuebleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _barrioCtrl = TextEditingController();
  final _costoCtrl = TextEditingController();
  final _valorUSDCtrl = TextEditingController();
  final _m2Ctrl = TextEditingController();
  final _alquilerCtrl = TextEditingController();
  final _parteIndivisaCtrl = TextEditingController(text: '100');
  final _anioConstrCtrl = TextEditingController();
  String _alquilerMoneda = 'USD';
  FormaCobroAlquiler _alquilerFormaCobro = FormaCobroAlquiler.efectivo;
  int? _ambientes;
  EstadoInmueble? _estadoInmueble;
  DateTime _fecha = DateTime.now();
  bool _saving = false;

  bool get _isEditing => widget.inmueble != null;

  @override
  void initState() {
    super.initState();
    final i = widget.inmueble;
    if (i != null) {
      _nombreCtrl.text = i.nombre;
      _direccionCtrl.text = i.direccion;
      _barrioCtrl.text = i.barrio ?? '';
      _costoCtrl.text = i.costoOriginalUSD.toString();
      if (i.valorEstimadoUSD > 0 && i.superficieM2 > 0) {
        _valorUSDCtrl.text =
            (i.valorEstimadoUSD / i.superficieM2).toStringAsFixed(0);
      }
      _m2Ctrl.text = i.superficieM2.toStringAsFixed(0);
      if (i.alquilerMensualUSD != null)
        _alquilerCtrl.text = i.alquilerMensualUSD.toString();
      _alquilerMoneda = i.alquilerMoneda;
      if (i.alquilerFormaCobro != null)
        _alquilerFormaCobro = i.alquilerFormaCobro!;
      _parteIndivisaCtrl.text = i.parteIndivisaPct.toStringAsFixed(0);
      _ambientes = i.ambientes;
      if (i.anioConstru != null) _anioConstrCtrl.text = i.anioConstru.toString();
      _estadoInmueble = i.estadoInmueble;
      _fecha = i.fechaAdquisicion;
    }
  }

  void _autocompletarValor() {
    if (_valorUSDCtrl.text.isNotEmpty) return;
    final barrio = _barrioCtrl.text.trim();
    final m2 = double.tryParse(_m2Ctrl.text.replaceAll(',', '.'));
    if (barrio.isEmpty || m2 == null || m2 <= 0) return;
    final precioM2 = PreciosBarrios.getPrecioM2(barrio);
    if (precioM2 != null) {
      setState(() => _valorUSDCtrl.text = precioM2.toStringAsFixed(0));
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _direccionCtrl.dispose();
    _barrioCtrl.dispose();
    _costoCtrl.dispose();
    _valorUSDCtrl.dispose();
    _m2Ctrl.dispose();
    _alquilerCtrl.dispose();
    _parteIndivisaCtrl.dispose();
    _anioConstrCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final inmueble = Inmueble(
      id: widget.inmueble?.id,
      nombre: _nombreCtrl.text.trim(),
      direccion: _direccionCtrl.text.trim(),
      barrio: _barrioCtrl.text.trim().isEmpty ? null : _barrioCtrl.text.trim(),
      costoOriginalUSD: double.parse(_costoCtrl.text.replaceAll(',', '.')),
      superficieM2: double.parse(_m2Ctrl.text.replaceAll(',', '.')),
      valorEstimadoUSD: () {
        final precioM2 =
            double.tryParse(_valorUSDCtrl.text.replaceAll(',', '.')) ?? 0.0;
        final m2 =
            double.tryParse(_m2Ctrl.text.replaceAll(',', '.')) ?? 0.0;
        return precioM2 > 0 && m2 > 0 ? precioM2 * m2 : 0.0;
      }(),
      fechaAdquisicion: _fecha,
      alquilerMensualUSD: _alquilerCtrl.text.isNotEmpty
          ? double.tryParse(_alquilerCtrl.text.replaceAll(',', '.'))
          : null,
      alquilerMoneda: _alquilerMoneda,
      alquilerFormaCobro:
          _alquilerCtrl.text.isNotEmpty ? _alquilerFormaCobro : null,
      parteIndivisaPct:
          double.tryParse(_parteIndivisaCtrl.text.replaceAll(',', '.')) ?? 100.0,
      ambientes: _ambientes,
      anioConstru: int.tryParse(_anioConstrCtrl.text.trim()),
      estadoInmueble: _estadoInmueble,
    );

    await ref
        .read(inversionesNotifierProvider.notifier)
        .agregarInmueble(inmueble);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
                MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.surfaceBorder,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: AppSpacing.md),
              Text(_isEditing ? 'Editar Inmueble' : 'Agregar Inmueble',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.lg),

              TextFormField(
                  controller: _nombreCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Nombre / Alias'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Requerido' : null),
              const SizedBox(height: AppSpacing.md),

              TextFormField(
                  controller: _direccionCtrl,
                  decoration: const InputDecoration(labelText: 'Dirección'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Requerido' : null),
              const SizedBox(height: AppSpacing.md),

              TextFormField(
                controller: _barrioCtrl,
                decoration: const InputDecoration(
                  labelText: 'Barrio o localidad',
                  hintText: 'Ej: Palermo, Belgrano, Rosario...',
                  prefixIcon: Icon(Icons.location_on_outlined,
                      color: AppColors.secondary),
                  helperText:
                      'Se usa para calcular el valor de mercado automáticamente',
                  helperStyle:
                      TextStyle(color: AppColors.primary, fontSize: 11),
                ),
                onChanged: (_) => _autocompletarValor(),
              ),
              const SizedBox(height: AppSpacing.md),

              Row(children: [
                Expanded(
                    child: TextFormField(
                  controller: _m2Ctrl,
                  decoration:
                      const InputDecoration(labelText: 'Superficie (m²)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => _autocompletarValor(),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Requerido' : null,
                )),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: TextFormField(
                  controller: _costoCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Costo Original (USD)',
                      prefixText: 'USD '),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Requerido' : null,
                )),
              ]),
              const SizedBox(height: AppSpacing.md),

              Row(children: [
                Expanded(
                    child: TextFormField(
                  controller: _valorUSDCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Precio/m² estimado (USD/m²)',
                    prefixText: 'USD ',
                    hintText: 'Auto desde barrio si se deja vacío',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                )),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: TextFormField(
                  controller: _alquilerCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Alquiler/mes (opcional)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                )),
              ]),
              if (_alquilerCtrl.text.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _alquilerMoneda,
                      decoration:
                          const InputDecoration(labelText: 'Moneda alquiler'),
                      dropdownColor: AppColors.surfaceElevated,
                      isExpanded: true,
                      items: kMonedas
                          .map((m) => DropdownMenuItem(
                              value: m.codigo,
                              child: Text('${m.codigo} ${m.simbolo}',
                                  overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) => setState(() => _alquilerMoneda = v!),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DropdownButtonFormField<FormaCobroAlquiler>(
                      value: _alquilerFormaCobro,
                      decoration:
                          const InputDecoration(labelText: 'Forma de cobro'),
                      dropdownColor: AppColors.surfaceElevated,
                      items: FormaCobroAlquiler.values
                          .map((f) => DropdownMenuItem(
                              value: f,
                              child: Row(children: [
                                Text(f.emoji),
                                const SizedBox(width: 6),
                                Text(f.label),
                              ])))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _alquilerFormaCobro = v!),
                    ),
                  ),
                ]),
              ],
              const SizedBox(height: AppSpacing.md),

              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _ambientes,
                    decoration:
                        const InputDecoration(labelText: 'Ambientes'),
                    dropdownColor: AppColors.surfaceElevated,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('— No indicado')),
                      ...List.generate(6, (i) => i + 1).map((n) =>
                          DropdownMenuItem(
                            value: n,
                            child: Text(n == 1
                                ? 'Monoambiente'
                                : '$n ambientes'),
                          )),
                    ],
                    onChanged: (v) => setState(() => _ambientes = v),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextFormField(
                    controller: _anioConstrCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Año construcción'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      final n = int.tryParse(v);
                      if (n == null || n < 1900 || n > 2100)
                        return 'Año inválido';
                      return null;
                    },
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.md),

              DropdownButtonFormField<EstadoInmueble?>(
                value: _estadoInmueble,
                decoration: const InputDecoration(
                    labelText: 'Estado del inmueble'),
                dropdownColor: AppColors.surfaceElevated,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('— No indicado')),
                  ...EstadoInmueble.values.map((e) => DropdownMenuItem(
                        value: e,
                        child: Row(children: [
                          Text(e.emoji),
                          const SizedBox(width: 8),
                          Text(e.label),
                        ]),
                      )),
                ],
                onChanged: (v) => setState(() => _estadoInmueble = v),
              ),
              const SizedBox(height: AppSpacing.md),

              TextFormField(
                controller: _parteIndivisaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Parte Indivisa (%)',
                  hintText: '100',
                  suffixText: '%',
                  helperText:
                      'Porcentaje de propiedad que te corresponde',
                  helperStyle: TextStyle(fontSize: 11),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final n =
                      double.tryParse(v?.replaceAll(',', '.') ?? '');
                  if (n == null || n <= 0 || n > 100)
                    return 'Ingresá un valor entre 1 y 100';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined,
                      color: AppColors.secondary),
                  title: Text(DateFormat('dd/MM/yyyy').format(_fecha)),
                  subtitle: const Text('Fecha de compra'),
                  onTap: () async {
                    final d = await showDatePicker(
                        context: context,
                        initialDate: _fecha,
                        firstDate: DateTime(1980),
                        lastDate: DateTime.now());
                    if (d != null) setState(() => _fecha = d);
                  }),
              const SizedBox(height: AppSpacing.lg),

              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 16)),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        _isEditing
                            ? 'Guardar Cambios'
                            : 'Agregar Inmueble',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
