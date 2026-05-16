import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../market_data/providers/market_data_providers.dart';
import '../../data/currency_data.dart';
import '../../domain/inversion_models.dart';
import '../providers/inversiones_provider.dart';
import 'inversion_total_banner.dart';

const Color _negocioColor = Color(0xFF4CAF50);

enum _SortNegocio {
  monto('Monto'),
  fecha('Fecha');

  const _SortNegocio(this.label);
  final String label;
}

class NegocioTab extends ConsumerStatefulWidget {
  const NegocioTab({super.key});

  @override
  ConsumerState<NegocioTab> createState() => _NegocioTabState();
}

class _NegocioTabState extends ConsumerState<NegocioTab> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String? _filterMoneda;
  _SortNegocio? _sort;
  bool _sortAsc = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    int c = 0;
    if (_filterMoneda != null) c++;
    if (_sort != null) c++;
    return c;
  }

  List<NegocioPersonal> _apply(List<NegocioPersonal> source) {
    var list = source.where((n) {
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        if (!n.nombre.toLowerCase().contains(q) &&
            !n.descripcion.toLowerCase().contains(q)) return false;
      }
      if (_filterMoneda != null && n.moneda != _filterMoneda) return false;
      return true;
    }).toList();

    if (_sort != null) {
      list.sort((a, b) {
        double va, vb;
        switch (_sort!) {
          case _SortNegocio.monto:
            va = a.monto; vb = b.monto;
          case _SortNegocio.fecha:
            va = a.fechaAdquisicion.millisecondsSinceEpoch.toDouble();
            vb = b.fechaAdquisicion.millisecondsSinceEpoch.toDouble();
        }
        return _sortAsc ? va.compareTo(vb) : vb.compareTo(va);
      });
    }
    return list;
  }

  Future<void> _openFilters(BuildContext ctx, List<String> monedas) async {
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NegocioFilterSheet(
        availableMonedas: monedas,
        initMoneda: _filterMoneda,
        initSort: _sort,
        initSortAsc: _sortAsc,
        onApply: (moneda, sort, sortAsc) => setState(() {
          _filterMoneda = moneda;
          _sort = sort;
          _sortAsc = sortAsc;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final negocios = ref.watch(negociosPersonalesProvider);
    final filtered = _apply(negocios);
    final monedas = negocios.map((n) => n.moneda).toSet().toList()..sort();
    final dolarVenta = ref.watch(dolarProvider).value
            ?.where((d) => d.casa.toLowerCase() == 'blue')
            .map((d) => d.venta)
            .firstOrNull ??
        1050.0;
    final totalUSD = negocios.fold(
        0.0, (s, n) => s + monedaToUSD(n.monto, n.moneda, dolarVenta));

    return Column(
      children: [
        InversionTotalBanner(totalUSD: totalUSD, dolarVenta: dolarVenta, seccionKey: 'Negocios'),
        Row(
          children: [
            if (negocios.isNotEmpty)
              Text(
                '${negocios.length} negocio${negocios.length == 1 ? '' : 's'}',
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
                          ? _negocioColor
                          : AppColors.textSecondary),
                  tooltip: 'Filtros y orden',
                  onPressed: () => _openFilters(context, monedas),
                ),
                if (_activeFilterCount > 0)
                  Positioned(
                    right: 4, top: 4,
                    child: Container(
                      width: 16, height: 16,
                      decoration: const BoxDecoration(
                          color: _negocioColor, shape: BoxShape.circle),
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
                builder: (_) => const _NegocioSheet(),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Agregar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _negocioColor,
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
            hintText: 'Buscar por nombre o descripción...',
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

        if (_activeFilterCount > 0) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              if (_filterMoneda != null)
                _NegocioChip(
                    label: '💱 $_filterMoneda',
                    onRemove: () => setState(() => _filterMoneda = null)),
              if (_sort != null)
                _NegocioChip(
                    label: '${_sortAsc ? '↑' : '↓'} ${_sort!.label}',
                    onRemove: () => setState(() => _sort = null)),
              TextButton(
                onPressed: () => setState(() {
                  _filterMoneda = null;
                  _sort = null;
                }),
                child: const Text('Limpiar',
                    style: TextStyle(fontSize: 11, color: AppColors.danger)),
              ),
            ]),
          ),
          const SizedBox(height: 4),
        ],

        if (negocios.isEmpty)
          Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.store_outlined,
                  size: 40, color: AppColors.textDisabled),
              const SizedBox(height: 12),
              Text('No tenés negocios registrados',
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
                          _filterMoneda = null;
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
              itemBuilder: (_, i) => _NegocioCard(negocio: filtered[i]),
            ),
          ),
      ],
    );
  }
}

class _NegocioChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _NegocioChip({required this.label, required this.onRemove});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      decoration: BoxDecoration(
        color: _negocioColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _negocioColor.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: const TextStyle(
                color: _negocioColor, fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(width: 2),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.close, size: 13, color: _negocioColor),
        ),
      ]),
    );
  }
}

class _NegocioFilterSheet extends StatefulWidget {
  final List<String> availableMonedas;
  final String? initMoneda;
  final _SortNegocio? initSort;
  final bool initSortAsc;
  final void Function(String? moneda, _SortNegocio? sort, bool sortAsc) onApply;

  const _NegocioFilterSheet({
    required this.availableMonedas,
    required this.initMoneda,
    required this.initSort,
    required this.initSortAsc,
    required this.onApply,
  });

  @override
  State<_NegocioFilterSheet> createState() => _NegocioFilterSheetState();
}

class _NegocioFilterSheetState extends State<_NegocioFilterSheet> {
  String? _moneda;
  _SortNegocio? _sort;
  bool _sortAsc = false;

  @override
  void initState() {
    super.initState();
    _moneda = widget.initMoneda;
    _sort = widget.initSort;
    _sortAsc = widget.initSortAsc;
  }

  void _clear() => setState(() {
        _moneda = null;
        _sort = null;
        _sortAsc = false;
      });

  void _apply() {
    widget.onApply(_moneda, _sort, _sortAsc);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
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
                      style:
                          TextStyle(color: AppColors.danger, fontSize: 13))),
            ]),
            const SizedBox(height: 20),

            if (widget.availableMonedas.isNotEmpty) ...[
              _NegocioSectionLabel(label: 'Moneda'),
              Wrap(spacing: 8, runSpacing: 6, children: [
                _NegocioFilterChip(
                    label: 'Todas',
                    selected: _moneda == null,
                    onTap: () => setState(() => _moneda = null)),
                ...widget.availableMonedas.map((m) => _NegocioFilterChip(
                      label: m,
                      selected: _moneda == m,
                      onTap: () =>
                          setState(() => _moneda = _moneda == m ? null : m),
                    )),
              ]),
              const SizedBox(height: 20),
            ],

            _NegocioSectionLabel(label: 'Ordenar por'),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _NegocioFilterChip(
                  label: 'Sin ordenar',
                  selected: _sort == null,
                  onTap: () => setState(() => _sort = null)),
              ..._SortNegocio.values.map((s) => _NegocioFilterChip(
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
                  selectedColor: _negocioColor.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                      color: !_sortAsc
                          ? _negocioColor
                          : AppColors.textSecondary,
                      fontSize: 12),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('↑ Menor primero'),
                  selected: _sortAsc,
                  onSelected: (_) => setState(() => _sortAsc = true),
                  selectedColor: _negocioColor.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                      color: _sortAsc
                          ? _negocioColor
                          : AppColors.textSecondary,
                      fontSize: 12),
                ),
              ]),
            ],
            const SizedBox(height: 28),

            ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _negocioColor,
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

class _NegocioSectionLabel extends StatelessWidget {
  final String label;
  const _NegocioSectionLabel({required this.label});
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

class _NegocioFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NegocioFilterChip(
      {required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? _negocioColor.withValues(alpha: 0.15)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? _negocioColor : AppColors.surfaceBorder),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? _negocioColor : AppColors.textSecondary,
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _NegocioCard extends ConsumerWidget {
  final NegocioPersonal negocio;
  const _NegocioCard({required this.negocio});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = monedaInfo(negocio.moneda);
    final fmt = NumberFormat('#,##0.00', 'es_AR');

    String primaryAmount;
    if (negocio.moneda == 'ARS') {
      primaryAmount = CurrencyFormatter.compact(negocio.monto);
    } else if (negocio.moneda == 'USD') {
      primaryAmount = CurrencyFormatter.usd(negocio.monto);
    } else {
      primaryAmount = '${info.simbolo} ${fmt.format(negocio.monto)}';
    }

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _negocioColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Icon(Icons.store_outlined, color: _negocioColor, size: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(negocio.nombre, style: Theme.of(context).textTheme.titleMedium),
              Text(negocio.sector ?? negocio.descripcion,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(primaryAmount,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            Text(negocio.moneda,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            if (negocio.dividendoMensual != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _negocioColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '📈 ${negocio.frecuenciaDividendo!.label}',
                  style: const TextStyle(color: _negocioColor, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ]),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _NegocioSheet(negocio: negocio),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textDisabled),
            onPressed: () => ref.read(inversionesNotifierProvider.notifier).eliminarNegocio(negocio.id),
          ),
        ],
      ),
    );
  }
}

class _NegocioSheet extends ConsumerStatefulWidget {
  final NegocioPersonal? negocio;
  const _NegocioSheet({this.negocio});

  @override
  ConsumerState<_NegocioSheet> createState() => _NegocioSheetState();
}

class _NegocioSheetState extends ConsumerState<_NegocioSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _sectorCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  final _montoDivCtrl = TextEditingController();
  String _moneda = 'ARS';
  String _monedaDiv = 'ARS';
  DateTime _fecha = DateTime.now();
  bool _saving = false;
  bool _tieneDividendos = false;
  FrecuenciaDividendo _frecuencia = FrecuenciaDividendo.mensual;
  DateTime? _fechaDividendo;

  bool get _isEditing => widget.negocio != null;

  @override
  void initState() {
    super.initState();
    final n = widget.negocio;
    if (n != null) {
      _nombreCtrl.text = n.nombre;
      _descCtrl.text = n.descripcion;
      _sectorCtrl.text = n.sector ?? '';
      _montoCtrl.text = n.monto > 0 ? n.monto.toString() : '';
      _notasCtrl.text = n.notas ?? '';
      _moneda = n.moneda;
      _fecha = n.fechaAdquisicion;
      if (n.montoDividendo != null && n.montoDividendo! > 0) {
        _tieneDividendos = true;
        _montoDivCtrl.text = n.montoDividendo!.toString();
        _monedaDiv = n.monedaDivEfectiva;
        _frecuencia = n.frecuenciaDividendo ?? FrecuenciaDividendo.mensual;
        _fechaDividendo = n.fechaDividendo;
      }
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    _sectorCtrl.dispose();
    _montoCtrl.dispose();
    _notasCtrl.dispose();
    _montoDivCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final montoDiv = _tieneDividendos
        ? double.tryParse(_montoDivCtrl.text.replaceAll(',', '.'))
        : null;

    final negocio = NegocioPersonal(
      id: widget.negocio?.id,
      nombre: _nombreCtrl.text.trim(),
      descripcion: _descCtrl.text.trim(),
      monto: double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ?? 0,
      moneda: _moneda,
      fechaAdquisicion: _fecha,
      sector: _sectorCtrl.text.trim().isNotEmpty ? _sectorCtrl.text.trim() : null,
      notas: _notasCtrl.text.trim().isNotEmpty ? _notasCtrl.text.trim() : null,
      montoDividendo: montoDiv,
      monedaDividendo: _tieneDividendos ? _monedaDiv : null,
      frecuenciaDividendo: _tieneDividendos ? _frecuencia : null,
      fechaDividendo: _tieneDividendos ? _fechaDividendo : null,
    );

    final notifier = ref.read(inversionesNotifierProvider.notifier);
    if (_isEditing) {
      await notifier.actualizarNegocio(negocio);
    } else {
      await notifier.agregarNegocio(negocio);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85, maxChildSize: 0.95,
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
                  decoration: BoxDecoration(color: AppColors.surfaceBorder, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: AppSpacing.md),
              Text(_isEditing ? 'Editar Negocio' : 'Negocio Personal',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.lg),

              TextFormField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null),
              const SizedBox(height: AppSpacing.md),
              TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Descripción'),
                  maxLines: 2),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _sectorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Rubro (opcional)',
                  hintText: 'Ej: Tecnología, Gastronomía, Comercio...',
                ),
              ),
              const SizedBox(height: AppSpacing.md),

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

              ListTile(contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined, color: _negocioColor),
                  title: Text(DateFormat('dd/MM/yyyy').format(_fecha)),
                  subtitle: const Text('Fecha de adquisición'),
                  onTap: () async {
                    final d = await showDatePicker(context: context,
                        initialDate: _fecha, firstDate: DateTime(2000), lastDate: DateTime.now());
                    if (d != null) setState(() => _fecha = d);
                  }),
              const SizedBox(height: AppSpacing.md),

              TextFormField(
                controller: _notasCtrl,
                decoration: const InputDecoration(labelText: 'Notas (opcional)'),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Dividendos ──────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(children: [
                  SwitchListTile(
                    value: _tieneDividendos,
                    onChanged: (v) => setState(() => _tieneDividendos = v),
                    title: const Text('Dividendos', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Genera ingreso y liquidez automáticamente',
                        style: TextStyle(fontSize: 12)),
                    activeColor: _negocioColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  ),
                  if (_tieneDividendos) ...[
                    const Divider(height: 1, color: AppColors.surfaceBorder),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _montoDivCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Monto por período',
                                  isDense: true,
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) => setState(() {}),
                                validator: (v) {
                                  if (!_tieneDividendos) return null;
                                  if (v == null || v.isEmpty) return 'Requerido';
                                  if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Inválido';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<FrecuenciaDividendo>(
                                value: _frecuencia,
                                decoration: const InputDecoration(labelText: 'Frecuencia', isDense: true),
                                dropdownColor: AppColors.surfaceElevated,
                                isExpanded: true,
                                items: FrecuenciaDividendo.values
                                    .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
                                    .toList(),
                                onChanged: (v) => setState(() => _frecuencia = v!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: _monedaDiv,
                          decoration: const InputDecoration(
                            labelText: 'Moneda del dividendo',
                            isDense: true,
                          ),
                          dropdownColor: AppColors.surfaceElevated,
                          isExpanded: true,
                          items: kMonedas
                              .map((m) => DropdownMenuItem(
                                    value: m.codigo,
                                    child: Text('${m.codigo} ${m.simbolo}',
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _monedaDiv = v!),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const Icon(Icons.event_outlined, color: _negocioColor, size: 20),
                          title: Text(_fechaDividendo != null
                              ? DateFormat('dd/MM/yyyy').format(_fechaDividendo!)
                              : 'Sin fecha específica'),
                          subtitle: const Text('Fecha de dividendos (Indicar la fecha de comienzo del periodo por el cual se obtiene dividendos)', style: TextStyle(fontSize: 11)),
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _fechaDividendo ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (d != null) setState(() => _fechaDividendo = d);
                          },
                          trailing: _fechaDividendo != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16, color: AppColors.textDisabled),
                                  onPressed: () => setState(() => _fechaDividendo = null),
                                )
                              : null,
                        ),
                        Builder(builder: (ctx) {
                          final monto = double.tryParse(_montoDivCtrl.text.replaceAll(',', '.'));
                          if (monto == null || monto <= 0) return const SizedBox.shrink();
                          final mensual = monto / _frecuencia.mesesPorPeriodo;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '≈ ${mensual.toStringAsFixed(2)} $_monedaDiv/mes · Ingreso fijo ${_frecuencia.mesesPorPeriodo} ${_frecuencia.mesesPorPeriodo == 1 ? 'mes' : 'meses'}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          );
                        }),
                      ]),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: AppSpacing.lg),

              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: _negocioColor,
                    foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _saving ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isEditing ? 'Guardar Cambios' : 'Agregar',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
