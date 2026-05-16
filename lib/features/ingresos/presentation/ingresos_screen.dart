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
import '../../inversiones/data/currency_data.dart';
import '../../market_data/providers/market_data_providers.dart';
import '../../inversiones/presentation/providers/inversiones_provider.dart';
import '../domain/ingreso.dart';
import 'providers/ingresos_provider.dart';
import 'widgets/add_ingreso_sheet.dart';
import 'widgets/importar_ingresos_page.dart';
import 'widgets/ingreso_list_tile.dart';
import 'widgets/ingresos_anos_chart.dart';
import 'widgets/ingresos_line_chart.dart';

class IngresosScreen extends ConsumerStatefulWidget {
  const IngresosScreen({super.key});

  @override
  ConsumerState<IngresosScreen> createState() => _IngresosScreenState();
}

enum _SortIngreso {
  monto('Monto'),
  fecha('Fecha');

  const _SortIngreso(this.label);
  final String label;
}

class _IngresosScreenState extends ConsumerState<IngresosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _monedaPasivo = 'USD';

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

  void _showImportarIngresos() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ImportarIngresosPage()),
    );
  }

  void _showAddIngreso() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddIngresoSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalIngresos = ref.watch(totalIngresosMesProvider);
    final dolarBlue = ref.watch(dolarBlueVentaProvider);
    final totalUSD = dolarBlue > 0 ? totalIngresos / dolarBlue : 0.0;
    final currency = ref.watch(displayCurrencyProvider);
    final btcPrice = ref.watch(btcPriceUSDProvider);
    final fiatRates = ref.watch(fiatRatesProvider).value ?? {};
    final fijos = ref.watch(ingresosFijosProvider);
    final variables = ref.watch(ingresosVariablesProvider);
    final totalFijosArs = ref.watch(totalIngresosFijosArsProvider);
    final totalVariablesArs = ref.watch(totalIngresosVariablesArsProvider);
    final totalFijosUsd = ref.watch(totalIngresosFijosUsdProvider);
    final totalVariablesUsd = ref.watch(totalIngresosVariablesUsdProvider);
    final historial = ref.watch(historialIngresosProvider);
    final historial10Anos = ref.watch(historial10AnosIngresosProvider);
    final pasivoData = ref.watch(ingresosPasivosProvider);
    final porCategoria = ref.watch(ingresosPorCategoriaProvider);

    return Scaffold(
      appBar: AppBar(
        title: _MesSelector(),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined),
            tooltip: 'Importar con IA',
            onPressed: _showImportarIngresos,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddIngreso,
        backgroundColor: AppColors.success,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Resumen ──────────────────────────────────────────────
                AppCard(
                  gradient: AppColors.successGradient,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Text(
                          'TOTAL INGRESOS',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                        const Spacer(),
                        const CurrencySelector(),
                      ]),
                      const SizedBox(height: 6),
                      Text(
                        CurrencyFormatter.fromUSD(totalUSD, currency,
                            dolarBlue: dolarBlue, btcPrice: btcPrice, fiatRates: fiatRates),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.secondaryFromUSD(totalUSD, currency,
                            dolarBlue: dolarBlue, btcPrice: btcPrice, fiatRates: fiatRates),
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _Chip(
                            label: 'Fijos',
                            count: fijos.length,
                            amount: totalFijosArs,
                            amountUsd: totalFijosUsd,
                            currency: currency,
                            dolarBlue: dolarBlue,
                            btcPrice: btcPrice,
                            fiatRates: fiatRates,
                          ),
                          const SizedBox(width: 8),
                          _Chip(
                            label: 'Variables',
                            count: variables.length,
                            amount: totalVariablesArs,
                            amountUsd: totalVariablesUsd,
                            currency: currency,
                            dolarBlue: dolarBlue,
                            btcPrice: btcPrice,
                            fiatRates: fiatRates,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sectionSpacing),

                // ── Ingresos pasivos ─────────────────────────────────────
                if (pasivoData.mensual > 0) ...[
                  const SectionHeader(
                    title: 'INGRESOS PASIVOS',
                    subtitle: 'Alquileres y dividendos',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text('Mostrar en:',
                                style: TextStyle(
                                    color: AppColors.textSecondary, fontSize: 12)),
                            const SizedBox(width: 8),
                            DropdownButton<String>(
                              value: _monedaPasivo,
                              isDense: true,
                              underline: const SizedBox(),
                              style: const TextStyle(
                                  color: AppColors.success,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                              dropdownColor: AppColors.surfaceElevated,
                              selectedItemBuilder: (_) => kMonedas
                                  .map((m) => DropdownMenuItem(
                                        value: m.codigo,
                                        child: Text(m.codigo),
                                      ))
                                  .toList(),
                              items: kMonedas
                                  .map((m) => DropdownMenuItem(
                                        value: m.codigo,
                                        child: Text('${m.codigo}  ${m.nombre}',
                                            style: const TextStyle(fontSize: 13)),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _monedaPasivo = v!),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Builder(builder: (_) {
                          final fmt = NumberFormat('#,##0', 'es_AR');
                          String formatP(double arsAmount) {
                            if (_monedaPasivo == 'ARS') {
                              return CurrencyFormatter.compact(arsAmount);
                            }
                            if (dolarBlue <= 0) {
                              return CurrencyFormatter.compact(arsAmount);
                            }
                            final usd = arsAmount / dolarBlue;
                            if (_monedaPasivo == 'USD') {
                              return CurrencyFormatter.usd(usd);
                            }
                            final info = kMonedas.firstWhere(
                                (m) => m.codigo == _monedaPasivo,
                                orElse: () => kMonedas.first);
                            if (info.approxUSD <= 0) return CurrencyFormatter.usd(usd);
                            final converted = usd / info.approxUSD;
                            return '${info.simbolo} ${fmt.format(converted)}';
                          }

                          return Row(children: [
                            Expanded(
                              child: _PasivoStat(
                                label: 'Mensual',
                                formattedAmount: formatP(pasivoData.mensual),
                                icon: Icons.calendar_month_outlined,
                              ),
                            ),
                            Container(width: 1, height: 40, color: AppColors.surfaceBorder),
                            Expanded(
                              child: _PasivoStat(
                                label: 'Anual estimado',
                                formattedAmount: formatP(pasivoData.anual),
                                icon: Icons.calendar_today_outlined,
                              ),
                            ),
                          ]);
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sectionSpacing),
                ],

                // ── Composición por categoría ────────────────────────────
                if (porCategoria.isNotEmpty) ...[
                  const SectionHeader(
                    title: 'COMPOSICIÓN',
                    subtitle: 'Por categoría este mes',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(child: _ComposicionCategoria(
                    porCategoria: porCategoria,
                    total: totalIngresos,
                    dolarBlue: dolarBlue,
                  )),
                  const SizedBox(height: AppSpacing.sectionSpacing),
                ],

                // ── Evolución 12 meses ───────────────────────────────────
                const SectionHeader(
                  title: 'EVOLUCIÓN',
                  subtitle: 'Últimos 12 meses',
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: IngresosLineChart(historial: historial),
                ),
                const SizedBox(height: AppSpacing.sectionSpacing),

                // ── Evolución 10 años ────────────────────────────────────
                const SectionHeader(
                  title: 'ÚLTIMOS 10 AÑOS',
                  subtitle: 'Total anual',
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(child: IngresosAnosChart(data: historial10Anos)),
                const SizedBox(height: AppSpacing.sectionSpacing),

                // ── Lista tabs ───────────────────────────────────────────
                const SectionHeader(title: 'DETALLE'),
                const SizedBox(height: AppSpacing.sm),
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.success,
                  labelColor: AppColors.success,
                  unselectedLabelColor: AppColors.textSecondary,
                  dividerColor: AppColors.surfaceBorder,
                  tabs: [
                    Tab(text: 'Fijos (${fijos.length})'),
                    Tab(text: 'Variables (${variables.length})'),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 440,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _IngresosList(ingresos: fijos),
                      _IngresosList(ingresos: variables),
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

class _Chip extends StatelessWidget {
  final String label;
  final int count;
  final double amount;
  final double amountUsd;
  final String currency;
  final double dolarBlue;
  final double btcPrice;
  final Map<String, double> fiatRates;

  const _Chip({
    required this.label,
    required this.count,
    required this.amount,
    required this.amountUsd,
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
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label ($count)',
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 2),
          Text(primary,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          Text(secondary,
              style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }
}

class _PasivoStat extends StatelessWidget {
  final String label;
  final String formattedAmount;
  final IconData icon;

  const _PasivoStat(
      {required this.label, required this.formattedAmount, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 13, color: AppColors.success),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ]),
          const SizedBox(height: 4),
          Text(formattedAmount,
              style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ComposicionCategoria extends ConsumerWidget {
  final Map<CategoriaIngreso, double> porCategoria;
  final double total;
  final double dolarBlue;

  const _ComposicionCategoria({
    required this.porCategoria,
    required this.total,
    required this.dolarBlue,
  });

  static const _colors = [
    AppColors.success,
    AppColors.primary,
    AppColors.warning,
    Color(0xFF9C6ADE),
    Color(0xFF0097A7),
    Color(0xFFFF7043),
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(displayCurrencyProvider);
    final btcPrice = ref.watch(btcPriceUSDProvider);
    final fiatRates = ref.watch(fiatRatesProvider).value ?? {};

    String toFmt(double ars) {
      final usd = dolarBlue > 0 ? ars / dolarBlue : 0.0;
      return CurrencyFormatter.fromUSD(usd, currency,
          dolarBlue: dolarBlue, btcPrice: btcPrice, fiatRates: fiatRates);
    }

    final sorted = porCategoria.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('COMPOSICIÓN',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8)),
            ),
            CurrencySelector(color: AppColors.textSecondary),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: LayoutBuilder(builder: (_, constraints) {
              double offset = 0;
              return Stack(
                children: sorted.asMap().entries.map((e) {
                  final pct = total > 0 ? e.value.value / total : 0.0;
                  final color = _colors[e.key % _colors.length];
                  final bar = Positioned(
                    left: offset * constraints.maxWidth,
                    width: pct * constraints.maxWidth,
                    top: 0, bottom: 0,
                    child: Container(color: color),
                  );
                  offset += pct;
                  return bar;
                }).toList(),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),
        ...sorted.asMap().entries.map((e) {
          final cat = e.value.key;
          final amount = e.value.value;
          final pct = total > 0 ? (amount / total * 100) : 0.0;
          final color = _colors[e.key % _colors.length];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(width: 10, height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(cat.emoji, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(cat.label,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                ),
                Text('${pct.toStringAsFixed(1)}%',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(width: 8),
                Text(toFmt(amount),
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _IngresosList extends ConsumerStatefulWidget {
  final List<Ingreso> ingresos;

  const _IngresosList({required this.ingresos});

  @override
  ConsumerState<_IngresosList> createState() => _IngresosListState();
}

class _IngresosListState extends ConsumerState<_IngresosList> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  _SortIngreso? _sort;
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
    if (_sort != null) c++;
    if (_fechaDesde != null || _fechaHasta != null) c++;
    return c;
  }

  List<Ingreso> get _filtered {
    final dolar = ref.watch(dolarBlueVentaProvider);
    double montoARS(Ingreso i) => i.esUSD ? i.monto * dolar : i.monto;

    var list = widget.ingresos.where((i) {
      if (_search.isNotEmpty &&
          !i.descripcion.toLowerCase().contains(_search.toLowerCase())) return false;
      if (_fechaDesde != null && i.fecha.isBefore(_fechaDesde!)) return false;
      if (_fechaHasta != null &&
          i.fecha.isAfter(_fechaHasta!.add(const Duration(days: 1)))) return false;
      return true;
    }).toList();

    if (_sort != null) {
      list.sort((a, b) {
        double va, vb;
        switch (_sort!) {
          case _SortIngreso.monto:
            va = montoARS(a); vb = montoARS(b);
          case _SortIngreso.fecha:
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
      builder: (_) => _IngresoFilterSheet(
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
                          ? AppColors.success
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
                          color: AppColors.success, shape: BoxShape.circle),
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
                  const Icon(Icons.monetization_on_outlined,
                      size: 40, color: AppColors.textDisabled),
                  const SizedBox(height: 12),
                  Text(
                    'No hay ingresos registrados',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
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
              itemBuilder: (context, i) => IngresoListTile(
                ingreso: filtered[i],
                onDelete: () {
                  final ing = filtered[i];
                  if (ing.liquidezDestinoId != null) {
                    ref
                        .read(inversionesNotifierProvider.notifier)
                        .ajustarMontoLiquidez(ing.liquidezDestinoId!, -ing.monto);
                  }
                  ref.read(ingresosNotifierProvider.notifier).eliminar(ing.id);
                },
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Filter sheet for ingresos ────────────────────────────────────────────────

class _IngresoFilterSheet extends StatefulWidget {
  final DateTime? initFechaDesde;
  final DateTime? initFechaHasta;
  final _SortIngreso? initSort;
  final bool initSortAsc;
  final void Function(
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    _SortIngreso? sort,
    bool sortAsc,
  ) onApply;

  const _IngresoFilterSheet({
    required this.initFechaDesde,
    required this.initFechaHasta,
    required this.initSort,
    required this.initSortAsc,
    required this.onApply,
  });

  @override
  State<_IngresoFilterSheet> createState() => _IngresoFilterSheetState();
}

class _IngresoFilterSheetState extends State<_IngresoFilterSheet> {
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  _SortIngreso? _sort;
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
      initialChildSize: 0.6,
      maxChildSize: 0.9,
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

            // ── Fecha ─────────────────────────────────────────────────
            _IngSectionLabel(label: 'Fecha del ingreso'),
            Row(children: [
              Expanded(
                  child: _IngDateButton(
                label: 'Desde',
                date: _fechaDesde,
                onTap: () async {
                  final d = await showDatePicker(
                      context: context,
                      initialDate: _fechaDesde ?? DateTime(DateTime.now().year, 1),
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
                  child: _IngDateButton(
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
            _IngSectionLabel(label: 'Ordenar por'),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _IngFilterChip(
                  label: 'Sin ordenar',
                  selected: _sort == null,
                  onTap: () => setState(() => _sort = null)),
              ..._SortIngreso.values.map((s) => _IngFilterChip(
                    label: s.label,
                    selected: _sort == s,
                    onTap: () => setState(() => _sort = _sort == s ? null : s),
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
                  selectedColor: AppColors.success.withOpacity(0.2),
                  labelStyle: TextStyle(
                      color: !_sortAsc ? AppColors.success : AppColors.textSecondary,
                      fontSize: 12),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('↑ Menor primero'),
                  selected: _sortAsc,
                  onSelected: (_) => setState(() => _sortAsc = true),
                  selectedColor: AppColors.success.withOpacity(0.2),
                  labelStyle: TextStyle(
                      color: _sortAsc ? AppColors.success : AppColors.textSecondary,
                      fontSize: 12),
                ),
              ]),
            ],
            const SizedBox(height: 28),

            ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
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

class _IngSectionLabel extends StatelessWidget {
  final String label;
  const _IngSectionLabel({required this.label});

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

class _IngFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _IngFilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.success.withOpacity(0.15)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.success : AppColors.surfaceBorder),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? AppColors.success : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _IngDateButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _IngDateButton(
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
              ? AppColors.success.withOpacity(0.08)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color:
                  date != null ? AppColors.success : AppColors.surfaceBorder),
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
                    color:
                        date != null ? AppColors.success : AppColors.textDisabled,
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

// ─── Selector de mes ──────────────────────────────────────────────────────────

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
                                ? AppColors.success
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
                child: const Text('Hoy', style: TextStyle(color: AppColors.success)),
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
      ref.read(mesSeleccionadoIngresosProvider.notifier).state = resultado!;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesSeleccionadoIngresosProvider);
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
          onPressed: () => ref.read(mesSeleccionadoIngresosProvider.notifier).state =
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
                  color: esMesActual ? null : AppColors.success,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.arrow_drop_down,
                  size: 18,
                  color: esMesActual ? AppColors.textSecondary : AppColors.success),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, size: 20),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          onPressed: esMesActual
              ? null
              : () => ref.read(mesSeleccionadoIngresosProvider.notifier).state =
                  DateTime(mes.year, mes.month + 1),
        ),
      ],
    );
  }
}
