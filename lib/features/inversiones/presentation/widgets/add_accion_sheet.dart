import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../data/exchange_data.dart';
import '../../domain/inversion_models.dart';
import '../providers/inversiones_provider.dart';

class AddAccionSheet extends ConsumerStatefulWidget {
  final Accion? accion;
  const AddAccionSheet({super.key, this.accion});

  @override
  ConsumerState<AddAccionSheet> createState() => _AddAccionSheetState();
}

class _AddAccionSheetState extends ConsumerState<AddAccionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _tickerController = TextEditingController();
  final _nombreController = TextEditingController();
  final _cantidadController = TextEditingController();
  final _precioController = TextEditingController();
  String _mercado = 'NASDAQ';
  String _exchange = kExchanges.first.nombre;
  DateTime _fecha = DateTime.now();
  bool _esVenta = false;
  bool _saving = false;

  bool get _isEditing => widget.accion != null;

  @override
  void initState() {
    super.initState();
    final a = widget.accion;
    if (a != null) {
      _tickerController.text = a.ticker;
      _nombreController.text = a.nombre;
      _cantidadController.text = a.cantidad.toString();
      _precioController.text = a.precioCompraUSD.toString();
      _mercado = a.exchange;
      _fecha = a.fechaAdquisicion;
    }
  }

  @override
  void dispose() {
    _tickerController.dispose();
    _nombreController.dispose();
    _cantidadController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final ticker = _tickerController.text.trim().toUpperCase();
    final cantidad = double.parse(_cantidadController.text.replaceAll(',', '.'));
    final precio = double.parse(_precioController.text.replaceAll(',', '.'));

    if (_esVenta) {
      await ref.read(inversionesNotifierProvider.notifier).registrarVentaAccion(
        ticker: ticker,
        cantidad: cantidad,
        precioVentaUSD: precio,
        exchange: _exchange,
      );
    } else {
      final accion = Accion(
        id: widget.accion?.id,
        ticker: ticker,
        nombre: _nombreController.text.trim(),
        cantidad: cantidad,
        precioCompraUSD: precio,
        fechaAdquisicion: _fecha,
        exchange: _mercado,
      );
      if (_isEditing) {
        await ref.read(inversionesNotifierProvider.notifier).actualizarAccion(accion);
      } else {
        await ref.read(inversionesNotifierProvider.notifier).agregarAccion(accion);
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.97,
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
              Text(_isEditing ? 'Editar Acción' : 'Agregar Acción',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.md),

              // Toggle Compra / Venta (solo al agregar)
              if (!_isEditing) ...[
                OperacionToggle(
                  esVenta: _esVenta,
                  onChanged: (v) => setState(() => _esVenta = v),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Ticker
              TextFormField(
                controller: _tickerController,
                decoration: InputDecoration(
                  labelText: 'Ticker',
                  hintText: 'Ej: AAPL, GGAL, YPF',
                  helperText: _esVenta ? 'Acción que estás vendiendo' : null,
                ),
                textCapitalization: TextCapitalization.characters,
                readOnly: _isEditing,
                validator: (v) => v == null || v.trim().isEmpty ? 'Ingresá el ticker' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // Nombre empresa (solo en compra)
              if (!_esVenta) ...[
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la empresa',
                    hintText: 'Ej: Apple Inc.',
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Ingresá el nombre' : null,
                ),
                const SizedBox(height: AppSpacing.md),

                // Mercado (solo en compra)
                DropdownButtonFormField<String>(
                  value: _mercado,
                  decoration: const InputDecoration(labelText: 'Mercado'),
                  dropdownColor: AppColors.surfaceElevated,
                  items: ['NASDAQ', 'NYSE', 'BYMA', 'NYSE ARCA', 'OTC']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _mercado = v!),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Exchange / Broker (siempre)
              ExchangeDropdown(
                value: _exchange,
                onChanged: (v) => setState(() => _exchange = v),
              ),
              const SizedBox(height: AppSpacing.md),

              // Cantidad y precio
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cantidadController,
                      decoration: const InputDecoration(labelText: 'Cantidad'),
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
                    child: TextFormField(
                      controller: _precioController,
                      decoration: InputDecoration(
                        labelText: _esVenta ? 'Precio venta (USD)' : 'Precio compra (USD)',
                        prefixText: 'USD ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requerido';
                        final n = double.tryParse(v.replaceAll(',', '.'));
                        if (n == null || n <= 0) return 'Inválido';
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              // Total venta informativo
              if (_esVenta)
                Builder(builder: (context) {
                  final cant = double.tryParse(_cantidadController.text.replaceAll(',', '.')) ?? 0;
                  final precio = double.tryParse(_precioController.text.replaceAll(',', '.')) ?? 0;
                  final total = cant * precio;
                  if (total <= 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Total a recibir: USD ${total.toStringAsFixed(2)}',
                      style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
                    ),
                  );
                }),

              const SizedBox(height: AppSpacing.md),

              if (!_esVenta)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined, color: AppColors.primary),
                  title: Text(DateFormat('dd/MM/yyyy').format(_fecha)),
                  subtitle: const Text('Fecha de compra'),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _fecha,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) setState(() => _fecha = date);
                  },
                ),

              const SizedBox(height: AppSpacing.lg),

              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _esVenta ? AppColors.danger : null,
                  foregroundColor: _esVenta ? Colors.white : null,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _isEditing
                            ? 'Guardar Cambios'
                            : _esVenta
                                ? 'Registrar Venta → Liquidez'
                                : 'Agregar al Portfolio',
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

// ─── Toggle Compra / Venta ─────────────────────────────────────────────────────

class OperacionToggle extends StatelessWidget {
  final bool esVenta;
  final ValueChanged<bool> onChanged;

  const OperacionToggle({required this.esVenta, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          ToggleOption(
            label: 'Compra',
            icon: Icons.arrow_downward,
            selected: !esVenta,
            color: AppColors.success,
            onTap: () => onChanged(false),
            isLeft: true,
          ),
          ToggleOption(
            label: 'Venta',
            icon: Icons.arrow_upward,
            selected: esVenta,
            color: AppColors.danger,
            onTap: () => onChanged(true),
            isLeft: false,
          ),
        ],
      ),
    );
  }
}

class ToggleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final bool isLeft;

  const ToggleOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
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
            color: selected ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isLeft ? 9 : 0),
              bottomLeft: Radius.circular(isLeft ? 9 : 0),
              topRight: Radius.circular(isLeft ? 0 : 9),
              bottomRight: Radius.circular(isLeft ? 0 : 9),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? color : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Exchange Dropdown ─────────────────────────────────────────────────────────

class ExchangeDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const ExchangeDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: kExchanges.any((e) => e.nombre == value) ? value : kExchanges.first.nombre,
      decoration: const InputDecoration(labelText: 'Exchange / Broker'),
      dropdownColor: AppColors.surfaceElevated,
      isExpanded: true,
      items: kExchanges.map((e) {
        return DropdownMenuItem(
          value: e.nombre,
          child: Row(
            children: [
              SizedBox(
                width: 22, height: 22,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    e.faviconUrl,
                    width: 22, height: 22,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => CircleAvatar(
                      radius: 11,
                      backgroundColor: AppColors.primary.withOpacity(0.2),
                      child: Text(e.initials,
                          style: const TextStyle(fontSize: 8, color: AppColors.primary,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(child: Text(e.nombre, overflow: TextOverflow.ellipsis)),
            ],
          ),
        );
      }).toList(),
      onChanged: (v) => onChanged(v!),
    );
  }
}
