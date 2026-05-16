import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart'; // XFile
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../ia/presentation/providers/ia_provider.dart';
import '../../../inversiones/domain/inversion_models.dart';
import '../../../inversiones/presentation/providers/inversiones_provider.dart';
import '../../data/importar_gastos_service.dart';
import '../../domain/gasto.dart';
import '../providers/gastos_provider.dart';

enum _ImportStep { input, analizando, confirmacion }

class ImportarGastosPage extends ConsumerStatefulWidget {
  const ImportarGastosPage({super.key});

  @override
  ConsumerState<ImportarGastosPage> createState() => _ImportarGastosPageState();
}

class _ImportarGastosPageState extends ConsumerState<ImportarGastosPage> {
  final _service = ImportarGastosService();
  final _textCtrl = TextEditingController();

  _ImportStep _step = _ImportStep.input;
  int _tabIndex = 0;
  XFile? _imagen;
  String? _pdfPath;
  String? _error;
  String? _apiKey;

  List<GastoParseado> _items = [];
  int _omitidos = 0;
  int _actualizados = 0;
  List<Gasto> _actualizaciones = [];
  String? _medioPagoGlobal;

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
    final key = await ref.read(apiKeyProvider.future);
    if (mounted) setState(() => _apiKey = key);
  }

  void _iniciarTimer() {
    _segundosRestantes = _timerDuracion.inSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _segundosRestantes--);
      if (_segundosRestantes <= 0) { t.cancel(); _guardarTodo(); }
    });
  }

  Future<void> _analizar() async {
    if (_apiKey == null || _apiKey!.isEmpty) { _pedirApiKey(); return; }
    if (_tabIndex == 0 && _textCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Pegá el texto del extracto antes de analizar.');
      return;
    }
    if (_tabIndex == 1 && _imagen == null && _pdfPath == null) {
      setState(() => _error = 'Seleccioná un archivo antes de analizar.');
      return;
    }

    setState(() { _step = _ImportStep.analizando; _error = null; });

    try {
      List<GastoParseado> parsed;
      if (_tabIndex == 0) {
        parsed = await _service.analizarTexto(apiKey: _apiKey!, texto: _textCtrl.text.trim());
      } else if (_pdfPath != null) {
        parsed = await _service.analizarPdf(apiKey: _apiKey!, pdfPath: _pdfPath!);
      } else {
        parsed = await _service.analizarImagen(apiKey: _apiKey!, imagen: _imagen!);
      }

      if (!mounted) return;
      if (parsed.isEmpty) {
        setState(() { _step = _ImportStep.input; _error = 'No se encontraron transacciones en el contenido.'; });
        return;
      }

      final (filtrados, omitidos, actualizaciones) = _filtrarDuplicadosFijos(parsed);
      if (filtrados.isEmpty && actualizaciones.isEmpty) {
        setState(() {
          _step = _ImportStep.input;
          _error = omitidos > 0
              ? 'Todos los gastos fijos del resumen ya están registrados.'
              : 'No se encontraron transacciones en el contenido.';
        });
        return;
      }
      // Si solo hay actualizaciones de precio (sin nuevos gastos), guardar directamente
      if (filtrados.isEmpty && actualizaciones.isNotEmpty) {
        final notifier = ref.read(gastosNotifierProvider.notifier);
        for (final g in actualizaciones) {
          await notifier.actualizar(g);
        }
        if (!mounted) return;
        setState(() { _step = _ImportStep.input; _error = null; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${actualizaciones.length} gasto${actualizaciones.length == 1 ? ' fijo actualizado' : 's fijos actualizados'} con nuevo precio.'),
          backgroundColor: AppColors.info,
        ));
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _items = filtrados;
        _omitidos = omitidos;
        _actualizados = actualizaciones.length;
        _actualizaciones = actualizaciones;
        _step = _ImportStep.confirmacion;
      });
      _iniciarTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() { _step = _ImportStep.input; _error = _parsearError(e); });
    }
  }

  Future<void> _guardarTodo() async {
    _timer?.cancel();
    final notifier = ref.read(gastosNotifierProvider.notifier);
    final invNotifier = ref.read(inversionesNotifierProvider.notifier);
    for (final item in _items) {
      await notifier.agregar(item.toGasto());
      if (item.medioPagoId != null) {
        await invNotifier.ajustarMontoLiquidez(item.medioPagoId!, -item.monto);
      }
    }
    for (final gasto in _actualizaciones) {
      await notifier.actualizar(gasto);
    }
    if (_items.isNotEmpty && mounted) {
      final f = _items.first.fecha;
      ref.read(mesSeleccionadoGastosProvider.notifier).state =
          DateTime(f.year, f.month);
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// Filtra gastos fijos que ya existen y están vigentes.
  /// Retorna (items a guardar, cantidad omitidos, actualizaciones de precio).
  (List<GastoParseado>, int, List<Gasto>) _filtrarDuplicadosFijos(List<GastoParseado> items) {
    final repo = ref.read(gastosRepositoryProvider);
    final existentesFijos = repo.getAll().where((g) => g.tipo == TipoGasto.fijo).toList();
    final ahora = DateTime.now();
    final mesActual = DateTime(ahora.year, ahora.month);

    final resultado = <GastoParseado>[];
    final actualizaciones = <Gasto>[];
    int omitidos = 0;

    for (final item in items) {
      if (item.tipo != TipoGasto.fijo) {
        resultado.add(item);
        continue;
      }

      // Las cuotas nunca se deduplicanpor aunque el modelo las marque como fijo
      if (_esCuota(item.descripcion)) {
        item.tipo = TipoGasto.variable;
        resultado.add(item);
        continue;
      }

      final coincidentes = existentesFijos
          .where((e) => _descripcionSimilar(e.descripcion, item.descripcion));
      if (coincidentes.isEmpty) {
        resultado.add(item);
        continue;
      }

      final existente = coincidentes.first;

      if (existente.duracionMeses == null) {
        // Fijo indefinido → verificar si el precio cambió
        if ((existente.monto - item.monto).abs() > 0.01) {
          actualizaciones.add(existente.copyWith(monto: item.monto));
        }
        omitidos++;
        continue;
      }

      // Fijo con duración limitada → verificar si venció
      final vencimiento = DateTime(
          existente.fecha.year, existente.fecha.month + existente.duracionMeses!);
      if (!vencimiento.isBefore(mesActual)) {
        // Aún vigente → omitir
        omitidos++;
        continue;
      }

      // Venció → es una renovación, incluir
      resultado.add(item);
    }

    return (resultado, omitidos, actualizaciones);
  }

  bool _esCuota(String descripcion) =>
      RegExp(r'\b\d{1,2}/\d{1,2}\b').hasMatch(descripcion);

  bool _descripcionSimilar(String a, String b) {
    String norm(String s) => s
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[*.\-_/\\]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    final na = norm(a);
    final nb = norm(b);
    if (na == nb) return true;
    if (na.length >= 4 && nb.contains(na)) return true;
    if (nb.length >= 4 && na.contains(nb)) return true;
    return false;
  }

  void _eliminarItem(int index) {
    setState(() => _items.removeAt(index));
    if (_items.isEmpty) { _timer?.cancel(); Navigator.of(context).pop(); }
  }

  Future<void> _seleccionarDeGaleria() async {
    setState(() => _error = null);
    try {
      final downloadsDir = await getDownloadsDirectory();
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif', 'pdf'],
        allowMultiple: false,
        initialDirectory: downloadsDir?.path,
      );
      if (!mounted) return;
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final path = file.path;
        if (path == null) return;
        final ext = (file.extension ?? '').toLowerCase();
        if (ext == 'pdf') {
          setState(() { _pdfPath = path; _imagen = null; _error = null; });
        } else {
          setState(() { _imagen = XFile(path); _pdfPath = null; _error = null; });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error al abrir el selector: $e');
    }
  }

  Future<void> _pedirApiKey() async {
    final ctrl = TextEditingController(text: _apiKey ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('API Key de Groq'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Es la misma API key de Groq que usás para el chat IA (console.groq.com).',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'gsk_...', labelText: 'API Key'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final key = ctrl.text.trim();
              await guardarApiKey(key);
              ref.invalidate(apiKeyProvider);
              if (mounted) setState(() => _apiKey = key);
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
    if (e is DioException) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      String? apiMsg;
      if (data is Map) {
        final errorObj = data['error'];
        if (errorObj is Map) {
          apiMsg = errorObj['message'] as String?;
        }
        apiMsg ??= errorObj?.toString();
      }
      final msgLower = apiMsg?.toLowerCase() ?? '';
      if (status == 401 || msgLower.contains('invalid_api_key') || msgLower.contains('api key')) {
        return 'API key incorrecta. Tocá 🔑 para actualizarla.';
      }
      if (status == 403) return 'Acceso denegado. Verificá tu API key en console.groq.com';
      if (status == 429) return 'Límite de requests alcanzado. Esperá un momento.';
      if (status == 400) {
        if (apiMsg != null) return 'Error al procesar el archivo: $apiMsg';
        return 'Archivo no válido. Usá una imagen JPG, PNG o WebP.';
      }
      if (apiMsg != null) return 'Error: $apiMsg';
      if (status != null) return 'Error HTTP $status.';
    }
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('connection')) return 'Sin conexión.';
    return 'Error: $msg';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Importar Gastos con IA'),
        actions: [
          IconButton(
            icon: Icon(Icons.key_outlined,
                color: _apiKey != null ? AppColors.success : AppColors.warning),
            tooltip: _apiKey != null ? 'API key configurada' : 'Configurar API key',
            onPressed: _pedirApiKey,
          ),
        ],
      ),
      body: switch (_step) {
        _ImportStep.input => _buildInput(),
        _ImportStep.analizando => _buildAnalizando(),
        _ImportStep.confirmacion => _buildConfirmacion(),
      },
    );
  }

  // ─── Input ──────────────────────────────────────────────────────────────────

  Widget _buildInput() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pegá el texto de tu extracto o adjuntá una foto del resumen.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Tabs custom
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(children: [
              _TabBtn(label: 'Texto', selected: _tabIndex == 0,
                  onTap: () => setState(() => _tabIndex = 0)),
              _TabBtn(label: 'Imagen', selected: _tabIndex == 1,
                  onTap: () => setState(() => _tabIndex = 1)),
            ]),
          ),
          const SizedBox(height: 16),

          if (_tabIndex == 0) _buildTextoTab() else _buildImagenTab(),

          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _error!),
          ],

          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _analizar,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Analizar con IA',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
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
    if (_pdfPath != null) {
      final nombre = _pdfPath!.split('/').last;
      return Container(
        height: 260,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf_outlined, size: 56, color: AppColors.danger),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(nombre,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 4),
            const Text('El texto se extraerá automáticamente',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _seleccionarDeGaleria,
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: const Text('Cambiar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceBorder,
                foregroundColor: AppColors.textSecondary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      );
    }

    if (_imagen != null) {
      return SizedBox(
        height: 260,
        child: Stack(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(_imagen!.path), fit: BoxFit.cover,
                width: double.infinity, height: 260),
          ),
          Positioned(
            top: 8, right: 8,
            child: ElevatedButton.icon(
              onPressed: _seleccionarDeGaleria,
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: const Text('Cambiar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
        ]),
      );
    }

    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.upload_file_outlined, size: 52, color: AppColors.textDisabled),
          const SizedBox(height: 12),
          const Text('Seleccioná el resumen de tu tarjeta',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('PDF, JPG o PNG',
              style: TextStyle(color: AppColors.textDisabled, fontSize: 11)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _seleccionarDeGaleria,
            icon: const Icon(Icons.folder_open_outlined, size: 20),
            label: const Text('Seleccionar archivo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger.withValues(alpha: 0.15),
              foregroundColor: AppColors.danger,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Analizando ─────────────────────────────────────────────────────────────

  Widget _buildAnalizando() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(color: AppColors.danger, strokeWidth: 2.5),
          ),
          SizedBox(height: 24),
          Text('Analizando con IA...',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Text('Identificando y clasificando transacciones',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // ─── Confirmación ───────────────────────────────────────────────────────────

  Widget _buildConfirmacion() {
    final progreso = _segundosRestantes / _timerDuracion.inSeconds;
    final m = _segundosRestantes ~/ 60;
    final s = _segundosRestantes % 60;
    final timerStr = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    final timerColor = _segundosRestantes < 30 ? AppColors.danger : AppColors.warning;
    final liquidezList = ref.watch(liquidezProvider);

    return Column(children: [
      // Header fijo
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(children: [
          Row(children: [
            Expanded(child: Text('${_items.length} transacciones encontradas',
                style: Theme.of(context).textTheme.headlineMedium)),
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
                    style: TextStyle(color: timerColor, fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
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
          if (_omitidos > 0 || _actualizados > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, size: 14, color: AppColors.info),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [
                      if (_omitidos > 0)
                        '$_omitidos fijo${_omitidos == 1 ? '' : 's'} omitido${_omitidos == 1 ? '' : 's'} (ya existente${_omitidos == 1 ? '' : 's'})',
                      if (_actualizados > 0)
                        '$_actualizados fijo${_actualizados == 1 ? '' : 's'} con precio actualizado',
                    ].join(' · '),
                    style: const TextStyle(fontSize: 11, color: AppColors.info),
                  ),
                ),
              ]),
            ),
          ],
          if (liquidezList.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Text('Débitar de:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _medioPagoGlobal,
                  isExpanded: true,
                  isDense: true,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Sin medio de pago', style: TextStyle(fontSize: 12))),
                    ...liquidezList.map((l) {
                      final sameLabel = liquidezList.where((x) => x.tipoLabel == l.tipoLabel).length > 1;
                      final display = sameLabel ? '${l.tipo.emoji} ${l.tipoLabel} – ${l.nombre}' : '${l.tipo.emoji} ${l.tipoLabel}';
                      return DropdownMenuItem<String?>(
                        value: l.id,
                        child: Text(display, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                      );
                    }),
                  ],
                  onChanged: (v) => setState(() {
                    _medioPagoGlobal = v;
                    for (final item in _items) { item.medioPagoId = v; }
                  }),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 12),
        ]),
      ),

      // Lista
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, i) => _GastoParsedoTile(
            item: _items[i],
            liquidezList: liquidezList,
            onEliminar: () => _eliminarItem(i),
          ),
        ),
      ),

      // Botones fijos
      Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).padding.bottom + 16),
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
}

// ─── Widgets auxiliares ────────────────────────────────────────────────────────

class _TabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabBtn({required this.label, required this.selected, required this.onTap});

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
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14)),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppColors.danger, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(message,
            style: const TextStyle(color: AppColors.danger, fontSize: 13))),
      ]),
    );
  }
}

class _GastoParsedoTile extends StatefulWidget {
  final GastoParseado item;
  final List<Liquidez> liquidezList;
  final VoidCallback onEliminar;

  const _GastoParsedoTile({required this.item, required this.liquidezList, required this.onEliminar});

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
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(children: [
            Text(widget.item.categoria.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.item.descripcion,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _tipoColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(widget.item.tipo == TipoGasto.fijo ? 'Fijo' : 'Variable',
                      style: TextStyle(color: _tipoColor, fontSize: 10, fontWeight: FontWeight.w600)),
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
                _EditChip(label: 'Fijo', selected: widget.item.tipo == TipoGasto.fijo,
                    color: AppColors.info,
                    onTap: () => setState(() => widget.item.tipo = TipoGasto.fijo)),
                const SizedBox(width: 6),
                _EditChip(label: 'Variable', selected: widget.item.tipo == TipoGasto.variable,
                    color: AppColors.warning,
                    onTap: () => setState(() => widget.item.tipo = TipoGasto.variable)),
              ]),
              const SizedBox(height: 10),
              const Text('Categoría:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6,
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
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: widget.item.fecha,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => widget.item.fecha = picked);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.surfaceBorder),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    const Text('Fecha', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const Spacer(),
                    Text(DateFormat('dd/MM/yyyy').format(widget.item.fecha),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
              if (widget.liquidezList.isNotEmpty) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  value: widget.liquidezList.any((l) => l.id == widget.item.medioPagoId)
                      ? widget.item.medioPagoId : null,
                  isExpanded: true,
                  isDense: true,
                  decoration: InputDecoration(
                    labelText: 'Débitar de',
                    labelStyle: const TextStyle(fontSize: 12),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Sin medio de pago', style: TextStyle(fontSize: 12))),
                    ...widget.liquidezList.map((l) {
                      final sameLabel = widget.liquidezList.where((x) => x.tipoLabel == l.tipoLabel).length > 1;
                      final display = sameLabel ? '${l.tipo.emoji} ${l.tipoLabel} – ${l.nombre}' : '${l.tipo.emoji} ${l.tipoLabel}';
                      return DropdownMenuItem<String?>(
                        value: l.id,
                        child: Text(display, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                      );
                    }),
                  ],
                  onChanged: (v) => setState(() => widget.item.medioPagoId = v),
                ),
              ],
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
