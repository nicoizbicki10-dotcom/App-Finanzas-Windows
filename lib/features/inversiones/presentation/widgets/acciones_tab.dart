import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/percentage_badge.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../market_data/providers/market_data_providers.dart';
import '../../domain/inversion_models.dart';
import '../providers/inversiones_provider.dart';
import 'add_accion_sheet.dart';
import 'exchange_selector_bar.dart';
import 'inversion_total_banner.dart';
import 'ticker_tape_widget.dart';

// ─── Sort enum ─────────────────────────────────────────────────────────────

enum _SortAccion {
  valorActual('Valor actual total'),
  cantidad('Cantidad de acciones'),
  ganancia('Ganancia %');

  const _SortAccion(this.label);
  final String label;
}

// ─── Tab ───────────────────────────────────────────────────────────────────

class AccionesTab extends ConsumerStatefulWidget {
  const AccionesTab({super.key});

  @override
  ConsumerState<AccionesTab> createState() => _AccionesTabState();
}

class _AccionesTabState extends ConsumerState<AccionesTab> {
  final _nombreCtrl = TextEditingController();
  final _brokerCtrl = TextEditingController();

  String _searchNombre = '';
  String _searchBroker = '';
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  _SortAccion? _sort;
  bool _sortAsc = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _brokerCtrl.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    int c = 0;
    if (_searchBroker.isNotEmpty) c++;
    if (_fechaDesde != null || _fechaHasta != null) c++;
    if (_sort != null) c++;
    return c;
  }

  void _clearAll() => setState(() {
        _searchNombre = '';
        _nombreCtrl.clear();
        _searchBroker = '';
        _brokerCtrl.clear();
        _fechaDesde = null;
        _fechaHasta = null;
        _sort = null;
      });

  Future<void> _openFilters(BuildContext ctx) async {
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccionesFilterSheet(
        initBroker: _searchBroker,
        initFechaDesde: _fechaDesde,
        initFechaHasta: _fechaHasta,
        initSort: _sort,
        initSortAsc: _sortAsc,
        onApply: (broker, fechaD, fechaH, sort, sortAsc) => setState(() {
          _searchBroker = broker;
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
    final acciones = ref.watch(accionesProvider);

    // Deduplicar por ticker
    final Map<String, Accion> byTicker = {};
    for (final a in acciones) {
      byTicker.putIfAbsent(a.ticker, () => a);
    }

    // Pre-computar cantidad y valor actual para filtrado/ordenamiento
    final Map<String, double> cantidadMap = {};
    final Map<String, double> valorActualMap = {};
    for (final ticker in byTicker.keys) {
      final ops = ref.watch(operacionesAccionProvider(ticker));
      final cantidad = ops
          .fold(0.0, (s, op) => op.tipoOp == TipoOperacion.compra
              ? s + op.cantidad
              : s - op.cantidad)
          .clamp(0.0, double.infinity);
      cantidadMap[ticker] = cantidad;
      final precio = ref.watch(stockQuoteProvider(ticker)).value?.currentPrice ??
          byTicker[ticker]!.precioCompraUSD;
      valorActualMap[ticker] = cantidad * precio;
    }

    // Ganancia % por ticker (precio actual vs precio de compra)
    final Map<String, double> gananciaMap = {};
    for (final ticker in byTicker.keys) {
      final precioCompra = byTicker[ticker]!.precioCompraUSD;
      final precioActual = ref.watch(stockQuoteProvider(ticker)).value?.currentPrice
          ?? precioCompra;
      gananciaMap[ticker] = precioCompra > 0
          ? (precioActual - precioCompra) / precioCompra * 100
          : 0;
    }

    // Ticker mundial
    final worldItems = worldStockTickers.map((ticker) {
      final quoteAsync = ref.watch(stockQuoteProvider(ticker));
      final quote = quoteAsync.value;
      return TickerItem(
        symbol: ticker,
        price: quote?.currentPrice ?? 0.0,
        changePercent: quote?.changePercent ?? 0.0,
      );
    }).where((item) => item.price > 0).toList();

    // Aplicar filtros
    var entries = byTicker.entries.toList();
    entries = entries.where((e) {
      final accion = e.value;
      if (_searchNombre.isNotEmpty) {
        final q = _searchNombre.toLowerCase();
        if (!accion.ticker.toLowerCase().contains(q) &&
            !accion.nombre.toLowerCase().contains(q)) return false;
      }
      if (_searchBroker.isNotEmpty) {
        if (!(accion.exchange.toLowerCase()
            .contains(_searchBroker.toLowerCase()))) return false;
      }
      if (_fechaDesde != null &&
          accion.fechaAdquisicion.isBefore(_fechaDesde!)) return false;
      if (_fechaHasta != null &&
          accion.fechaAdquisicion
              .isAfter(_fechaHasta!.add(const Duration(days: 1)))) return false;
      return true;
    }).toList();

    // Aplicar orden
    if (_sort != null) {
      entries.sort((a, b) {
        final double va, vb;
        switch (_sort!) {
          case _SortAccion.valorActual:
            va = valorActualMap[a.key] ?? 0;
            vb = valorActualMap[b.key] ?? 0;
          case _SortAccion.cantidad:
            va = cantidadMap[a.key] ?? 0;
            vb = cantidadMap[b.key] ?? 0;
          case _SortAccion.ganancia:
            va = gananciaMap[a.key] ?? 0;
            vb = gananciaMap[b.key] ?? 0;
        }
        return _sortAsc ? va.compareTo(vb) : vb.compareTo(va);
      });
    }

    final lista = entries.map((e) => e.value).toList();

    final totalAccionesAsync = ref.watch(valorAccionesUSDProvider);
    final dolarVenta = ref.watch(dolarProvider).value
            ?.where((d) => d.casa.toLowerCase() == 'blue')
            .map((d) => d.venta)
            .firstOrNull ??
        1050.0;

    final varAcciones = byTicker.entries
        .where((e) => e.value.precioCompraUSD > 0)
        .map((e) => gananciaMap[e.key] ?? 0.0)
        .toList();
    final avgVarAcciones = varAcciones.isEmpty
        ? null
        : varAcciones.reduce((a, b) => a + b) / varAcciones.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InversionTotalBanner(
          totalUSD: totalAccionesAsync.value,
          dolarVenta: dolarVenta,
          seccionKey: 'Acciones',
          variacionPromedio: avgVarAcciones,
        ),
        // Ticker mundial
        if (worldItems.isNotEmpty) ...[
          TickerTapeWidget(items: worldItems),
          const SizedBox(height: AppSpacing.sm),
        ],

        // Exchange / Broker selector
        const ExchangeSelectorBar(
          prefKey: 'acciones_exchange',
          accentColor: AppColors.primary,
        ),
        const SizedBox(height: AppSpacing.sm),

        // ── Search bar + actions ─────────────────────────────────────────
        Row(children: [
          Expanded(
            child: TextField(
              controller: _nombreCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por ticker o nombre...',
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: AppColors.textSecondary),
                suffixIcon: _searchNombre.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => setState(() {
                              _searchNombre = '';
                              _nombreCtrl.clear();
                            }))
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
              builder: (_) => const AddAccionSheet(),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Agregar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
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
              if (_searchBroker.isNotEmpty)
                _ActiveChip(
                    label: '🏦 $_searchBroker',
                    onRemove: () => setState(() {
                          _searchBroker = '';
                          _brokerCtrl.clear();
                        })),
              if (_fechaDesde != null || _fechaHasta != null)
                _ActiveChip(
                    label:
                        'Compra: ${_fechaDesde != null ? DateFormat('MM/yy').format(_fechaDesde!) : '?'}–${_fechaHasta != null ? DateFormat('MM/yy').format(_fechaHasta!) : '?'}',
                    onRemove: () => setState(() {
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
        if (byTicker.isNotEmpty && (_activeFilterCount > 0 || _searchNombre.isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('${lista.length} de ${byTicker.length} acciones',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
          ),

        // ── List ─────────────────────────────────────────────────────────
        if (acciones.isEmpty)
          const _EmptyAcciones()
        else if (lista.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search_off,
                        size: 40, color: AppColors.textDisabled),
                    const SizedBox(height: 12),
                    const Text('Sin resultados',
                        style: TextStyle(color: AppColors.textSecondary)),
                    TextButton(
                        onPressed: _clearAll,
                        child: const Text('Limpiar filtros')),
                  ]),
            ),
          )
        else ...[
          const SectionHeader(title: 'MI PORTFOLIO'),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: ListView.separated(
              itemCount: lista.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) => _AccionCard(accion: lista[i]),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Filter sheet ──────────────────────────────────────────────────────────

class _AccionesFilterSheet extends StatefulWidget {
  final String initBroker;
  final DateTime? initFechaDesde;
  final DateTime? initFechaHasta;
  final _SortAccion? initSort;
  final bool initSortAsc;
  final void Function(String broker, DateTime? fechaD, DateTime? fechaH,
      _SortAccion? sort, bool sortAsc) onApply;

  const _AccionesFilterSheet({
    required this.initBroker,
    required this.initFechaDesde,
    required this.initFechaHasta,
    required this.initSort,
    required this.initSortAsc,
    required this.onApply,
  });

  @override
  State<_AccionesFilterSheet> createState() => _AccionesFilterSheetState();
}

class _AccionesFilterSheetState extends State<_AccionesFilterSheet> {
  late final TextEditingController _brokerCtrl;
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  _SortAccion? _sort;
  bool _sortAsc = false;

  @override
  void initState() {
    super.initState();
    _brokerCtrl = TextEditingController(text: widget.initBroker);
    _fechaDesde = widget.initFechaDesde;
    _fechaHasta = widget.initFechaHasta;
    _sort = widget.initSort;
    _sortAsc = widget.initSortAsc;
  }

  @override
  void dispose() {
    _brokerCtrl.dispose();
    super.dispose();
  }

  void _clear() => setState(() {
        _brokerCtrl.clear();
        _fechaDesde = null;
        _fechaHasta = null;
        _sort = null;
        _sortAsc = false;
      });

  void _apply() {
    widget.onApply(
        _brokerCtrl.text.trim(), _fechaDesde, _fechaHasta, _sort, _sortAsc);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
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

            // ── Broker ───────────────────────────────────────────────
            const _SectionLabel(label: 'Buscar por broker / exchange'),
            TextField(
              controller: _brokerCtrl,
              decoration: const InputDecoration(
                hintText: 'Ej: IBKR, Balanz, IOL...',
                prefixIcon: Icon(Icons.business_outlined, size: 18),
                isDense: true,
              ),
            ),
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
                      firstDate: DateTime(2000),
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
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now());
                  if (d != null) setState(() => _fechaHasta = d);
                },
                onClear: _fechaHasta != null
                    ? () => setState(() => _fechaHasta = null)
                    : null,
              )),
            ]),
            const SizedBox(height: 20),

            // ── Ordenar ───────────────────────────────────────────────
            const _SectionLabel(label: 'Ordenar por'),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _FilterChip2(
                  label: 'Sin ordenar',
                  selected: _sort == null,
                  onTap: () => setState(() => _sort = null)),
              ..._SortAccion.values.map((s) => _FilterChip2(
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
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Aplicar',
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

class _AccionCard extends ConsumerWidget {
  final Accion accion;
  const _AccionCard({required this.accion});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quoteAsync = ref.watch(stockQuoteProvider(accion.ticker));

    return AppCard(
      child: quoteAsync.when(
        loading: () => _AccionCardContent(
          accion: accion,
          currentPrice: accion.precioCompraUSD,
          changePercent: 0,
          isLoading: true,
        ),
        error: (_, __) => _AccionCardContent(
          accion: accion,
          currentPrice: accion.precioCompraUSD,
          changePercent: 0,
          isError: true,
        ),
        data: (quote) {
          final rentabilidad = accion.precioCompraUSD > 0
              ? ((quote.currentPrice - accion.precioCompraUSD) /
                      accion.precioCompraUSD) *
                  100
              : 0.0;
          return _AccionCardContent(
            accion: accion,
            currentPrice: quote.currentPrice,
            changePercent: quote.changePercent,
            rentabilidadPct: rentabilidad,
          );
        },
      ),
    );
  }
}

class _AccionCardContent extends ConsumerWidget {
  final Accion accion;
  final double currentPrice;
  final double changePercent;
  final double? rentabilidadPct;
  final bool isLoading;
  final bool isError;

  const _AccionCardContent({
    required this.accion,
    required this.currentPrice,
    required this.changePercent,
    this.rentabilidadPct,
    this.isLoading = false,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operaciones = ref.watch(operacionesAccionProvider(accion.ticker));
    final cantidadActual = operaciones
        .fold(0.0, (sum, op) => op.tipoOp == TipoOperacion.compra
            ? sum + op.cantidad
            : sum - op.cantidad)
        .clamp(0.0, double.infinity);

    final valorActual = cantidadActual * currentPrice;

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              accion.ticker.length > 4
                  ? accion.ticker.substring(0, 4)
                  : accion.ticker,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(accion.ticker,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 8),
                  if (!isLoading && !isError)
                    PercentageBadge(percentage: changePercent, fontSize: 11),
                  if (isLoading)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: AppColors.primary),
                    ),
                ],
              ),
              Text(
                '${cantidadActual.toStringAsFixed(cantidadActual % 1 == 0 ? 0 : 2)} acciones',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              CurrencyFormatter.usd(valorActual),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            if (rentabilidadPct != null)
              PercentageBadge(
                  percentage: rentabilidadPct!, fontSize: 11, showIcon: false),
            Text(CurrencyFormatter.usd(currentPrice),
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.history,
              size: 18, color: AppColors.textSecondary),
          tooltip: 'Historial',
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) =>
                _HistorialAccionesSheet(ticker: accion.ticker),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined,
              size: 18, color: AppColors.textSecondary),
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => AddAccionSheet(accion: accion),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline,
              size: 18, color: AppColors.textDisabled),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.surface,
                title: const Text('Eliminar acción'),
                content:
                    Text('¿Eliminar ${accion.ticker} del portfolio?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Eliminar',
                          style: TextStyle(color: AppColors.danger))),
                ],
              ),
            );
            if (confirm == true) {
              ref
                  .read(inversionesNotifierProvider.notifier)
                  .eliminarAccionesPorTicker(accion.ticker);
            }
          },
        ),
      ],
    );
  }
}

// ─── Historial sheet ───────────────────────────────────────────────────────

class _HistorialAccionesSheet extends ConsumerWidget {
  final String ticker;
  const _HistorialAccionesSheet({required this.ticker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operaciones = ref.watch(operacionesAccionProvider(ticker));
    return _HistorialSheet(
      titulo: 'Historial de $ticker',
      operaciones: operaciones,
      color: AppColors.primary,
      onDelete: (op) =>
          ref.read(inversionesNotifierProvider.notifier).eliminarOperacion(op),
      onEdit: (op) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => EditOperacionSheet(op: op),
      ),
    );
  }
}

class _HistorialSheet extends StatelessWidget {
  final String titulo;
  final List<OperacionLog> operaciones;
  final Color color;
  final void Function(OperacionLog)? onDelete;
  final void Function(OperacionLog)? onEdit;
  const _HistorialSheet(
      {required this.titulo,
      required this.operaciones,
      required this.color,
      this.onDelete,
      this.onEdit});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.surfaceBorder,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(titulo,
                  style: Theme.of(context).textTheme.headlineMedium),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.surfaceBorder),
            if (operaciones.isEmpty)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history,
                          size: 40, color: AppColors.textDisabled),
                      SizedBox(height: 12),
                      Text('Sin operaciones registradas',
                          style:
                              TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  controller: sc,
                  padding: const EdgeInsets.all(16),
                  itemCount: operaciones.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.surfaceBorder),
                  itemBuilder: (ctx, i) {
                    final op = operaciones[i];
                    final isCompra = op.tipoOp == TipoOperacion.compra;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (isCompra
                                      ? AppColors.success
                                      : AppColors.danger)
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isCompra
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: isCompra
                                  ? AppColors.success
                                  : AppColors.danger,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isCompra ? 'Compra' : 'Venta',
                                  style: TextStyle(
                                    color: isCompra
                                        ? AppColors.success
                                        : AppColors.danger,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  DateFormat('dd/MM/yyyy').format(op.fecha),
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11),
                                ),
                                if (op.exchange != null)
                                  Text(op.exchange!,
                                      style: const TextStyle(
                                          color: AppColors.textDisabled,
                                          fontSize: 10)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                CurrencyFormatter.usd(op.montoTotal),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                              ),
                              Text(
                                '${op.cantidad % 1 == 0 ? op.cantidad.toStringAsFixed(0) : op.cantidad.toStringAsFixed(4)} × ${CurrencyFormatter.usd(op.precioUSD)}',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10),
                              ),
                            ],
                          ),
                          if (onEdit != null)
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  size: 16,
                                  color: AppColors.textSecondary),
                              onPressed: () => onEdit!(op),
                            ),
                          if (onDelete != null)
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 16,
                                  color: AppColors.textDisabled),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: ctx,
                                  builder: (d) => AlertDialog(
                                    backgroundColor: AppColors.surface,
                                    title: const Text('Eliminar operación'),
                                    content: Text(
                                        '¿Eliminar esta ${isCompra ? "compra" : "venta"}?'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(d, false),
                                          child: const Text('Cancelar')),
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(d, true),
                                          child: const Text('Eliminar',
                                              style: TextStyle(
                                                  color:
                                                      AppColors.danger))),
                                    ],
                                  ),
                                );
                                if (confirm == true) onDelete!(op);
                              },
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Edit operacion sheet (shared with crypto) ────────────────────────────

class EditOperacionSheet extends ConsumerStatefulWidget {
  final OperacionLog op;
  const EditOperacionSheet({super.key, required this.op});

  @override
  ConsumerState<EditOperacionSheet> createState() =>
      _EditOperacionSheetState();
}

class _EditOperacionSheetState extends ConsumerState<EditOperacionSheet> {
  late TipoOperacion _tipoOp;
  late TextEditingController _cantidadCtrl;
  late TextEditingController _precioCtrl;
  late TextEditingController _exchangeCtrl;
  late DateTime _fecha;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tipoOp = widget.op.tipoOp;
    _cantidadCtrl =
        TextEditingController(text: widget.op.cantidad.toString());
    _precioCtrl =
        TextEditingController(text: widget.op.precioUSD.toString());
    _exchangeCtrl =
        TextEditingController(text: widget.op.exchange ?? '');
    _fecha = widget.op.fecha;
  }

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _precioCtrl.dispose();
    _exchangeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cantidad =
        double.tryParse(_cantidadCtrl.text.replaceAll(',', '.'));
    final precio = double.tryParse(_precioCtrl.text.replaceAll(',', '.'));
    if (cantidad == null || cantidad <= 0 || precio == null || precio <= 0)
      return;
    setState(() => _saving = true);
    final updated = OperacionLog(
      id: widget.op.id,
      tipoActivo: widget.op.tipoActivo,
      ticker: widget.op.ticker,
      tipoOp: _tipoOp,
      cantidad: cantidad,
      precioUSD: precio,
      fecha: _fecha,
      exchange: _exchangeCtrl.text.trim().isEmpty
          ? null
          : _exchangeCtrl.text.trim(),
    );
    await ref
        .read(inversionesNotifierProvider.notifier)
        .actualizarOperacion(updated);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: sc,
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.surfaceBorder,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Editar Operación',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 20),

            Row(
              children: TipoOperacion.values.map((t) {
                final sel = _tipoOp == t;
                final color = t == TipoOperacion.compra
                    ? AppColors.success
                    : AppColors.danger;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(t == TipoOperacion.compra
                          ? 'Compra'
                          : 'Venta'),
                      selected: sel,
                      onSelected: (_) => setState(() => _tipoOp = t),
                      selectedColor: color.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color:
                            sel ? color : AppColors.textSecondary,
                        fontWeight: sel
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      side: BorderSide(
                          color: sel ? color : AppColors.surfaceBorder),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _cantidadCtrl,
              decoration: const InputDecoration(labelText: 'Cantidad'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _precioCtrl,
              decoration: const InputDecoration(
                  labelText: 'Precio USD', prefixText: 'USD '),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _exchangeCtrl,
              decoration: const InputDecoration(
                  labelText: 'Exchange / Broker (opcional)'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined,
                  color: AppColors.primary),
              title: Text(DateFormat('dd/MM/yyyy').format(_fecha)),
              subtitle: const Text('Fecha'),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _fecha,
                  firstDate: DateTime(2010),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _fecha = d);
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Guardar Cambios',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared filter widgets (also used in crypto_tab) ──────────────────────

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
              color: selected
                  ? AppColors.primary
                  : AppColors.surfaceBorder),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal)),
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
              color: date != null
                  ? AppColors.primary
                  : AppColors.surfaceBorder),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary)),
                  Text(
                    date != null
                        ? DateFormat('dd/MM/yyyy').format(date!)
                        : 'Seleccionar',
                    style: TextStyle(
                        fontSize: 12,
                        color: date != null
                            ? AppColors.primary
                            : AppColors.textDisabled,
                        fontWeight: date != null
                            ? FontWeight.w500
                            : FontWeight.normal),
                  ),
                ]),
          ),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.clear,
                  size: 14, color: AppColors.textDisabled),
            )
          else
            const Icon(Icons.calendar_today_outlined,
                size: 14, color: AppColors.textDisabled),
        ]),
      ),
    );
  }
}

// ─── Empty state ───────────────────────────────────────────────────────────

class _EmptyAcciones extends StatelessWidget {
  const _EmptyAcciones();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.candlestick_chart_outlined,
              size: 40, color: AppColors.textDisabled),
          const SizedBox(height: 12),
          Text('No tenés acciones en tu portfolio',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
