import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../market_data/providers/market_data_providers.dart';
import '../../data/banco_data.dart';
import '../../data/currency_data.dart';
import '../../domain/inversion_models.dart';
import '../providers/inversiones_provider.dart';
import 'inversion_total_banner.dart';

enum _SortInstrumento {
  tna('TNA %'),
  monto('Monto invertido'),
  vencimiento('Vencimiento');

  const _SortInstrumento(this.label);
  final String label;
}

class InstrumentosTab extends ConsumerStatefulWidget {
  const InstrumentosTab({super.key});

  @override
  ConsumerState<InstrumentosTab> createState() => _InstrumentosTabState();
}

class _InstrumentosTabState extends ConsumerState<InstrumentosTab> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  _SortInstrumento? _sort;
  bool _sortAsc = false;
  TipoInstrumento? _filterTipo;
  DateTime? _vencDesde;
  DateTime? _vencHasta;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    int c = 0;
    if (_filterTipo != null) c++;
    if (_sort != null) c++;
    if (_vencDesde != null) c++;
    if (_vencHasta != null) c++;
    return c;
  }

  List<InstrumentoFinanciero> _apply(List<InstrumentoFinanciero> source) {
    var list = source.where((i) {
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        if (!i.entidad.toLowerCase().contains(q) &&
            !i.tipo.label.toLowerCase().contains(q)) return false;
      }
      if (_filterTipo != null && i.tipo != _filterTipo) return false;
      if (_vencDesde != null && i.fechaFin.isBefore(_vencDesde!)) return false;
      if (_vencHasta != null && i.fechaFin.isAfter(_vencHasta!)) return false;
      return true;
    }).toList();

    if (_sort != null) {
      list.sort((a, b) {
        double va, vb;
        switch (_sort!) {
          case _SortInstrumento.tna:
            va = a.tasaAnualPct; vb = b.tasaAnualPct;
          case _SortInstrumento.monto:
            va = a.monto; vb = b.monto;
          case _SortInstrumento.vencimiento:
            va = a.fechaFin.millisecondsSinceEpoch.toDouble();
            vb = b.fechaFin.millisecondsSinceEpoch.toDouble();
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
      builder: (_) => _InstrumentoFilterSheet(
        initTipo: _filterTipo,
        initSort: _sort,
        initSortAsc: _sortAsc,
        initVencDesde: _vencDesde,
        initVencHasta: _vencHasta,
        onApply: (tipo, sort, sortAsc, vencDesde, vencHasta) => setState(() {
          _filterTipo = tipo;
          _sort = sort;
          _sortAsc = sortAsc;
          _vencDesde = vencDesde;
          _vencHasta = vencHasta;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final instrumentos = ref.watch(instrumentosProvider);
    final valorAsync = ref.watch(valorInstrumentosUSDProvider);

    final dolarAsync = ref.watch(dolarProvider);
    final dolarVenta = dolarAsync.value
            ?.where((d) => d.casa.toLowerCase() == 'blue')
            .map((d) => d.venta)
            .firstOrNull ??
        1050.0;

    final totalUSD = valorAsync.value ?? 0.0;
    final totalARS = totalUSD * dolarVenta;
    final filtered = _apply(instrumentos);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InversionTotalBanner(
          totalUSD: valorAsync.hasValue ? totalUSD : null,
          dolarVenta: dolarVenta,
          seccionKey: 'Instrumentos',
        ),
        Row(
          children: [
            if (instrumentos.isNotEmpty)
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('USD: ${CurrencyFormatter.usd(totalUSD)}',
                    style: const TextStyle(
                        color: AppColors.success, fontWeight: FontWeight.w600)),
                Text('Equiv. ARS: ${CurrencyFormatter.compact(totalARS)}',
                    style: const TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500,
                        fontSize: 12)),
              ]),
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
                  onPressed: () => _openFilters(context),
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
                builder: (_) => const _InstrumentoSheet(),
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
            hintText: 'Buscar por entidad o tipo...',
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
                _InstChip(
                    label: '${_filterTipo!.emoji} ${_filterTipo!.label}',
                    onRemove: () => setState(() => _filterTipo = null)),
              if (_vencDesde != null)
                _InstChip(
                    label: 'Venc. desde ${DateFormat('dd/MM/yy').format(_vencDesde!)}',
                    onRemove: () => setState(() => _vencDesde = null)),
              if (_vencHasta != null)
                _InstChip(
                    label: 'Venc. hasta ${DateFormat('dd/MM/yy').format(_vencHasta!)}',
                    onRemove: () => setState(() => _vencHasta = null)),
              if (_sort != null)
                _InstChip(
                    label: '${_sortAsc ? '↑' : '↓'} ${_sort!.label}',
                    onRemove: () => setState(() => _sort = null)),
              TextButton(
                onPressed: () => setState(() {
                  _filterTipo = null;
                  _sort = null;
                  _vencDesde = null;
                  _vencHasta = null;
                }),
                child: const Text('Limpiar',
                    style: TextStyle(fontSize: 11, color: AppColors.danger)),
              ),
            ]),
          ),
          const SizedBox(height: 4),
        ],

        if (instrumentos.isEmpty)
          Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.account_balance_outlined,
                  size: 40, color: AppColors.textDisabled),
              const SizedBox(height: 12),
              Text('No tenés instrumentos financieros registrados',
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
        else
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) =>
                  _InstrumentoCard(instrumento: filtered[i], dolarVenta: dolarVenta),
            ),
          ),
      ],
    );
  }
}

class _InstChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _InstChip({required this.label, required this.onRemove});
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
                color: AppColors.info, fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(width: 2),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.close, size: 13, color: AppColors.info),
        ),
      ]),
    );
  }
}

class _InstrumentoFilterSheet extends StatefulWidget {
  final TipoInstrumento? initTipo;
  final _SortInstrumento? initSort;
  final bool initSortAsc;
  final DateTime? initVencDesde;
  final DateTime? initVencHasta;
  final void Function(TipoInstrumento? tipo, _SortInstrumento? sort, bool sortAsc,
      DateTime? vencDesde, DateTime? vencHasta) onApply;

  const _InstrumentoFilterSheet({
    required this.initTipo,
    required this.initSort,
    required this.initSortAsc,
    required this.initVencDesde,
    required this.initVencHasta,
    required this.onApply,
  });

  @override
  State<_InstrumentoFilterSheet> createState() => _InstrumentoFilterSheetState();
}

class _InstrumentoFilterSheetState extends State<_InstrumentoFilterSheet> {
  TipoInstrumento? _tipo;
  _SortInstrumento? _sort;
  bool _sortAsc = false;
  DateTime? _vencDesde;
  DateTime? _vencHasta;

  @override
  void initState() {
    super.initState();
    _tipo = widget.initTipo;
    _sort = widget.initSort;
    _sortAsc = widget.initSortAsc;
    _vencDesde = widget.initVencDesde;
    _vencHasta = widget.initVencHasta;
  }

  void _clear() => setState(() {
        _tipo = null;
        _sort = null;
        _sortAsc = false;
        _vencDesde = null;
        _vencHasta = null;
      });

  void _apply() {
    widget.onApply(_tipo, _sort, _sortAsc, _vencDesde, _vencHasta);
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

            _InstSectionLabel(label: 'Tipo de instrumento'),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _InstFilterChip(
                  label: 'Todos',
                  selected: _tipo == null,
                  onTap: () => setState(() => _tipo = null)),
              ...TipoInstrumento.values.map((t) => _InstFilterChip(
                    label: '${t.emoji} ${t.label}',
                    selected: _tipo == t,
                    onTap: () =>
                        setState(() => _tipo = _tipo == t ? null : t),
                  )),
            ]),
            const SizedBox(height: 20),

            _InstSectionLabel(label: 'Rango de vencimiento'),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month_outlined, size: 16),
                  label: Text(_vencDesde != null ? fmt.format(_vencDesde!) : 'Desde',
                      style: const TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _vencDesde != null ? AppColors.info : AppColors.textSecondary,
                    side: BorderSide(
                        color: _vencDesde != null ? AppColors.info : AppColors.surfaceBorder),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _vencDesde ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setState(() => _vencDesde = d);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month_outlined, size: 16),
                  label: Text(_vencHasta != null ? fmt.format(_vencHasta!) : 'Hasta',
                      style: const TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _vencHasta != null ? AppColors.info : AppColors.textSecondary,
                    side: BorderSide(
                        color: _vencHasta != null ? AppColors.info : AppColors.surfaceBorder),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _vencHasta ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setState(() => _vencHasta = d);
                  },
                ),
              ),
              if (_vencDesde != null || _vencHasta != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: AppColors.textDisabled),
                  onPressed: () => setState(() { _vencDesde = null; _vencHasta = null; }),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ]),
            const SizedBox(height: 20),

            _InstSectionLabel(label: 'Ordenar por'),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _InstFilterChip(
                  label: 'Sin ordenar',
                  selected: _sort == null,
                  onTap: () => setState(() => _sort = null)),
              ..._SortInstrumento.values.map((s) => _InstFilterChip(
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

class _InstSectionLabel extends StatelessWidget {
  final String label;
  const _InstSectionLabel({required this.label});
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

class _InstFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _InstFilterChip(
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

class _InstrumentoCard extends ConsumerWidget {
  final InstrumentoFinanciero instrumento;
  final double dolarVenta;
  const _InstrumentoCard({required this.instrumento, required this.dolarVenta});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat('#,##0.00', 'es_AR');

    String formatMonto(double amount, String moneda) {
      if (moneda == 'ARS') return CurrencyFormatter.compact(amount);
      if (moneda == 'USD') return CurrencyFormatter.usd(amount);
      return '${monedaInfo(moneda).simbolo} ${fmt.format(amount)}';
    }

    final montoDisplay = formatMonto(instrumento.monto, instrumento.moneda);
    final totalDisplay = formatMonto(instrumento.montoTotal, instrumento.moneda);
    final interesesDisplay = formatMonto(instrumento.interesesGanados, instrumento.moneda);
    final fechaFin = DateFormat('dd/MM/yyyy').format(instrumento.fechaFin);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(instrumento.tipo.emoji, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(instrumento.tipo.label,
                        style: Theme.of(context).textTheme.titleMedium),
                    Row(
                      children: [
                        if (instrumento.entidadUrl.isNotEmpty) ...[
                          SizedBox(
                            width: 16, height: 16,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: Image.network(
                                'https://www.google.com/s2/favicons?sz=32&domain=${Uri.parse(instrumento.entidadUrl).host}',
                                width: 16, height: 16,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.account_balance_outlined, size: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(instrumento.entidad,
                              style: Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(montoDisplay,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('+$interesesDisplay',
                      style: const TextStyle(color: AppColors.success, fontSize: 11)),
                  Text('Total: $totalDisplay',
                      style: const TextStyle(
                          color: AppColors.info, fontWeight: FontWeight.w600, fontSize: 12)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _InstrumentoSheet(instrumento: instrumento),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textDisabled),
                onPressed: () => ref
                    .read(inversionesNotifierProvider.notifier)
                    .eliminarInstrumento(instrumento.id),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('Vence: $fechaFin',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              const SizedBox(width: 12),
              const Icon(Icons.percent, size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('TNA ${instrumento.tasaAnualPct.toStringAsFixed(1)}%',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              const SizedBox(width: 4),
              Text('(${instrumento.tipoInteres == TipoInteres.compuesto ? "comp." : "simple"})',
                  style: const TextStyle(color: AppColors.textDisabled, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Bottom Sheet ────────────────────────────────────────────────────────────

class _InstrumentoSheet extends ConsumerStatefulWidget {
  final InstrumentoFinanciero? instrumento;
  const _InstrumentoSheet({this.instrumento});

  @override
  ConsumerState<_InstrumentoSheet> createState() => _InstrumentoSheetState();
}

class _InstrumentoSheetState extends ConsumerState<_InstrumentoSheet> {
  final _formKey = GlobalKey<FormState>();
  final _montoCtrl = TextEditingController();
  final _entidadCustomCtrl = TextEditingController();
  final _tasaCtrl = TextEditingController();
  final _duracionCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  TipoInstrumento _tipo = TipoInstrumento.plazoFijo;
  String _moneda = 'ARS';
  BancoInfo? _banco;
  DateTime _fechaInicio = DateTime.now();
  TipoInteres _tipoInteres = TipoInteres.simple;
  UnidadDuracion _unidadDuracion = UnidadDuracion.dias;
  bool _saving = false;

  // Computed display values
  String _fechaFinDisplay = '';
  String _montoTotalDisplay = '';

  bool get _isEditing => widget.instrumento != null;

  @override
  void initState() {
    super.initState();
    final inst = widget.instrumento;
    if (inst != null) {
      _tipo = inst.tipo;
      _montoCtrl.text = inst.monto > 0 ? inst.monto.toString() : '';
      _moneda = inst.moneda;
      _fechaInicio = inst.fechaInicio;
      _tipoInteres = inst.tipoInteres;
      _tasaCtrl.text = inst.tasaAnualPct > 0 ? inst.tasaAnualPct.toString() : '';
      _duracionCtrl.text = inst.duracion > 0 ? inst.duracion.toString() : '';
      _unidadDuracion = inst.unidadDuracion;
      if (inst.descripcion != null) _descCtrl.text = inst.descripcion!;
      if (inst.notas != null) _notasCtrl.text = inst.notas!;

      // Try to find matching bank
      try {
        _banco = kBancos.firstWhere(
          (b) => b.nombre == inst.entidad,
        );
        if (_banco!.url != inst.entidadUrl) {
          _entidadCustomCtrl.text = inst.entidad;
          _banco = null;
        }
      } catch (_) {
        _entidadCustomCtrl.text = inst.entidad;
      }
    } else {
      _banco = kBancos.first;
    }

    _montoCtrl.addListener(_recalcular);
    _tasaCtrl.addListener(_recalcular);
    _duracionCtrl.addListener(_recalcular);
    _recalcular();
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _entidadCustomCtrl.dispose();
    _tasaCtrl.dispose();
    _duracionCtrl.dispose();
    _descCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  void _recalcular() {
    final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ?? 0;
    final tasa = double.tryParse(_tasaCtrl.text.replaceAll(',', '.')) ?? 0;
    final duracion = double.tryParse(_duracionCtrl.text.replaceAll(',', '.')) ?? 0;

    if (monto <= 0 || tasa <= 0 || duracion <= 0) {
      setState(() {
        _fechaFinDisplay = '';
        _montoTotalDisplay = '';
      });
      return;
    }

    final tempInst = InstrumentoFinanciero(
      tipo: _tipo,
      monto: monto,
      moneda: _moneda,
      entidad: '',
      fechaInicio: _fechaInicio,
      tipoInteres: _tipoInteres,
      tasaAnualPct: tasa,
      duracion: duracion,
      unidadDuracion: _unidadDuracion,
    );

    final fechaFin = DateFormat('dd/MM/yyyy').format(tempInst.fechaFin);
    String montoTotal;
    if (_moneda == 'ARS') {
      montoTotal = CurrencyFormatter.compact(tempInst.montoTotal);
    } else if (_moneda == 'USD') {
      montoTotal = CurrencyFormatter.usd(tempInst.montoTotal);
    } else {
      final fmt = NumberFormat('#,##0.00', 'es_AR');
      montoTotal = '${monedaInfo(_moneda).simbolo} ${fmt.format(tempInst.montoTotal)}';
    }

    setState(() {
      _fechaFinDisplay = fechaFin;
      _montoTotalDisplay = montoTotal;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final entidad = _banco?.nombre ?? _entidadCustomCtrl.text.trim();
    final entidadUrl = _banco?.url ?? '';

    final inst = InstrumentoFinanciero(
      id: widget.instrumento?.id,
      tipo: _tipo,
      monto: double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ?? 0,
      moneda: _moneda,
      entidad: entidad,
      entidadUrl: entidadUrl,
      fechaInicio: _fechaInicio,
      tipoInteres: _tipoInteres,
      tasaAnualPct: double.tryParse(_tasaCtrl.text.replaceAll(',', '.')) ?? 0,
      duracion: double.tryParse(_duracionCtrl.text.replaceAll(',', '.')) ?? 0,
      unidadDuracion: _unidadDuracion,
      descripcion: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      notas: _notasCtrl.text.trim().isNotEmpty ? _notasCtrl.text.trim() : null,
    );

    await ref.read(inversionesNotifierProvider.notifier).agregarInstrumento(inst);
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
              Text(_isEditing ? 'Editar Instrumento' : 'Agregar Instrumento',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.lg),

              // Tipo de instrumento
              DropdownButtonFormField<TipoInstrumento>(
                value: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo de instrumento'),
                dropdownColor: AppColors.surfaceElevated,
                items: TipoInstrumento.values
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

              // Banco / Entidad dropdown
              _BancoDropdown(
                value: _banco,
                onChanged: (b) => setState(() {
                  _banco = b;
                  if (b != null && b.url.isNotEmpty) {
                    _entidadCustomCtrl.clear();
                  }
                }),
              ),
              if (_banco != null && _banco!.url.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(Icons.link, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(_banco!.url,
                          style: const TextStyle(color: AppColors.info, fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => launchUrl(Uri.parse(_banco!.url),
                          mode: LaunchMode.externalApplication),
                      child: const Icon(Icons.open_in_new, size: 14, color: AppColors.info),
                    ),
                  ],
                ),
              ],
              if (_banco == null || _banco!.url.isEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _entidadCustomCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre de entidad'),
                  validator: (v) {
                    if (_banco == null && (v == null || v.isEmpty)) return 'Requerido';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.md),

              // Fecha inicio
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined, color: AppColors.info),
                title: Text(DateFormat('dd/MM/yyyy').format(_fechaInicio)),
                subtitle: const Text('Fecha de inicio'),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _fechaInicio,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) {
                    setState(() => _fechaInicio = d);
                    _recalcular();
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Tipo de interés toggle
              Text('Tipo de interés', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: AppSpacing.xs),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Row(
                  children: [
                    _InteresOption(
                      label: 'Simple',
                      selected: _tipoInteres == TipoInteres.simple,
                      onTap: () {
                        setState(() => _tipoInteres = TipoInteres.simple);
                        _recalcular();
                      },
                      isLeft: true,
                    ),
                    _InteresOption(
                      label: 'Compuesto',
                      selected: _tipoInteres == TipoInteres.compuesto,
                      onTap: () {
                        setState(() => _tipoInteres = TipoInteres.compuesto);
                        _recalcular();
                      },
                      isLeft: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Tasa anual
              TextFormField(
                controller: _tasaCtrl,
                decoration: const InputDecoration(
                    labelText: 'Tasa anual (TNA %)', suffixText: '%'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Inválido';
                  return null;
                },
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

              // Fecha fin (read-only display)
              if (_fechaFinDisplay.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available, size: 16, color: AppColors.info),
                      const SizedBox(width: 8),
                      Text('Vencimiento: $_fechaFinDisplay',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              // Monto total (read-only display)
              if (_montoTotalDisplay.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                    border: Border.all(color: AppColors.info.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.trending_up, size: 16, color: AppColors.info),
                      const SizedBox(width: 8),
                      Text('Monto total al vencer: $_montoTotalDisplay',
                          style: const TextStyle(
                              color: AppColors.info, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Descripción
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.lg),

              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.info,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isEditing ? 'Guardar Cambios' : 'Agregar Instrumento',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Banco Dropdown ──────────────────────────────────────────────────────────

class _BancoDropdown extends StatelessWidget {
  final BancoInfo? value;
  final ValueChanged<BancoInfo?> onChanged;

  const _BancoDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<BancoInfo>(
      value: value,
      decoration: const InputDecoration(labelText: 'Banco / Entidad'),
      dropdownColor: AppColors.surfaceElevated,
      isExpanded: true,
      items: kBancos.map((b) {
        return DropdownMenuItem(
          value: b,
          child: Row(
            children: [
              if (b.url.isNotEmpty)
                SizedBox(
                  width: 20, height: 20,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Image.network(
                      b.faviconUrl,
                      width: 20, height: 20,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => CircleAvatar(
                        radius: 10,
                        backgroundColor: AppColors.info.withOpacity(0.2),
                        child: Text(b.initials,
                            style: const TextStyle(fontSize: 7, color: AppColors.info,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                )
              else
                const Icon(Icons.account_balance_outlined, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Flexible(child: Text(b.nombre, overflow: TextOverflow.ellipsis)),
            ],
          ),
        );
      }).toList(),
      onChanged: (v) => onChanged(v),
    );
  }
}

// ─── Interés Toggle Option ───────────────────────────────────────────────────

class _InteresOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isLeft;

  const _InteresOption({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.info.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isLeft ? 9 : 0),
              bottomLeft: Radius.circular(isLeft ? 9 : 0),
              topRight: Radius.circular(isLeft ? 0 : 9),
              bottomRight: Radius.circular(isLeft ? 0 : 9),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.info : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
