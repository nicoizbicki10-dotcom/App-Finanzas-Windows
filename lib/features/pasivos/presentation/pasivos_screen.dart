import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/display_currency_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/currency_selector.dart';
import '../../inversiones/data/currency_data.dart';
import '../../market_data/providers/market_data_providers.dart';
import '../domain/pasivo_models.dart';
import 'providers/pasivos_provider.dart';

class PasivosScreen extends ConsumerStatefulWidget {
  const PasivosScreen({super.key});

  @override
  ConsumerState<PasivosScreen> createState() => _PasivosScreenState();
}

class _PasivosScreenState extends ConsumerState<PasivosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tipos = [
    TipoPasivo.particular,
    TipoPasivo.bancario,
    TipoPasivo.financiero,
    TipoPasivo.otro,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalUSD = ref.watch(totalPasivosUSDProvider);
    final todos = ref.watch(pasivosProvider);
    final dolarAsync = ref.watch(dolarProvider);
    final dolarVenta = dolarAsync.value
            ?.where((d) => d.casa.toLowerCase() == 'blue')
            .map((d) => d.venta)
            .firstOrNull ??
        1050.0;

    final tipoActivo = _tipos[_tabController.index];
    final seccionUSD = todos
        .where((p) => p.tipo == tipoActivo)
        .fold(0.0, (s, p) => s + monedaToUSD(p.montoTotal, p.moneda, dolarVenta));
    final pctSeccion = totalUSD > 0 ? seccionUSD / totalUSD : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pasivos'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.danger,
          labelColor: AppColors.danger,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: '👤 Particulares'),
            Tab(text: '🏦 Bancarias'),
            Tab(text: '📊 Financieras'),
            Tab(text: '📌 Otras'),
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Total general ────────────────────────────────────
                _TotalDeudasCard(totalUSD: totalUSD, dolarVenta: dolarVenta),
                const SizedBox(height: 8),

                // ── Total sección activa ─────────────────────────────
                _SeccionTotalCard(
                  tipo: tipoActivo,
                  seccionUSD: seccionUSD,
                  pct: pctSeccion,
                  dolarVenta: dolarVenta,
                ),
                const SizedBox(height: AppSpacing.sectionSpacing),

                // ── Tabs de pasivos ────────────────────────────────
                SizedBox(
                  height: 600,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _PasivoTabContent(tipo: TipoPasivo.particular, dolarVenta: dolarVenta),
                      _PasivoTabContent(tipo: TipoPasivo.bancario, dolarVenta: dolarVenta),
                      _PasivoTabContent(tipo: TipoPasivo.financiero, dolarVenta: dolarVenta),
                      _PasivoTabContent(tipo: TipoPasivo.otro, dolarVenta: dolarVenta),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalDeudasCard extends ConsumerWidget {
  final double totalUSD;
  final double dolarVenta;
  const _TotalDeudasCard({required this.totalUSD, required this.dolarVenta});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(displayCurrencyProvider);
    final btcPrice = ref.watch(btcPriceUSDProvider);
    final fiatRates = ref.watch(fiatRatesProvider).value ?? {};
    final primary = CurrencyFormatter.fromUSD(totalUSD, currency,
        dolarBlue: dolarVenta, btcPrice: btcPrice, fiatRates: fiatRates);
    final secondary = CurrencyFormatter.secondaryFromUSD(totalUSD, currency,
        dolarBlue: dolarVenta, btcPrice: btcPrice, fiatRates: fiatRates);
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.trending_down, color: AppColors.danger, size: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total deudas', style: Theme.of(context).textTheme.bodySmall),
                Text(primary,
                    style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                        fontSize: 20)),
                if (secondary.isNotEmpty)
                  Text(secondary,
                      style: const TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w500,
                          fontSize: 12)),
              ],
            ),
          ),
          CurrencySelector(color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _SeccionTotalCard extends ConsumerWidget {
  final TipoPasivo tipo;
  final double seccionUSD;
  final double pct;
  final double dolarVenta;

  const _SeccionTotalCard({
    required this.tipo,
    required this.seccionUSD,
    required this.pct,
    required this.dolarVenta,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(displayCurrencyProvider);
    final btcPrice = ref.watch(btcPriceUSDProvider);
    final fiatRates = ref.watch(fiatRatesProvider).value ?? {};
    final primary = CurrencyFormatter.fromUSD(seccionUSD, currency,
        dolarBlue: dolarVenta, btcPrice: btcPrice, fiatRates: fiatRates);
    final secondary = CurrencyFormatter.secondaryFromUSD(seccionUSD, currency,
        dolarBlue: dolarVenta, btcPrice: btcPrice, fiatRates: fiatRates);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Text(tipo.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total ${tipo.labelPlural}',
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
                Text(primary,
                    style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                if (secondary.isNotEmpty)
                  Text(secondary,
                      style: const TextStyle(
                          color: AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (pct > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${(pct * 100).toStringAsFixed(1)}% del total',
                style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

enum _SortPasivo {
  monto('Monto adeudado'),
  cuota('Cuota mensual'),
  urgencia('Urgencia (vencimiento)'),
  fechaDeuda('Fecha de endeudamiento');

  const _SortPasivo(this.label);
  final String label;
}

class _PasivoTabContent extends ConsumerStatefulWidget {
  final TipoPasivo tipo;
  final double dolarVenta;
  const _PasivoTabContent({required this.tipo, required this.dolarVenta});

  @override
  ConsumerState<_PasivoTabContent> createState() => _PasivoTabContentState();
}

class _PasivoTabContentState extends ConsumerState<_PasivoTabContent> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  _SortPasivo? _sort;
  bool _sortAsc = false;
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    int c = 0;
    if (_fechaDesde != null || _fechaHasta != null) c++;
    if (_sort != null) c++;
    return c;
  }

  List<Pasivo> _apply(List<Pasivo> source) {
    var list = source.where((p) {
      if (_search.isNotEmpty &&
          !p.concepto.toLowerCase().contains(_search.toLowerCase())) return false;
      if (_fechaDesde != null && p.fechaEndeudamiento.isBefore(_fechaDesde!)) return false;
      if (_fechaHasta != null &&
          p.fechaEndeudamiento.isAfter(_fechaHasta!.add(const Duration(days: 1)))) return false;
      return true;
    }).toList();

    if (_sort != null) {
      list.sort((a, b) {
        double va, vb;
        switch (_sort!) {
          case _SortPasivo.monto:
            va = a.monto; vb = b.monto;
          case _SortPasivo.cuota:
            va = a.cuotaMensual ?? 0; vb = b.cuotaMensual ?? 0;
          case _SortPasivo.urgencia:
            va = a.fechaVencimiento.millisecondsSinceEpoch.toDouble();
            vb = b.fechaVencimiento.millisecondsSinceEpoch.toDouble();
          case _SortPasivo.fechaDeuda:
            va = a.fechaEndeudamiento.millisecondsSinceEpoch.toDouble();
            vb = b.fechaEndeudamiento.millisecondsSinceEpoch.toDouble();
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
      builder: (_) => _PasivoFilterSheet(
        initFechaDesde: _fechaDesde,
        initFechaHasta: _fechaHasta,
        initSort: _sort,
        initSortAsc: _sortAsc,
        onApply: (fechaD, fechaH, sort, sortAsc) => setState(() {
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
    final todos = ref.watch(pasivosProvider);
    final seccion = todos.where((p) => p.tipo == widget.tipo).toList();
    final filtrados = _apply(seccion);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Buscar por concepto...',
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
            ),
            const SizedBox(width: 4),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Icon(Icons.tune,
                      color: _activeFilterCount > 0
                          ? AppColors.danger
                          : AppColors.textSecondary),
                  tooltip: 'Filtros y orden',
                  onPressed: () => _openFilters(context),
                ),
                if (_activeFilterCount > 0)
                  Positioned(
                    right: 4, top: 4,
                    child: Container(
                      width: 16, height: 16,
                      decoration: const BoxDecoration(
                          color: AppColors.danger, shape: BoxShape.circle),
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
                builder: (_) => _PasivoSheet(tipoInicial: widget.tipo),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Agregar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (filtrados.isEmpty)
          Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.check_circle_outline, size: 40, color: AppColors.textDisabled),
              const SizedBox(height: 12),
              Text('Sin deudas ${widget.tipo.labelPlural.toLowerCase()} registradas',
                  style: Theme.of(context).textTheme.bodyMedium),
            ]),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: filtrados.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) =>
                  _PasivoCard(pasivo: filtrados[i], dolarVenta: widget.dolarVenta),
            ),
          ),
      ],
    );
  }
}

// ─── Filter Sheet ─────────────────────────────────────────────────────────────

class _PasivoFilterSheet extends StatefulWidget {
  final DateTime? initFechaDesde;
  final DateTime? initFechaHasta;
  final _SortPasivo? initSort;
  final bool initSortAsc;
  final void Function(
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    _SortPasivo? sort,
    bool sortAsc,
  ) onApply;

  const _PasivoFilterSheet({
    required this.initFechaDesde,
    required this.initFechaHasta,
    required this.initSort,
    required this.initSortAsc,
    required this.onApply,
  });

  @override
  State<_PasivoFilterSheet> createState() => _PasivoFilterSheetState();
}

class _PasivoFilterSheetState extends State<_PasivoFilterSheet> {
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  _SortPasivo? _sort;
  bool _sortAsc = false;

  @override
  void initState() {
    super.initState();
    _fechaDesde = widget.initFechaDesde;
    _fechaHasta = widget.initFechaHasta;
    _sort = widget.initSort;
    _sortAsc = widget.initSortAsc;
  }

  void _clear() => setState(() {
        _fechaDesde = null;
        _fechaHasta = null;
        _sort = null;
        _sortAsc = false;
      });

  void _apply() {
    widget.onApply(_fechaDesde, _fechaHasta, _sort, _sortAsc);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
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
                      style: TextStyle(color: AppColors.danger, fontSize: 13))),
            ]),
            const SizedBox(height: 20),

            // ── Fecha de endeudamiento ─────────────────────────────────
            const _PasivoSectionLabel(label: 'Fecha de endeudamiento'),
            Row(children: [
              Expanded(
                  child: _PasivoDateButton(
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
                  child: _PasivoDateButton(
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

            // ── Ordenar por ─────────────────────────────────────────────
            const _PasivoSectionLabel(label: 'Ordenar por'),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _PasivoFilterChip(
                  label: 'Sin ordenar',
                  selected: _sort == null,
                  onTap: () => setState(() => _sort = null)),
              ..._SortPasivo.values.map((s) => _PasivoFilterChip(
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
                  selectedColor: AppColors.danger.withOpacity(0.2),
                  labelStyle: TextStyle(
                      color: !_sortAsc ? AppColors.danger : AppColors.textSecondary,
                      fontSize: 12),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('↑ Menor primero'),
                  selected: _sortAsc,
                  onSelected: (_) => setState(() => _sortAsc = true),
                  selectedColor: AppColors.danger.withOpacity(0.2),
                  labelStyle: TextStyle(
                      color: _sortAsc ? AppColors.danger : AppColors.textSecondary,
                      fontSize: 12),
                ),
              ]),
            ],
            const SizedBox(height: 28),

            ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
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

class _PasivoSectionLabel extends StatelessWidget {
  final String label;
  const _PasivoSectionLabel({required this.label});

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

class _PasivoFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PasivoFilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.danger.withOpacity(0.15)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.danger : AppColors.surfaceBorder),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? AppColors.danger : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _PasivoDateButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _PasivoDateButton(
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
              ? AppColors.danger.withOpacity(0.08)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: date != null ? AppColors.danger : AppColors.surfaceBorder),
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
                    color: date != null ? AppColors.danger : AppColors.textDisabled,
                    fontWeight:
                        date != null ? FontWeight.w500 : FontWeight.normal),
              ),
            ]),
          ),
          if (onClear != null)
            GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.clear,
                    size: 14, color: AppColors.textDisabled))
          else
            const Icon(Icons.calendar_today_outlined,
                size: 14, color: AppColors.textDisabled),
        ]),
      ),
    );
  }
}

class _PasivoCard extends ConsumerWidget {
  final Pasivo pasivo;
  final double dolarVenta;
  const _PasivoCard({required this.pasivo, required this.dolarVenta});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat('#,##0.00', 'es_AR');

    String formatMonto(double amount, String moneda) {
      if (moneda == 'ARS') return CurrencyFormatter.compact(amount);
      if (moneda == 'USD') return CurrencyFormatter.usd(amount);
      return '${monedaInfo(moneda).simbolo} ${fmt.format(amount)}';
    }

    final montoDisplay = formatMonto(pasivo.monto, pasivo.moneda);
    final totalDisplay = formatMonto(pasivo.montoTotal, pasivo.moneda);
    final fechaVence = DateFormat('dd/MM/yyyy').format(pasivo.fechaVencimiento);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(pasivo.tipo.emoji, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pasivo.concepto, style: Theme.of(context).textTheme.titleMedium),
                    Text(pasivo.tipo.label,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(montoDisplay,
                      style: const TextStyle(
                          color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 13)),
                  if (pasivo.tasaInteresPct > 0) ...[
                    Text('+${formatMonto(pasivo.intereses, pasivo.moneda)}',
                        style: const TextStyle(color: AppColors.warning, fontSize: 11)),
                    Text('Total: $totalDisplay',
                        style: const TextStyle(
                            color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _PasivoSheet(pasivo: pasivo),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textDisabled),
                onPressed: () =>
                    ref.read(pasivosNotifierProvider.notifier).eliminar(pasivo.id),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.event, size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('Vence: $fechaVence',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              if (pasivo.tasaInteresPct > 0) ...[
                const SizedBox(width: 12),
                const Icon(Icons.percent, size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('${pasivo.tasaInteresPct.toStringAsFixed(1)}% · ${pasivo.metodo.label}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ],
          ),
          if (pasivo.cuotaMensual != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_month, size: 12, color: AppColors.warning),
                const SizedBox(width: 4),
                Text(
                  pasivo.metodo == MetodoPasivo.americano
                      ? 'Cuota: ${formatMonto(pasivo.cuotaMensual!, pasivo.moneda)} / mes + capital al vencer'
                      : pasivo.metodo == MetodoPasivo.aleman
                          ? '1° cuota: ${formatMonto(pasivo.cuotaMensual!, pasivo.moneda)} (decreciente)'
                          : 'Cuota: ${formatMonto(pasivo.cuotaMensual!, pasivo.moneda)} / mes',
                  style: const TextStyle(color: AppColors.warning, fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Bottom Sheet ────────────────────────────────────────────────────────────

class _PasivoSheet extends ConsumerStatefulWidget {
  final Pasivo? pasivo;
  final TipoPasivo? tipoInicial;
  const _PasivoSheet({this.pasivo, this.tipoInicial});

  @override
  ConsumerState<_PasivoSheet> createState() => _PasivoSheetState();
}

class _PasivoSheetState extends ConsumerState<_PasivoSheet> {
  final _formKey = GlobalKey<FormState>();
  final _conceptoCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  final _tasaCtrl = TextEditingController();
  final _duracionCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  TipoPasivo _tipo = TipoPasivo.bancario;
  String _moneda = 'ARS';
  DateTime _fechaEndeudamiento = DateTime.now();
  MetodoPasivo _metodo = MetodoPasivo.frances;
  UnidadDuracion _unidadDuracion = UnidadDuracion.meses;
  bool _saving = false;

  String _fechaVenceDisplay = '';
  String _montoTotalDisplay = '';
  String _cuotaMensualDisplay = '';

  bool get _isEditing => widget.pasivo != null;

  @override
  void initState() {
    super.initState();
    final p = widget.pasivo;
    if (p != null) {
      _tipo = p.tipo;
      _conceptoCtrl.text = p.concepto;
      _montoCtrl.text = p.monto > 0 ? p.monto.toString() : '';
      _moneda = p.moneda;
      _fechaEndeudamiento = p.fechaEndeudamiento;
      _tasaCtrl.text = p.tasaInteresPct > 0 ? p.tasaInteresPct.toString() : '';
      _metodo = p.metodo;
      _duracionCtrl.text = p.duracion > 0 ? p.duracion.toString() : '';
      _unidadDuracion = p.unidadDuracion;
      if (p.notas != null) _notasCtrl.text = p.notas!;
    } else if (widget.tipoInicial != null) {
      _tipo = widget.tipoInicial!;
    }

    _montoCtrl.addListener(_recalcular);
    _tasaCtrl.addListener(_recalcular);
    _duracionCtrl.addListener(_recalcular);
    _recalcular();
  }

  @override
  void dispose() {
    _conceptoCtrl.dispose();
    _montoCtrl.dispose();
    _tasaCtrl.dispose();
    _duracionCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  void _recalcular() {
    final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ?? 0;
    final tasa = double.tryParse(_tasaCtrl.text.replaceAll(',', '.')) ?? 0;
    final duracion = double.tryParse(_duracionCtrl.text.replaceAll(',', '.')) ?? 0;

    if (monto <= 0 || duracion <= 0) {
      setState(() {
        _fechaVenceDisplay = '';
        _montoTotalDisplay = '';
        _cuotaMensualDisplay = '';
      });
      return;
    }

    final tempPasivo = Pasivo(
      concepto: '',
      tipo: _tipo,
      monto: monto,
      moneda: _moneda,
      fechaEndeudamiento: _fechaEndeudamiento,
      tasaInteresPct: tasa,
      metodo: _metodo,
      duracion: duracion,
      unidadDuracion: _unidadDuracion,
    );

    String formatM(double v) {
      if (_moneda == 'ARS') return CurrencyFormatter.compact(v);
      if (_moneda == 'USD') return CurrencyFormatter.usd(v);
      final fmt = NumberFormat('#,##0.00', 'es_AR');
      return '${monedaInfo(_moneda).simbolo} ${fmt.format(v)}';
    }

    final fechaVence = DateFormat('dd/MM/yyyy').format(tempPasivo.fechaVencimiento);
    final cuota = tempPasivo.cuotaMensual;

    setState(() {
      _fechaVenceDisplay = fechaVence;
      _montoTotalDisplay = formatM(tempPasivo.montoTotal);
      _cuotaMensualDisplay = cuota != null ? formatM(cuota) : '';
    });
  }

  String _metodoDescripcion(MetodoPasivo m) {
    switch (m) {
      case MetodoPasivo.ninguno:
        return 'Sin método de cálculo. El monto total es igual al capital ingresado.';
      case MetodoPasivo.simple:
        return 'Interés simple: I = Capital × tasa × tiempo. Sin cuotas periódicas.';
      case MetodoPasivo.compuesto:
        return 'Interés compuesto: el interés se capitaliza sobre el saldo acumulado.';
      case MetodoPasivo.frances:
        return 'Sistema Francés: cuota fija mensual. La proporción interés/capital varía en cada cuota.';
      case MetodoPasivo.aleman:
        return 'Sistema Alemán: amortización constante. La cuota decrece con el tiempo.';
      case MetodoPasivo.americano:
        return 'Sistema Americano (Bullet): se pagan solo intereses cada período y el capital completo al vencimiento.';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final pasivo = Pasivo(
      id: widget.pasivo?.id,
      concepto: _conceptoCtrl.text.trim(),
      tipo: _tipo,
      monto: double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ?? 0,
      moneda: _moneda,
      fechaEndeudamiento: _fechaEndeudamiento,
      tasaInteresPct: double.tryParse(_tasaCtrl.text.replaceAll(',', '.')) ?? 0,
      metodo: _metodo,
      duracion: double.tryParse(_duracionCtrl.text.replaceAll(',', '.')) ?? 1,
      unidadDuracion: _unidadDuracion,
      notas: _notasCtrl.text.trim().isNotEmpty ? _notasCtrl.text.trim() : null,
    );

    await ref.read(pasivosNotifierProvider.notifier).agregar(pasivo);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
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
              AppSpacing.md, AppSpacing.sm, AppSpacing.md,
              MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
            ),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(_isEditing ? 'Editar Deuda' : 'Agregar Deuda',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.lg),

              // Tipo
              DropdownButtonFormField<TipoPasivo>(
                value: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo de deuda'),
                dropdownColor: AppColors.surfaceElevated,
                items: TipoPasivo.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Row(children: [
                            Text(t.emoji),
                            const SizedBox(width: 8),
                            Text(t.label),
                          ]),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _tipo = v!),
              ),
              const SizedBox(height: AppSpacing.md),

              // Concepto
              TextFormField(
                controller: _conceptoCtrl,
                decoration: const InputDecoration(labelText: 'Concepto / Descripción'),
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
                      onChanged: (v) {
                        setState(() => _moneda = v!);
                        _recalcular();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Fecha de endeudamiento
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined, color: AppColors.danger),
                title: Text(DateFormat('dd/MM/yyyy').format(_fechaEndeudamiento)),
                subtitle: const Text('Fecha de endeudamiento'),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _fechaEndeudamiento,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) {
                    setState(() => _fechaEndeudamiento = d);
                    _recalcular();
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Método de cálculo
              Text('Método de cálculo', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: MetodoPasivo.values.map((m) {
                  final selected = _metodo == m;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _metodo = m);
                      _recalcular();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.danger.withOpacity(0.15)
                            : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? AppColors.danger : AppColors.surfaceBorder,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(m.emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 2),
                          Text(
                            m.label,
                            style: TextStyle(
                              color: selected ? AppColors.danger : AppColors.textSecondary,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              // Descripción del método seleccionado
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _metodoDescripcion(_metodo),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Tasa de interés
              TextFormField(
                controller: _tasaCtrl,
                decoration: const InputDecoration(
                    labelText: 'Tasa anual (%) — opcional', suffixText: '%'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: AppSpacing.md),

              // Duración
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _duracionCtrl,
                      decoration: const InputDecoration(labelText: 'Duración'),
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
                    child: DropdownButtonFormField<UnidadDuracion>(
                      value: _unidadDuracion,
                      decoration: const InputDecoration(labelText: 'Unidad'),
                      dropdownColor: AppColors.surfaceElevated,
                      items: const [
                        DropdownMenuItem(value: UnidadDuracion.dias, child: Text('Días')),
                        DropdownMenuItem(value: UnidadDuracion.meses, child: Text('Meses')),
                        DropdownMenuItem(value: UnidadDuracion.anios, child: Text('Años')),
                      ],
                      onChanged: (v) {
                        setState(() => _unidadDuracion = v!);
                        _recalcular();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Fecha vencimiento (read-only)
              if (_fechaVenceDisplay.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available, size: 16, color: AppColors.danger),
                      const SizedBox(width: 8),
                      Text('Vencimiento: $_fechaVenceDisplay',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              // Cuota mensual (read-only, solo para amortización)
              if (_cuotaMensualDisplay.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                    border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, size: 16, color: AppColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _metodo == MetodoPasivo.americano
                              ? 'Cuota mensual (interés): $_cuotaMensualDisplay · Capital al vencimiento'
                              : _metodo == MetodoPasivo.aleman
                                  ? 'Cuota inicial (1° período): $_cuotaMensualDisplay · Decrece cada mes'
                                  : 'Cuota mensual fija: $_cuotaMensualDisplay',
                          style: const TextStyle(color: AppColors.warning, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              // Monto total (read-only)
              if (_montoTotalDisplay.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                    border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.trending_down, size: 16, color: AppColors.danger),
                      const SizedBox(width: 8),
                      Text('Total a pagar: $_montoTotalDisplay',
                          style: const TextStyle(
                              color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Notas
              TextFormField(
                controller: _notasCtrl,
                decoration: const InputDecoration(labelText: 'Notas (opcional)'),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.lg),

              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isEditing ? 'Guardar Cambios' : 'Agregar Deuda',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

