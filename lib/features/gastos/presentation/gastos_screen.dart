import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/providers/display_currency_provider.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/currency_selector.dart';
import '../../../core/widgets/section_header.dart';
import '../../market_data/providers/market_data_providers.dart';
import '../../../features/inversiones/presentation/providers/inversiones_provider.dart';
import '../domain/gasto.dart';
import 'providers/gastos_provider.dart';
import 'widgets/add_gasto_sheet.dart';
import 'widgets/gasto_list_tile.dart';
import 'widgets/importar_gastos_page.dart';
import 'widgets/gastos_evolucion_chart.dart';
import 'widgets/gastos_pie_chart.dart';

class GastosScreen extends ConsumerStatefulWidget {
  const GastosScreen({super.key});

  @override
  ConsumerState<GastosScreen> createState() => _GastosScreenState();
}

class _GastosScreenState extends ConsumerState<GastosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddGasto() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddGastoSheet(),
    );
  }

  void _showImportarGastos() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ImportarGastosPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalGastos = ref.watch(totalGastosMesProvider);
    final totalFijos = ref.watch(totalGastosFijosProvider);
    final totalVariables = ref.watch(totalGastosVariablesProvider);
    final totalGastosUsd = ref.watch(totalGastosMesUsdProvider);
    final totalFijosUsd = ref.watch(totalGastosFijosUsdProvider);
    final totalVariablesUsd = ref.watch(totalGastosVariablesUsdProvider);
    final historial12Meses = ref.watch(historial12MesesGastosProvider);
    final historial10Anos = ref.watch(historial10AnosGastosProvider);
    final porCategoria = ref.watch(gastosPorCategoriaProvider);
    final gastosFijos = ref.watch(gastosFijosProvider);
    final gastosVariables = ref.watch(gastosVariablesProvider);

    return Scaffold(
      appBar: AppBar(
        title: _MesSelector(),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined),
            tooltip: 'Importar con IA',
            onPressed: _showImportarGastos,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Fijos'),
            Tab(text: 'Variables'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddGasto,
        backgroundColor: AppColors.danger,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Resumen ─────────────────────────────────────────────
                _GastosSummaryCard(
                  totalGastos: totalGastos,
                  totalFijos: totalFijos,
                  totalVariables: totalVariables,
                  totalGastosUsd: totalGastosUsd,
                  totalFijosUsd: totalFijosUsd,
                  totalVariablesUsd: totalVariablesUsd,
                ),
                const SizedBox(height: AppSpacing.sm),
                _FijosVariablesPct(
                  totalFijos: totalFijos,
                  totalVariables: totalVariables,
                  totalFijosUsd: totalFijosUsd,
                  totalVariablesUsd: totalVariablesUsd,
                ),
                const SizedBox(height: AppSpacing.sectionSpacing),

                // ── Gráfico por categoría ────────────────────────────
                if (porCategoria.isNotEmpty) ...[
                  const SectionHeader(title: 'POR CATEGORÍA'),
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(child: GastosPieChart(data: porCategoria)),
                  const SizedBox(height: AppSpacing.sectionSpacing),
                ],

                // ── Evolución 12 meses ───────────────────────────────
                const SectionHeader(
                  title: 'ÚLTIMOS 12 MESES',
                  subtitle: 'Evolución mensual',
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(child: Gastos12MesesChart(data: historial12Meses)),
                const SizedBox(height: AppSpacing.sectionSpacing),

                // ── Evolución 10 años ────────────────────────────────
                const SectionHeader(
                  title: 'ÚLTIMOS 10 AÑOS',
                  subtitle: 'Total anual',
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(child: Gastos10AnosChart(data: historial10Anos)),
                const SizedBox(height: AppSpacing.sectionSpacing),

                // ── Lista con tabs ───────────────────────────────────
                const SectionHeader(title: 'DETALLE'),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 44,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.primary,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    dividerColor: AppColors.surfaceBorder,
                    tabs: [
                      Tab(
                        text: 'Fijos (${gastosFijos.length})',
                      ),
                      Tab(
                        text: 'Variables (${gastosVariables.length})',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 460,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _GastosList(gastos: gastosFijos),
                      _GastosList(gastos: gastosVariables),
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

class _GastosSummaryCard extends ConsumerWidget {
  final double totalGastos;
  final double totalFijos;
  final double totalVariables;
  final double totalGastosUsd;
  final double totalFijosUsd;
  final double totalVariablesUsd;

  const _GastosSummaryCard({
    required this.totalGastos,
    required this.totalFijos,
    required this.totalVariables,
    required this.totalGastosUsd,
    required this.totalFijosUsd,
    required this.totalVariablesUsd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(displayCurrencyProvider);
    final dolarBlue = ref.watch(dolarBlueVentaProvider);
    final btcPrice = ref.watch(btcPriceUSDProvider);
    final fiatRates = ref.watch(fiatRatesProvider).value ?? {};
    final primaryText = CurrencyFormatter.fromUSD(totalGastosUsd, currency,
        dolarBlue: dolarBlue, btcPrice: btcPrice, fiatRates: fiatRates);
    final secondaryText = CurrencyFormatter.secondaryFromUSD(totalGastosUsd, currency,
        dolarBlue: dolarBlue, btcPrice: btcPrice, fiatRates: fiatRates);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'TOTAL GASTOS',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              CurrencySelector(color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            primaryText,
            style: const TextStyle(
              color: AppColors.danger,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            secondaryText,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: 'Fijos',
                  amount: totalFijos,
                  amountUsd: totalFijosUsd,
                  color: AppColors.info,
                  currency: currency,
                  dolarBlue: dolarBlue,
                  btcPrice: btcPrice,
                  fiatRates: fiatRates,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatChip(
                  label: 'Variables',
                  amount: totalVariables,
                  amountUsd: totalVariablesUsd,
                  color: AppColors.warning,
                  currency: currency,
                  dolarBlue: dolarBlue,
                  btcPrice: btcPrice,
                  fiatRates: fiatRates,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final double amount;
  final double amountUsd;
  final Color color;
  final String currency;
  final double dolarBlue;
  final double btcPrice;
  final Map<String, double> fiatRates;

  const _StatChip({
    required this.label,
    required this.amount,
    required this.amountUsd,
    required this.color,
    this.currency = 'USD',
    this.dolarBlue = 0,
    this.btcPrice = 0,
    this.fiatRates = const {},
  });

  @override
  Widget build(BuildContext context) {
    final primary = CurrencyFormatter.fromUSD(amountUsd, currency,
        dolarBlue: dolarBlue, btcPrice: btcPrice, fiatRates: fiatRates);
    final secondary = CurrencyFormatter.secondaryFromUSD(amountUsd, currency,
        dolarBlue: dolarBlue, btcPrice: btcPrice, fiatRates: fiatRates);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
          Text(primary,
              style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
          Text(secondary,
              style: TextStyle(color: color.withValues(alpha: 0.65), fontSize: 11)),
        ],
      ),
    );
  }
}

class _FijosVariablesPct extends ConsumerWidget {
  final double totalFijos;
  final double totalVariables;
  final double totalFijosUsd;
  final double totalVariablesUsd;

  const _FijosVariablesPct({
    required this.totalFijos,
    required this.totalVariables,
    required this.totalFijosUsd,
    required this.totalVariablesUsd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = totalFijos + totalVariables;
    if (total == 0) return const SizedBox.shrink();
    final pctFijos = totalFijos / total;
    final pctVariables = totalVariables / total;

    final currency = ref.watch(displayCurrencyProvider);
    final dolarBlue = ref.watch(dolarBlueVentaProvider);
    final btcPrice = ref.watch(btcPriceUSDProvider);
    final fiatRates = ref.watch(fiatRatesProvider).value ?? {};

    String fmt(double usd) => CurrencyFormatter.fromUSD(usd, currency,
        dolarBlue: dolarBlue, btcPrice: btcPrice, fiatRates: fiatRates);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('COMPOSICIÓN',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                Flexible(
                  flex: (pctFijos * 100).round().clamp(1, 99),
                  child: Container(height: 10, color: AppColors.info),
                ),
                Flexible(
                  flex: (pctVariables * 100).round().clamp(1, 99),
                  child: Container(height: 10, color: AppColors.warning),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ComposicionRow(
            color: AppColors.info,
            label: 'Fijos',
            pct: pctFijos,
            amount: fmt(totalFijosUsd),
          ),
          const SizedBox(height: 8),
          _ComposicionRow(
            color: AppColors.warning,
            label: 'Variables',
            pct: pctVariables,
            amount: fmt(totalVariablesUsd),
          ),
        ],
      ),
    );
  }
}

class _ComposicionRow extends StatelessWidget {
  final Color color;
  final String label;
  final double pct;
  final String amount;

  const _ComposicionRow({
    required this.color,
    required this.label,
    required this.pct,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        ),
        Text(
          '${(pct * 100).toStringAsFixed(1)}%',
          style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 12),
        Text(
          amount,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

enum _SortGasto {
  monto('Monto'),
  fecha('Fecha');

  const _SortGasto(this.label);
  final String label;
}

class _GastosList extends ConsumerStatefulWidget {
  final List<Gasto> gastos;

  const _GastosList({required this.gastos});

  @override
  ConsumerState<_GastosList> createState() => _GastosListState();
}

class _GastosListState extends ConsumerState<_GastosList> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  CategoriaGasto? _filterCategoria;
  _SortGasto? _sort;
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
    if (_filterCategoria != null) c++;
    if (_sort != null) c++;
    if (_fechaDesde != null || _fechaHasta != null) c++;
    return c;
  }

  List<Gasto> get _filtered {
    var list = widget.gastos.where((g) {
      if (_search.isNotEmpty &&
          !g.descripcion.toLowerCase().contains(_search.toLowerCase())) {
        return false;
      }
      if (_filterCategoria != null && g.categoria != _filterCategoria) return false;
      if (_fechaDesde != null && g.fecha.isBefore(_fechaDesde!)) return false;
      if (_fechaHasta != null &&
          g.fecha.isAfter(_fechaHasta!.add(const Duration(days: 1)))) return false;
      return true;
    }).toList();

    if (_sort != null) {
      list.sort((a, b) {
        double va, vb;
        switch (_sort!) {
          case _SortGasto.monto:
            va = a.monto; vb = b.monto;
          case _SortGasto.fecha:
            va = a.fecha.millisecondsSinceEpoch.toDouble();
            vb = b.fecha.millisecondsSinceEpoch.toDouble();
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
      builder: (_) => _GastoFilterSheet(
        initCategoria: _filterCategoria,
        initSort: _sort,
        initSortAsc: _sortAsc,
        initFechaDesde: _fechaDesde,
        initFechaHasta: _fechaHasta,
        onApply: (cat, sort, sortAsc, fechaD, fechaH) => setState(() {
          _filterCategoria = cat;
          _sort = sort;
          _sortAsc = sortAsc;
          _fechaDesde = fechaD;
          _fechaHasta = fechaH;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Buscar...',
                  prefixIcon: const Icon(Icons.search,
                      size: 18, color: AppColors.textSecondary),
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
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 12),
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
          ],
        ),
        const SizedBox(height: 4),
        if (filtered.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long_outlined,
                      size: 40, color: AppColors.textDisabled),
                  const SizedBox(height: 12),
                  Text('No hay gastos registrados',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.surfaceBorder),
              itemBuilder: (context, i) => GastoListTile(
                gasto: filtered[i],
                onDelete: () {
                  final g = filtered[i];
                  if (g.medioPagoId != null) {
                    ref
                        .read(inversionesNotifierProvider.notifier)
                        .ajustarMontoLiquidez(g.medioPagoId!, g.monto);
                  }
                  ref.read(gastosNotifierProvider.notifier).eliminar(g.id);
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _GastoFilterSheet extends StatefulWidget {
  final CategoriaGasto? initCategoria;
  final _SortGasto? initSort;
  final bool initSortAsc;
  final DateTime? initFechaDesde;
  final DateTime? initFechaHasta;
  final void Function(
    CategoriaGasto? categoria,
    _SortGasto? sort,
    bool sortAsc,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
  ) onApply;

  const _GastoFilterSheet({
    required this.initCategoria,
    required this.initSort,
    required this.initSortAsc,
    required this.initFechaDesde,
    required this.initFechaHasta,
    required this.onApply,
  });

  @override
  State<_GastoFilterSheet> createState() => _GastoFilterSheetState();
}

class _GastoFilterSheetState extends State<_GastoFilterSheet> {
  CategoriaGasto? _categoria;
  _SortGasto? _sort;
  bool _sortAsc = false;
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;

  @override
  void initState() {
    super.initState();
    _categoria = widget.initCategoria;
    _sort = widget.initSort;
    _sortAsc = widget.initSortAsc;
    _fechaDesde = widget.initFechaDesde;
    _fechaHasta = widget.initFechaHasta;
  }

  void _clear() => setState(() {
        _categoria = null;
        _sort = null;
        _sortAsc = false;
        _fechaDesde = null;
        _fechaHasta = null;
      });

  void _apply() {
    widget.onApply(_categoria, _sort, _sortAsc, _fechaDesde, _fechaHasta);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
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

            _GastoSectionLabel(label: 'Categoría'),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _GastoFilterChip(
                  label: 'Todas',
                  selected: _categoria == null,
                  onTap: () => setState(() => _categoria = null)),
              ...CategoriaGasto.values.map((c) => _GastoFilterChip(
                    label: '${c.emoji} ${c.label}',
                    selected: _categoria == c,
                    onTap: () => setState(
                        () => _categoria = _categoria == c ? null : c),
                  )),
            ]),
            const SizedBox(height: 20),

            _GastoSectionLabel(label: 'Fecha'),
            Row(children: [
              Expanded(
                  child: _GastoDateButton(
                label: 'Desde',
                date: _fechaDesde,
                onTap: () async {
                  final d = await showDatePicker(
                      context: context,
                      initialDate:
                          _fechaDesde ?? DateTime(DateTime.now().year, 1),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now());
                  if (d != null) setState(() => _fechaDesde = d);
                },
                onClear: _fechaDesde != null
                    ? () => setState(() => _fechaDesde = null)
                    : null,
                fmt: fmt,
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _GastoDateButton(
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
                fmt: fmt,
              )),
            ]),
            const SizedBox(height: 20),

            _GastoSectionLabel(label: 'Ordenar por'),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _GastoFilterChip(
                  label: 'Sin ordenar',
                  selected: _sort == null,
                  onTap: () => setState(() => _sort = null)),
              ..._SortGasto.values.map((s) => _GastoFilterChip(
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
                  selectedColor: AppColors.danger.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                      color: !_sortAsc
                          ? AppColors.danger
                          : AppColors.textSecondary,
                      fontSize: 12),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('↑ Menor primero'),
                  selected: _sortAsc,
                  onSelected: (_) => setState(() => _sortAsc = true),
                  selectedColor: AppColors.danger.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                      color: _sortAsc
                          ? AppColors.danger
                          : AppColors.textSecondary,
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
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GastoSectionLabel extends StatelessWidget {
  final String label;
  const _GastoSectionLabel({required this.label});
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

class _GastoFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GastoFilterChip(
      {required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.danger.withValues(alpha: 0.15)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color:
                  selected ? AppColors.danger : AppColors.surfaceBorder),
        ),
        child: Text(label,
            style: TextStyle(
                color:
                    selected ? AppColors.danger : AppColors.textSecondary,
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _GastoDateButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final DateFormat fmt;
  const _GastoDateButton(
      {required this.label,
      required this.date,
      required this.onTap,
      this.onClear,
      required this.fmt});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: date != null
              ? AppColors.danger.withValues(alpha: 0.08)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: date != null
                  ? AppColors.danger
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
                    date != null ? fmt.format(date!) : 'Seleccionar',
                    style: TextStyle(
                        fontSize: 12,
                        color: date != null
                            ? AppColors.danger
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
                    size: 14, color: AppColors.textDisabled))
          else
            const Icon(Icons.calendar_today_outlined,
                size: 14, color: AppColors.textDisabled),
        ]),
      ),
    );
  }
}

class _MesSelector extends ConsumerWidget {
  const _MesSelector();

  static const _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  Future<void> _abrirPicker(BuildContext context, WidgetRef ref, DateTime actual) async {
    final ahora = DateTime.now();
    DateTime selAnio = actual;
    DateTime? resultado;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Ir a mes', style: TextStyle(fontSize: 16)),
            content: SizedBox(
              width: 280,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Selector de año
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 20),
                        onPressed: selAnio.year > 2018
                            ? () => setDialogState(() => selAnio = DateTime(selAnio.year - 1, selAnio.month))
                            : null,
                      ),
                      Text('${selAnio.year}',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        onPressed: selAnio.year < ahora.year
                            ? () => setDialogState(() => selAnio = DateTime(selAnio.year + 1, selAnio.month))
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Grid de meses
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    childAspectRatio: 1.6,
                    children: List.generate(12, (i) {
                      final esFuturo = selAnio.year == ahora.year && i + 1 > ahora.month;
                      final esSeleccionado = selAnio.year == actual.year && i + 1 == actual.month;
                      return GestureDetector(
                        onTap: esFuturo ? null : () {
                          resultado = DateTime(selAnio.year, i + 1);
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: esSeleccionado
                                ? AppColors.danger
                                : esFuturo
                                    ? Colors.transparent
                                    : AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _meses[i].substring(0, 3),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: esSeleccionado ? FontWeight.w700 : FontWeight.normal,
                              color: esSeleccionado
                                  ? Colors.white
                                  : esFuturo
                                      ? AppColors.textDisabled
                                      : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  resultado = DateTime(ahora.year, ahora.month);
                  Navigator.pop(ctx);
                },
                child: const Text('Hoy', style: TextStyle(color: AppColors.danger)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          );
        },
      ),
    );

    if (resultado != null) {
      ref.read(mesSeleccionadoGastosProvider.notifier).state = resultado!;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesSeleccionadoGastosProvider);
    final ahora = DateTime.now();
    final esMesActual = mes.year == ahora.year && mes.month == ahora.month;
    final label = '${_meses[mes.month - 1]} ${mes.year}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, size: 20),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          onPressed: () => ref.read(mesSeleccionadoGastosProvider.notifier).state =
              DateTime(mes.year, mes.month - 1),
        ),
        GestureDetector(
          onTap: () => _abrirPicker(context, ref, mes),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: esMesActual ? null : AppColors.danger,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.arrow_drop_down,
                  size: 18,
                  color: esMesActual ? AppColors.textSecondary : AppColors.danger),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, size: 20),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          onPressed: esMesActual
              ? null
              : () => ref.read(mesSeleccionadoGastosProvider.notifier).state =
                  DateTime(mes.year, mes.month + 1),
        ),
      ],
    );
  }
}
