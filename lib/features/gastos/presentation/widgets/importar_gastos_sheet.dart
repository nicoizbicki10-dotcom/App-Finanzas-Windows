import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../ia/presentation/providers/ia_provider.dart';
import '../../data/importar_gastos_service.dart';
import '../../domain/gasto.dart';
import '../providers/gastos_provider.dart';

enum _ImportStep { input, analizando, confirmacion }

class ImportarGastosSheet extends ConsumerStatefulWidget {
  const ImportarGastosSheet({super.key});

  @override
  ConsumerState<ImportarGastosSheet> createState() =>
      _ImportarGastosSheetState();
}

class _ImportarGastosSheetState extends ConsumerState<ImportarGastosSheet> {
  final _service = ImportarGastosService();
  final _textCtrl = TextEditingController();

  _ImportStep _step = _ImportStep.input;
  int _tabIndex = 0; // 0 = texto, 1 = imagen
  XFile? _imagen;
  String? _error;
  String? _apiKey;

  List<GastoParseado> _items = [];

  static const _timerDuracion = Duration(minutes: 3);
  Timer? _timer;
  int _segundosRestantes = _timerDuracion.inSeconds;

  @override
  void initState() {
    super.initState();
    _cargarApiKey();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargarApiKey() async {
    final key = await ref.read(geminiImportApiKeyProvider.future);
    if (mounted) setState(() => _apiKey = key);
  }

  void _iniciarTimer() {
    _segundosRestantes = _timerDuracion.inSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _segundosRestantes--);
      if (_segundosRestantes <= 0) {
        t.cancel();
        _guardarTodo();
      }
    });
  }

  Future<void> _analizar() async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      _pedirApiKey();
      return;
    }
    if (_tabIndex == 0 && _textCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Pegá el texto del extracto antes de analizar.');
      return;
    }
    if (_tabIndex == 1 && _imagen == null) {
      setState(() => _error = 'Seleccioná una imagen antes de analizar.');
      return;
    }

    setState(() { _step = _ImportStep.analizando; _error = null; });

    try {
      final parsed = _tabIndex == 0
          ? await _service.analizarTexto(apiKey: _apiKey!, texto: _textCtrl.text.trim())
          : await _service.analizarImagen(apiKey: _apiKey!, imagen: _imagen!);

      if (!mounted) return;

      if (parsed.isEmpty) {
        setState(() {
          _step = _ImportStep.input;
          _error = 'No se encontraron transacciones en el contenido.';
        });
        return;
      }

      setState(() { _items = parsed; _step = _ImportStep.confirmacion; });
      _iniciarTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() { _step = _ImportStep.input; _error = _parsearError(e); });
    }
  }

  Future<void> _guardarTodo() async {
    _timer?.cancel();
    final notifier = ref.read(gastosNotifierProvider.notifier);
    for (final item in _items) {
      await notifier.agregar(item.toGasto());
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _eliminarItem(int index) {
    setState(() => _items.removeAt(index));
    if (_items.isEmpty) { _timer?.cancel(); Navigator.of(context).pop(); }
  }

  Future<void> _seleccionarImagen(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final img = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (img != null && mounted) setState(() => _imagen = img);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      setState(() {
        _error = source == ImageSource.camera
            ? 'No se pudo acceder a la cámara. Verificá los permisos en Configuración.'
            : 'No se pudo abrir la galería: $msg';
      });
    }
  }

  Future<void> _pedirApiKey() async {
    final ctrl = TextEditingController(text: _apiKey ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('API Key de Google Gemini'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Necesitás una API key gratuita de Google (aistudio.google.com → Get API Key) para usar esta función.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'AIza...', labelText: 'API Key'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              await guardarGeminiImportApiKey(ctrl.text.trim());
              if (mounted) setState(() => _apiKey = ctrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  String _parsearError(Object e) {
    final msg = e.toString();
    if (msg.contains('400') || msg.contains('401') || msg.contains('API_KEY') ||
        msg.contains('api key') || msg.contains('INVALID_ARGUMENT')) {
      return 'API key incorrecta. Tocá 🔑 para actualizarla.';
    }
    if (msg.contains('429')) return 'Límite de requests alcanzado. Esperá un momento.';
    if (msg.contains('SocketException') || msg.contains('connection')) {
      return 'Sin conexión a internet.';
    }
    return 'Error al analizar: $msg';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: switch (_step) {
          _ImportStep.input => _buildInput(sc),
          _ImportStep.analizando => _buildAnalizando(),
          _ImportStep.confirmacion => _buildConfirmacion(sc),
        },
      ),
    );
  }

  // ─── Step 1: Input ──────────────────────────────────────────────────────────

  Widget _buildInput(ScrollController sc) {
    return ListView(
      controller: sc,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _handle(),
        const SizedBox(height: 16),
        // Header
        Row(children: [
          Expanded(child: Text('Importar Gastos con IA', style: Theme.of(context).textTheme.headlineMedium)),
          IconButton(
            icon: Icon(Icons.key_outlined,
                color: _apiKey != null ? AppColors.success : AppColors.warning, size: 20),
            tooltip: _apiKey != null ? 'API key configurada' : 'Configurar API key',
            onPressed: _pedirApiKey,
          ),
        ]),
        const SizedBox(height: 4),
        const Text('Pegá el texto de tu extracto o adjuntá una foto del resumen.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 20),

        // Tabs custom (sin TabBarView)
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(children: [
            _TabButton(label: 'Texto', selected: _tabIndex == 0, onTap: () => setState(() => _tabIndex = 0)),
            _TabButton(label: 'Imagen', selected: _tabIndex == 1, onTap: () => setState(() => _tabIndex = 1)),
          ]),
        ),
        const SizedBox(height: 16),

        // Contenido del tab — sin PageView, sin TabBarView
        if (_tabIndex == 0) _buildTextoTab() else _buildImagenTab(),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13))),
            ]),
          ),
        ],

        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _analizar,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: const Text('Analizar con IA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildTextoTab() {
    return SizedBox(
      height: 260,
      child: TextField(
        controller: _textCtrl,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Pegá aquí el texto del resumen de tarjeta o extracto bancario...',
          hintStyle: const TextStyle(fontSize: 13, color: AppColors.textDisabled),
          filled: true,
          fillColor: AppColors.surfaceElevated,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.surfaceBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.surfaceBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.danger)),
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }

  Widget _buildImagenTab() {
    return SizedBox(
      height: 260,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: _imagen == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image_outlined, size: 48, color: AppColors.textDisabled),
                  const SizedBox(height: 12),
                  const Text('Seleccioná una imagen',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _seleccionarImagen(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined, size: 20),
                        label: const Text('Galería'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger.withValues(alpha: 0.15),
                          foregroundColor: AppColors.danger,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () => _seleccionarImagen(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined, size: 20),
                        label: const Text('Cámara'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger.withValues(alpha: 0.15),
                          foregroundColor: AppColors.danger,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(_imagen!.path), fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () => _seleccionarImagen(ImageSource.gallery),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.swap_horiz, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Cambiar', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ─── Step 2: Analizando ─────────────────────────────────────────────────────

  Widget _buildAnalizando() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(color: AppColors.danger, strokeWidth: 2.5),
          ),
          SizedBox(height: 24),
          Text('Analizando con IA...',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          SizedBox(height: 8),
          Text('Identificando y clasificando transacciones',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // ─── Step 3: Confirmación ───────────────────────────────────────────────────

  Widget _buildConfirmacion(ScrollController sc) {
    final progreso = _segundosRestantes / _timerDuracion.inSeconds;
    final m = _segundosRestantes ~/ 60;
    final s = _segundosRestantes % 60;
    final timerStr = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    final timerColor = _segundosRestantes < 30 ? AppColors.danger : AppColors.warning;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(children: [
          _handle(),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_items.length} transacciones encontradas',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 2),
              const Text('Revisá y editá cada item antes de guardar.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: timerColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: timerColor.withValues(alpha: 0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.timer_outlined, size: 14, color: timerColor),
                const SizedBox(width: 4),
                Text(timerStr,
                    style: TextStyle(
                        color: timerColor, fontSize: 13, fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progreso,
              backgroundColor: AppColors.surfaceBorder.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(timerColor),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 4),
          const Text('Se guardará automáticamente al terminar el tiempo.',
              style: TextStyle(fontSize: 10, color: AppColors.textDisabled)),
          const SizedBox(height: 12),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          controller: sc,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, i) => _GastoParsedoTile(
            item: _items[i],
            onEliminar: () => _eliminarItem(i),
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
        child: Column(children: [
          FilledButton.icon(
            onPressed: _guardarTodo,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.check, size: 18),
            label: Text('Guardar ${_items.length} gasto${_items.length == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () { _timer?.cancel(); Navigator.of(context).pop(); },
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ]),
      ),
    ]);
  }

  Widget _handle() => Center(
    child: Container(
      width: 40, height: 4,
      decoration: BoxDecoration(color: AppColors.surfaceBorder, borderRadius: BorderRadius.circular(2)),
    ),
  );
}

// ─── Tab button custom ─────────────────────────────────────────────────────────

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.danger : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Source button (galería / cámara) ─────────────────────────────────────────

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.danger.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: AppColors.danger.withValues(alpha: 0.2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: AppColors.danger, size: 26),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

// ─── Tile editable de gasto parseado ──────────────────────────────────────────

class _GastoParsedoTile extends StatefulWidget {
  final GastoParseado item;
  final VoidCallback onEliminar;

  const _GastoParsedoTile({required this.item, required this.onEliminar});

  @override
  State<_GastoParsedoTile> createState() => _GastoParsedoTileState();
}

class _GastoParsedoTileState extends State<_GastoParsedoTile> {
  bool _expanded = false;
  late TextEditingController _descCtrl;
  late TextEditingController _montoCtrl;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.item.descripcion);
    _montoCtrl = TextEditingController(text: widget.item.monto.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  Color get _tipoColor =>
      widget.item.tipo == TipoGasto.fijo ? AppColors.info : AppColors.warning;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yy');
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(children: [
        // Fila principal
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(children: [
            Text(widget.item.categoria.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.item.descripcion,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _tipoColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.item.tipo == TipoGasto.fijo ? 'Fijo' : 'Variable',
                    style: TextStyle(color: _tipoColor, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 6),
                Text(widget.item.categoria.label,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(width: 6),
                Text(fmt.format(widget.item.fecha),
                    style: const TextStyle(fontSize: 11, color: AppColors.textDisabled)),
              ]),
            ])),
            const SizedBox(width: 8),
            Text(
              '${widget.item.esUSD ? 'USD ' : '\$'}${widget.item.monto.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.danger),
            ),
            const SizedBox(width: 4),
            Column(children: [
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18, color: AppColors.textDisabled),
              ),
              GestureDetector(
                onTap: widget.onEliminar,
                child: const Icon(Icons.close, size: 16, color: AppColors.textDisabled),
              ),
            ]),
          ]),
        ),

        // Panel edición expandible
        if (_expanded)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.surfaceBorder))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 10),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Descripción', isDense: true),
                style: const TextStyle(fontSize: 13),
                onChanged: (v) => widget.item.descripcion = v,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _montoCtrl,
                decoration: const InputDecoration(labelText: 'Monto', isDense: true),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                style: const TextStyle(fontSize: 13),
                onChanged: (v) { final p = double.tryParse(v); if (p != null) widget.item.monto = p; },
              ),
              const SizedBox(height: 10),
              Row(children: [
                const Text('Tipo:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 10),
                _EditChip(label: 'Fijo', selected: widget.item.tipo == TipoGasto.fijo, color: AppColors.info,
                    onTap: () => setState(() => widget.item.tipo = TipoGasto.fijo)),
                const SizedBox(width: 6),
                _EditChip(label: 'Variable', selected: widget.item.tipo == TipoGasto.variable, color: AppColors.warning,
                    onTap: () => setState(() => widget.item.tipo = TipoGasto.variable)),
              ]),
              const SizedBox(height: 10),
              const Text('Categoría:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: CategoriaGasto.values.map((c) => _EditChip(
                  label: '${c.emoji} ${c.label}',
                  selected: widget.item.categoria == c,
                  color: AppColors.danger,
                  onTap: () => setState(() => widget.item.categoria = c),
                )).toList(),
              ),
              const SizedBox(height: 10),
              Row(children: [
                const Text('Moneda:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 10),
                _EditChip(label: 'ARS', selected: !widget.item.esUSD, color: AppColors.primary,
                    onTap: () => setState(() => widget.item.esUSD = false)),
                const SizedBox(width: 6),
                _EditChip(label: 'USD', selected: widget.item.esUSD, color: AppColors.primary,
                    onTap: () => setState(() => widget.item.esUSD = true)),
              ]),
            ]),
          ),
      ]),
    );
  }
}

class _EditChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _EditChip({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : AppColors.surfaceBorder),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? color : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}
