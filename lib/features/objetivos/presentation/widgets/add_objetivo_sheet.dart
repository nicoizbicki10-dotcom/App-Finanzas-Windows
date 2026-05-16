import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../domain/objetivo.dart';
import '../providers/objetivos_provider.dart';

class AddObjetivoSheet extends ConsumerStatefulWidget {
  const AddObjetivoSheet({super.key});

  @override
  ConsumerState<AddObjetivoSheet> createState() => _AddObjetivoSheetState();
}

class _AddObjetivoSheetState extends ConsumerState<AddObjetivoSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _metaCtrl = TextEditingController();
  final _actualCtrl = TextEditingController(text: '0');
  final _linkCtrl = TextEditingController();

  TipoObjetivo _tipo = TipoObjetivo.ahorro;
  MonedaObjetivo _moneda = MonedaObjetivo.ars;
  DateTime _fechaMeta = DateTime.now().add(const Duration(days: 365));
  String? _colorHex;
  bool _saving = false;

  static const _colores = [
    '#FFA502', '#00D4FF', '#00C896', '#7B2FBE',
    '#FF4757', '#FF6B81', '#3742FA', '#2ed573',
  ];

  @override
  void dispose() {
    _nombreCtrl.dispose(); _descCtrl.dispose();
    _metaCtrl.dispose(); _actualCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final linkText = _linkCtrl.text.trim();
    final objetivo = Objetivo(
      nombre: _nombreCtrl.text.trim(),
      descripcion: _descCtrl.text.trim(),
      montoMeta: double.parse(_metaCtrl.text.replaceAll(',', '.')),
      montoActual: double.tryParse(_actualCtrl.text.replaceAll(',', '.')) ?? 0,
      moneda: _moneda,
      tipo: _tipo,
      fechaInicio: DateTime.now(),
      fechaMeta: _fechaMeta,
      colorHex: _colorHex,
      link: linkText.isEmpty ? null : linkText,
    );

    await ref.read(objetivosNotifierProvider.notifier).agregar(objetivo);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
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
              Text('Nuevo Objetivo', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.lg),

              // Tipo de objetivo
              Text('Tipo', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: TipoObjetivo.values.map((t) {
                  final selected = _tipo == t;
                  return ChoiceChip(
                    label: Text('${t.emoji} ${t.label}'),
                    selected: selected,
                    onSelected: (_) => setState(() => _tipo = t),
                    selectedColor: AppColors.warning.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: selected ? AppColors.warning : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: selected ? AppColors.warning : AppColors.surfaceBorder,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),

              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre del objetivo'),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => v == null || v.trim().isEmpty ? 'Ingresá un nombre' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.md),

              TextFormField(
                controller: _linkCtrl,
                decoration: const InputDecoration(
                  labelText: 'Link de referencia (opcional)',
                  hintText: 'https://...',
                  prefixIcon: Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: AppSpacing.md),

              // Moneda
              Row(
                children: [
                  Text('Moneda:', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(width: AppSpacing.md),
                  ...MonedaObjetivo.values.map((m) {
                    final selected = _moneda == m;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(m == MonedaObjetivo.ars ? 'ARS \$' : 'USD \$'),
                        selected: selected,
                        onSelected: (_) => setState(() => _moneda = m),
                        selectedColor: AppColors.primary.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: selected ? AppColors.primary : AppColors.textSecondary,
                        ),
                        side: BorderSide(
                          color: selected ? AppColors.primary : AppColors.surfaceBorder,
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _metaCtrl,
                      decoration: InputDecoration(
                        labelText: 'Meta',
                        prefixText: _moneda == MonedaObjetivo.ars ? '\$ ' : 'USD ',
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
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _actualCtrl,
                      decoration: InputDecoration(
                        labelText: 'Ya tengo',
                        prefixText: _moneda == MonedaObjetivo.ars ? '\$ ' : 'USD ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Fecha meta
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month_outlined, color: AppColors.warning),
                title: Text('Meta: ${DateFormat('dd/MM/yyyy').format(_fechaMeta)}'),
                subtitle: Text(
                  '${_fechaMeta.difference(DateTime.now()).inDays} días para cumplir el objetivo',
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _fechaMeta,
                    firstDate: DateTime.now().add(const Duration(days: 1)),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) setState(() => _fechaMeta = date);
                },
              ),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),

              // Color del objetivo
              Text('Color:', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: _colores.map((hex) {
                  final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                  final selected = _colorHex == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _colorHex = hex),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: selected
                            ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 1)]
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),

              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _colorHex != null
                      ? Color(int.parse(_colorHex!.replaceFirst('#', '0xFF')))
                      : AppColors.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Crear Objetivo',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
