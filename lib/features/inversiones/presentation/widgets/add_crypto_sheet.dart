import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../market_data/domain/crypto_price.dart';
import '../../../market_data/providers/market_data_providers.dart';
import '../../data/exchange_data.dart';
import '../../domain/inversion_models.dart';
import '../providers/inversiones_provider.dart';
import 'add_accion_sheet.dart' show OperacionToggle, ExchangeDropdown;

class AddCryptoSheet extends ConsumerStatefulWidget {
  final CryptoHolding? crypto;
  const AddCryptoSheet({super.key, this.crypto});

  @override
  ConsumerState<AddCryptoSheet> createState() => _AddCryptoSheetState();
}

class _AddCryptoSheetState extends ConsumerState<AddCryptoSheet> {
  final _formKey = GlobalKey<FormState>();
  final _cantidadController = TextEditingController();
  final _precioController = TextEditingController();
  final _busquedaController = TextEditingController();
  String? _selectedCoinId;
  String? _selectedSymbol;
  String? _selectedName;
  String _exchange = kExchanges.first.nombre;
  DateTime _fecha = DateTime.now();
  bool _esVenta = false;
  bool _saving = false;

  bool get _isEditing => widget.crypto != null;

  @override
  void initState() {
    super.initState();
    final c = widget.crypto;
    if (c != null) {
      _selectedCoinId = c.coingeckoId;
      _selectedSymbol = c.symbol;
      _selectedName = c.nombre;
      _busquedaController.text = '${c.symbol.toUpperCase()} – ${c.nombre}';
      _cantidadController.text = c.cantidad.toString();
      _precioController.text = c.precioCompraUSD.toString();
      _fecha = c.fechaAdquisicion;
    }
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _precioController.dispose();
    _busquedaController.dispose();
    super.dispose();
  }

  void _seleccionarCoin(CryptoPrice coin) {
    setState(() {
      _selectedCoinId = coin.id;
      _selectedSymbol = coin.symbol;
      _selectedName = coin.name;
      _busquedaController.text = '${coin.symbol.toUpperCase()} – ${coin.name}';
      if (_precioController.text.isEmpty) {
        _precioController.text = coin.currentPrice.toStringAsFixed(2);
      }
    });
  }

  void _entradaManual(String texto) {
    // Si el usuario escribe algo que no está en la lista, lo guardamos como custom
    final partes = texto.trim().split(RegExp(r'\s+'));
    final symbol = partes.isNotEmpty ? partes[0].toUpperCase() : texto.toUpperCase();
    setState(() {
      _selectedCoinId = symbol.toLowerCase();
      _selectedSymbol = symbol;
      _selectedName = texto.trim();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCoinId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná o escribí una criptomoneda')),
      );
      return;
    }
    setState(() => _saving = true);

    final cantidad = double.parse(_cantidadController.text.replaceAll(',', '.'));
    final precio = double.parse(_precioController.text.replaceAll(',', '.'));

    if (_esVenta) {
      await ref.read(inversionesNotifierProvider.notifier).registrarVentaCrypto(
        symbol: _selectedSymbol ?? _selectedCoinId!,
        cantidad: cantidad,
        precioVentaUSD: precio,
        exchange: _exchange,
      );
    } else {
      final crypto = CryptoHolding(
        id: widget.crypto?.id,
        coingeckoId: _selectedCoinId!,
        symbol: _selectedSymbol!,
        nombre: _selectedName!,
        cantidad: cantidad,
        precioCompraUSD: precio,
        fechaAdquisicion: _fecha,
      );
      if (_isEditing) {
        await ref.read(inversionesNotifierProvider.notifier).actualizarCrypto(crypto);
      } else {
        await ref.read(inversionesNotifierProvider.notifier).agregarCrypto(crypto);
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final topCryptosAsync = ref.watch(topCryptosProvider);
    final topCryptos = topCryptosAsync.whenOrNull(data: (list) => list) ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
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
              Text(_isEditing ? 'Editar Criptomoneda' : 'Agregar Criptomoneda',
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

              // Selector de criptomoneda
              if (_isEditing)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Row(
                    children: [
                      Text(_selectedSymbol ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning)),
                      const SizedBox(width: 8),
                      Text(_selectedName ?? '', style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                )
              else
                _CryptoSearchField(
                  controller: _busquedaController,
                  topCryptos: topCryptos,
                  isLoading: topCryptosAsync.isLoading,
                  onSelected: _seleccionarCoin,
                  onManualEntry: _entradaManual,
                ),
              const SizedBox(height: AppSpacing.md),

              // Exchange / Broker
              ExchangeDropdown(
                value: _exchange,
                onChanged: (v) => setState(() => _exchange = v),
              ),
              const SizedBox(height: AppSpacing.md),

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
              const SizedBox(height: AppSpacing.md),

              if (!_isEditing && _esVenta)
                Builder(builder: (context) {
                  final cant = double.tryParse(_cantidadController.text.replaceAll(',', '.')) ?? 0;
                  final precio = double.tryParse(_precioController.text.replaceAll(',', '.')) ?? 0;
                  final total = cant * precio;
                  if (total <= 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Total a recibir: USD ${total.toStringAsFixed(2)}',
                      style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
                    ),
                  );
                }),

              if (!_esVenta)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined, color: AppColors.warning),
                title: Text(DateFormat('dd/MM/yyyy').format(_fecha)),
                subtitle: const Text('Fecha de compra'),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _fecha,
                    firstDate: DateTime(2009),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _fecha = date);
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _esVenta ? AppColors.danger : AppColors.warning,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                    _isEditing
                        ? 'Guardar Cambios'
                        : _esVenta
                            ? 'Registrar Venta → Liquidez'
                            : 'Agregar Cripto',
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

class _CryptoSearchField extends StatefulWidget {
  final TextEditingController controller;
  final List<CryptoPrice> topCryptos;
  final bool isLoading;
  final void Function(CryptoPrice) onSelected;
  final void Function(String) onManualEntry;

  const _CryptoSearchField({
    required this.controller,
    required this.topCryptos,
    required this.isLoading,
    required this.onSelected,
    required this.onManualEntry,
  });

  @override
  State<_CryptoSearchField> createState() => _CryptoSearchFieldState();
}

class _CryptoSearchFieldState extends State<_CryptoSearchField> {
  final _focusNode = FocusNode();
  List<CryptoPrice> _sugerencias = [];
  bool _showSuggestions = false;
  bool _selectedFromList = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() => _showSuggestions = false);
        // Solo tratar como entrada manual si el usuario NO seleccionó de la lista.
        // Si seleccionó de la lista, el unfocus() dispararía este listener y
        // sobreescribiría el coingeckoId correcto con uno derivado del texto.
        if (!_selectedFromList && widget.controller.text.isNotEmpty) {
          widget.onManualEntry(widget.controller.text);
        }
        _selectedFromList = false;
      }
    });
  }

  void _onTextChanged() {
    final query = widget.controller.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _sugerencias = [];
        _showSuggestions = false;
      });
      return;
    }
    final filtered = widget.topCryptos.where((c) {
      return c.symbol.toLowerCase().contains(query) ||
             c.name.toLowerCase().contains(query);
    }).take(6).toList();
    setState(() {
      _sugerencias = filtered;
      _showSuggestions = filtered.isNotEmpty && _focusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: 'Criptomoneda',
            hintText: 'Ej: BTC, Bitcoin, ETH...',
            suffixIcon: widget.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning),
                    ),
                  )
                : const Icon(Icons.search, color: AppColors.textSecondary),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresá una criptomoneda' : null,
          onChanged: (_) => setState(() => _showSuggestions = _sugerencias.isNotEmpty),
        ),
        if (_showSuggestions)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Column(
              children: _sugerencias.map((coin) => InkWell(
                onTap: () {
                  _selectedFromList = true;
                  widget.onSelected(coin);
                  setState(() => _showSuggestions = false);
                  _focusNode.unfocus();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Text(
                        coin.symbol.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(coin.name,
                            style: const TextStyle(color: AppColors.textPrimary)),
                      ),
                      Text(
                        'USD ${coin.currentPrice.toStringAsFixed(2)}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )).toList(),
            ),
          ),
        if (!_showSuggestions && widget.topCryptos.isEmpty && !widget.isLoading)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Escribí el símbolo o nombre de la cripto (ej: BTC)',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
