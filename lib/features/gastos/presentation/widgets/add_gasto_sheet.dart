import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../inversiones/domain/inversion_models.dart';
import '../../../inversiones/presentation/providers/inversiones_provider.dart';
import '../../../market_data/providers/market_data_providers.dart';
import '../../domain/gasto.dart';
import '../providers/gastos_provider.dart';

class AddGastoSheet extends ConsumerStatefulWidget {
  final Gasto? gasto;
  const AddGastoSheet({super.key, this.gasto});

  @override
  ConsumerState<AddGastoSheet> createState() => _AddGastoSheetState();
}

class _AddGastoSheetState extends ConsumerState<AddGastoSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionController = TextEditingController();
  final _montoController = TextEditingController();
  CategoriaGasto _categoria = CategoriaGasto.otros;
  String? _subcategoria;
  TipoGasto _tipo = TipoGasto.variable;
  DateTime _fecha = DateTime.now();
  bool _saving = false;
  bool _esUSD = false;
  String? _medioPagoId;

  bool get _isEditing => widget.gasto != null;

  // Duración de gasto fijo: null = indefinido
  int? _duracionMeses;
  String _duracionUnidad = 'meses';
  int _duracionValor = 1;

  @override
  void initState() {
    super.initState();
    final g = widget.gasto;
    if (g != null) {
      _descripcionController.text = g.descripcion;
      _montoController.text = g.monto.toString();
      _categoria = g.categoria;
      _subcategoria = g.subcategoria;
      _tipo = g.tipo;
      _fecha = g.fecha;
      _esUSD = g.esUSD;
      _medioPagoId = g.medioPagoId;
      if (g.duracionMeses != null) {
        _duracionMeses = g.duracionMeses;
        if (g.duracionMeses! % 12 == 0) {
          _duracionUnidad = 'anos';
          _duracionValor = g.duracionMeses! ~/ 12;
        } else {
          _duracionUnidad = 'meses';
          _duracionValor = g.duracionMeses!;
        }
      }
    }
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final monto = double.tryParse(
          _montoController.text.replaceAll(',', '.'),
        ) ??
        0;

    final gasto = Gasto(
      id: widget.gasto?.id,
      descripcion: _descripcionController.text.trim(),
      monto: monto,
      esUSD: _esUSD,
      categoria: _categoria,
      subcategoria: _subcategoria,
      tipo: _tipo,
      fecha: _fecha,
      recurrente: _tipo == TipoGasto.fijo,
      duracionMeses: _tipo == TipoGasto.fijo ? _duracionMeses : null,
      medioPagoId: _medioPagoId,
    );

    final invNotifier = ref.read(inversionesNotifierProvider.notifier);

    if (_isEditing) {
      // Restaurar saldo anterior
      final oldMedioPagoId = widget.gasto?.medioPagoId;
      if (oldMedioPagoId != null) {
        await invNotifier.ajustarMontoLiquidez(oldMedioPagoId, widget.gasto!.monto);
      }
      await ref.read(gastosNotifierProvider.notifier).actualizar(gasto);
    } else {
      await ref.read(gastosNotifierProvider.notifier).agregar(gasto);
    }

    // Debitar del medio de pago seleccionado
    if (_medioPagoId != null) {
      await invNotifier.ajustarMontoLiquidez(_medioPagoId!, -monto);
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _agregarNuevoMedioPago(List<Liquidez> existing) async {
    final result = await showDialog<Liquidez>(
      context: context,
      builder: (ctx) => _NuevoMedioPagoDialog(),
    );
    if (result != null && mounted) {
      await ref.read(inversionesNotifierProvider.notifier).agregarLiquidez(result);
      setState(() => _medioPagoId = result.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dolarBlue = ref.watch(dolarBlueVentaProvider);
    final liquidezList = ref.watch(liquidezProvider);
    final monto = double.tryParse(_montoController.text.replaceAll(',', '.'));
    final montoConvertido = monto != null
        ? (_esUSD ? monto * dolarBlue : monto / dolarBlue)
        : null;

    final dropdownValue = liquidezList.any((l) => l.id == _medioPagoId)
        ? _medioPagoId
        : null;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: scrollController,
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
              Text(_isEditing ? 'Editar Gasto' : 'Nuevo Gasto',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.lg),

              // Tipo: Fijo / Variable
              Row(
                children: TipoGasto.values.map((t) {
                  final selected = _tipo == t;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(t == TipoGasto.fijo ? 'Fijo' : 'Variable'),
                        selected: selected,
                        onSelected: (_) => setState(() => _tipo = t),
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: selected ? AppColors.primary : AppColors.textSecondary,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: selected ? AppColors.primary : AppColors.surfaceBorder,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),

              // Descripción
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Ej: Supermercado Día',
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Ingresá una descripción' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // Toggle moneda
              Row(
                children: [
                  const Text('Moneda:', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(width: 12),
                  _CurrencyToggle(
                    esUSD: _esUSD,
                    onChanged: (v) => setState(() => _esUSD = v),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Monto con conversión
              TextFormField(
                controller: _montoController,
                decoration: InputDecoration(
                  labelText: _esUSD ? 'Monto (USD)' : 'Monto (ARS)',
                  hintText: '0.00',
                  prefixText: _esUSD ? 'USD ' : '\$ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingresá un monto';
                  final n = double.tryParse(v.replaceAll(',', '.'));
                  if (n == null || n <= 0) return 'Monto inválido';
                  return null;
                },
              ),
              if (montoConvertido != null) ...[
                const SizedBox(height: 4),
                Text(
                  _esUSD
                      ? '≈ ${CurrencyFormatter.ars(montoConvertido)} (blue \$${dolarBlue.toStringAsFixed(0)})'
                      : '≈ USD ${montoConvertido.toStringAsFixed(2)} (blue \$${dolarBlue.toStringAsFixed(0)})',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),

              // Categoría
              DropdownButtonFormField<CategoriaGasto>(
                value: _categoria,
                decoration: const InputDecoration(labelText: 'Categoría'),
                dropdownColor: AppColors.surfaceElevated,
                items: CategoriaGasto.values
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Text(c.emoji),
                            const SizedBox(width: 8),
                            Text(c.label),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  _categoria = v!;
                  _subcategoria = null;
                }),
              ),
              const SizedBox(height: AppSpacing.md),

              // Subcategoría (solo si hay opciones para la categoría)
              if (subcategoriasPorCategoria.containsKey(_categoria)) ...[
                DropdownButtonFormField<String>(
                  value: _subcategoria,
                  decoration: const InputDecoration(labelText: 'Subcategoría'),
                  dropdownColor: AppColors.surfaceElevated,
                  items: subcategoriasPorCategoria[_categoria]!
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _subcategoria = v),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Duración (solo para gastos fijos)
              if (_tipo == TipoGasto.fijo) ...[
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    const Text('Duración:', style: TextStyle(color: AppColors.textSecondary)),
                    const Spacer(),
                    Switch(
                      value: _duracionMeses != null,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() {
                        _duracionMeses = v
                            ? (_duracionUnidad == 'anos'
                                ? _duracionValor * 12
                                : _duracionValor)
                            : null;
                      }),
                    ),
                    const Text('Limitada', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
                if (_duracionMeses != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _duracionValor.toString(),
                          decoration: const InputDecoration(labelText: 'Cantidad'),
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            if (n != null && n > 0) {
                              setState(() {
                                _duracionValor = n;
                                _duracionMeses = _duracionUnidad == 'anos' ? n * 12 : n;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _duracionUnidad,
                          decoration: const InputDecoration(labelText: 'Unidad'),
                          dropdownColor: AppColors.surfaceElevated,
                          items: const [
                            DropdownMenuItem(value: 'meses', child: Text('Meses')),
                            DropdownMenuItem(value: 'anos', child: Text('Años')),
                          ],
                          onChanged: (v) => setState(() {
                            _duracionUnidad = v!;
                            _duracionMeses = v == 'anos'
                                ? _duracionValor * 12
                                : _duracionValor;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Expira en $_duracionMeses ${_duracionMeses == 1 ? "mes" : "meses"}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
              ],

              // Fecha
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined, color: AppColors.primary),
                title: Text(DateFormat('dd/MM/yyyy').format(_fecha)),
                subtitle: const Text('Fecha'),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _fecha,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _fecha = date);
                },
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Medio de pago ────────────────────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  const Text('Medio de pago',
                      style: TextStyle(color: AppColors.textSecondary)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _agregarNuevoMedioPago(liquidezList),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Nuevo', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String?>(
                value: dropdownValue,
                isExpanded: true,
                decoration: const InputDecoration(
                  hintText: 'Sin medio de pago (opcional)',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                dropdownColor: AppColors.surfaceElevated,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sin medio de pago'),
                  ),
                  ...liquidezList.map((l) {
                        final sameLabel = liquidezList
                            .where((x) => x.tipoLabel == l.tipoLabel)
                            .length > 1;
                        final display = sameLabel
                            ? '${l.tipo.emoji} ${l.tipoLabel} – ${l.nombre} (${l.moneda})'
                            : '${l.tipo.emoji} ${l.tipoLabel} (${l.moneda})';
                        return DropdownMenuItem<String?>(
                          value: l.id,
                          child: Text(display, overflow: TextOverflow.ellipsis),
                        );
                      }),
                ],
                onChanged: (v) => setState(() => _medioPagoId = v),
              ),
              const SizedBox(height: AppSpacing.lg),

              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isEditing ? 'Guardar Cambios' : 'Guardar Gasto',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Dialog para agregar un nuevo medio de pago rápido ───────────────────────

class _NuevoMedioPagoDialog extends StatefulWidget {
  const _NuevoMedioPagoDialog();

  @override
  State<_NuevoMedioPagoDialog> createState() => _NuevoMedioPagoDialogState();
}

class _NuevoMedioPagoDialogState extends State<_NuevoMedioPagoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _institucionCtrl = TextEditingController();
  TipoLiquidez _tipo = TipoLiquidez.cuentaCorriente;
  String _moneda = 'ARS';

  static const _monedas = ['ARS', 'USD', 'EUR', 'BRL'];

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _institucionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Nuevo medio de pago', style: TextStyle(fontSize: 16)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre *', hintText: 'Ej: Cuenta Galicia'),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _institucionCtrl,
                decoration: const InputDecoration(labelText: 'Institución', hintText: 'Ej: Banco Galicia'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TipoLiquidez>(
                value: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                dropdownColor: AppColors.surfaceElevated,
                items: TipoLiquidez.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text('${t.emoji}  ${t.label}',
                              style: const TextStyle(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _tipo = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _moneda,
                decoration: const InputDecoration(labelText: 'Moneda'),
                dropdownColor: AppColors.surfaceElevated,
                items: _monedas
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => _moneda = v!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final liq = Liquidez(
              nombre: _nombreCtrl.text.trim(),
              monto: 0,
              moneda: _moneda,
              institucion: _institucionCtrl.text.trim().isEmpty
                  ? _nombreCtrl.text.trim()
                  : _institucionCtrl.text.trim(),
              tipo: _tipo,
            );
            Navigator.pop(context, liq);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Crear'),
        ),
      ],
    );
  }
}

class _CurrencyToggle extends StatelessWidget {
  final bool esUSD;
  final ValueChanged<bool> onChanged;

  const _CurrencyToggle({required this.esUSD, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleOption(label: 'ARS', selected: !esUSD, onTap: () => onChanged(false),
              color: AppColors.primary),
          _ToggleOption(label: 'USD', selected: esUSD, onTap: () => onChanged(true),
              color: AppColors.success),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _ToggleOption({required this.label, required this.selected,
      required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
