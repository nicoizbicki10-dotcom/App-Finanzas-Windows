import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../gastos/presentation/providers/gastos_provider.dart';
import '../../ingresos/presentation/providers/ingresos_provider.dart';
import '../../inversiones/presentation/providers/inversiones_provider.dart';
import '../../market_data/providers/market_data_providers.dart';
import 'providers/ia_provider.dart';

class IaScreen extends ConsumerStatefulWidget {
  const IaScreen({super.key});

  @override
  ConsumerState<IaScreen> createState() => _IaScreenState();
}

class _IaScreenState extends ConsumerState<IaScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _apiKeyController = TextEditingController();
  String? _apiKey;

  @override
  void initState() {
    super.initState();
    _cargarApiKey();
  }

  Future<void> _cargarApiKey() async {
    final prefs = await ref.read(apiKeyProvider.future);
    if (mounted) setState(() => _apiKey = prefs);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _scrollAbajo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _buildSystemPrompt({
    required double totalPatrimonioUSD,
    required double dolarBlue,
    required double totalGastosARS,
    required double totalIngresosARS,
    required double accionesUSD,
    required double cryptoUSD,
    required double inmueblesUSD,
    required Map<String, double> distribucion,
  }) {
    final balanceMensualARS = totalIngresosARS - totalGastosARS;
    final balanceMensualUSD = balanceMensualARS / dolarBlue;

    return '''Sos un asesor financiero personal experto en el mercado argentino. Tu rol es ayudar al usuario a tomar mejores decisiones financieras basadas en sus datos reales.

## DATOS FINANCIEROS ACTUALES DEL USUARIO

**Patrimonio total:** USD ${totalPatrimonioUSD.toStringAsFixed(0)} (≈ ${CurrencyFormatter.compact(totalPatrimonioUSD * dolarBlue)})

**Composición del portfolio:**
${distribucion.entries.where((e) => e.value > 0.1).map((e) => '- ${e.key}: ${e.value.toStringAsFixed(1)}%').join('\n')}

**Detalle de inversiones:**
- Inmuebles: USD ${inmueblesUSD.toStringAsFixed(0)}
- Acciones: USD ${accionesUSD.toStringAsFixed(0)}
- Criptomonedas: USD ${cryptoUSD.toStringAsFixed(0)}

**Flujo mensual (mes actual):**
- Ingresos: ${CurrencyFormatter.ars(totalIngresosARS)} (≈ USD ${(totalIngresosARS / dolarBlue).toStringAsFixed(0)})
- Gastos: ${CurrencyFormatter.ars(totalGastosARS)} (≈ USD ${(totalGastosARS / dolarBlue).toStringAsFixed(0)})
- Balance: ${balanceMensualARS >= 0 ? '+' : ''}${CurrencyFormatter.ars(balanceMensualARS)} (≈ USD ${balanceMensualUSD >= 0 ? '+' : ''}${balanceMensualUSD.toStringAsFixed(0)})

**Tipo de cambio dólar blue:** \$${dolarBlue.toStringAsFixed(0)} ARS/USD

## INSTRUCCIONES

- Respondé siempre en español argentino
- Usá los datos reales del usuario para personalizar tus recomendaciones
- Cuando menciones montos, mostrá tanto ARS como USD cuando sea relevante
- Sé concreto y accionable, no genérico
- Considerá el contexto económico argentino (inflación, cepo cambiario, opciones de inversión locales)
- Si el usuario pregunta algo fuera del ámbito financiero, redirigí la conversación amablemente''';
  }

  void _usarSugerencia(String texto) {
    _inputController.text = texto;
    _enviar();
  }

  Future<void> _enviar() async {
    final texto = _inputController.text.trim();
    if (texto.isEmpty || _apiKey == null) return;

    _inputController.clear();

    // Recolectar datos financieros actuales
    final dolarBlue = ref.read(dolarBlueVentaProvider);
    final totalGastos = ref.read(totalGastosMesProvider);
    final totalIngresos = ref.read(totalIngresosMesProvider);

    double accionesUSD = 0;
    double cryptoUSD = 0;
    double inmueblesUSD = 0;
    double totalPatrimonio = 0;
    Map<String, double> distribucion = {};

    try { accionesUSD = await ref.read(valorAccionesUSDProvider.future); } catch (_) {}
    try { cryptoUSD = await ref.read(valorCryptoUSDProvider.future); } catch (_) {}
    try { inmueblesUSD = await ref.read(valorInmueblesUSDProvider.future); } catch (_) {}
    try { totalPatrimonio = await ref.read(totalPatrimonioUSDProvider.future); } catch (_) {}
    try { distribucion = await ref.read(distribucionPortfolioProvider.future); } catch (_) {}

    final systemPrompt = _buildSystemPrompt(
      totalPatrimonioUSD: totalPatrimonio,
      dolarBlue: dolarBlue,
      totalGastosARS: totalGastos,
      totalIngresosARS: totalIngresos,
      accionesUSD: accionesUSD,
      cryptoUSD: cryptoUSD,
      inmueblesUSD: inmueblesUSD,
      distribucion: distribucion,
    );

    await ref.read(iaChatProvider.notifier).enviar(
      apiKey: _apiKey!,
      systemPrompt: systemPrompt,
      texto: texto,
    );
    _scrollAbajo();
  }

  Future<void> _mostrarDialogApiKey() async {
    _apiKeyController.text = _apiKey ?? '';
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
              'Ingresá tu API key de Groq (groq.com).',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'Obtenela en console.groq.com → API Keys',
              style: TextStyle(color: AppColors.primary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'gsk_...',
                hintText: 'gsk_...',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          if (_apiKey != null)
            TextButton(
              onPressed: () async {
                await borrarApiKey();
                setState(() => _apiKey = null);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Borrar', style: TextStyle(color: AppColors.danger)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final key = _apiKeyController.text.trim();
              if (key.isNotEmpty) {
                await guardarApiKey(key);
                setState(() => _apiKey = key);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(iaChatProvider);

    ref.listen(iaChatProvider, (_, next) {
      if (!next.cargando && next.mensajes.isNotEmpty) _scrollAbajo();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, size: 20, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Asesor IA  ·  Groq'),
          ],
        ),
        actions: [
          if (chatState.mensajes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Limpiar chat',
              onPressed: () => ref.read(iaChatProvider.notifier).limpiarChat(),
            ),
          IconButton(
            icon: Icon(
              _apiKey != null ? Icons.key : Icons.key_off_outlined,
              color: _apiKey != null ? AppColors.success : AppColors.warning,
            ),
            tooltip: 'Configurar API Key',
            onPressed: _mostrarDialogApiKey,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Sin API key — banner de configuración
          if (_apiKey == null)
            _ApiKeyBanner(onTap: _mostrarDialogApiKey),

          // Lista de mensajes
          Expanded(
            child: chatState.mensajes.isEmpty
                ? _EmptyState(
                    apiKeyConfigurada: _apiKey != null,
                    onConfigurarKey: _mostrarDialogApiKey,
                    onUsarSugerencia: _usarSugerencia,
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: chatState.mensajes.length + (chatState.cargando ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == chatState.mensajes.length) {
                        return const _TypingIndicator();
                      }
                      return _BurbujaMensaje(mensaje: chatState.mensajes[i]);
                    },
                  ),
          ),

          // Error
          if (chatState.error != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.danger.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(chatState.error!,
                        style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                  ),
                  if (chatState.puedeReintentar) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => ref.read(iaChatProvider.notifier)
                          .reintentar(apiKey: _apiKey!),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: AppColors.danger,
                      ),
                      child: const Text('Reintentar', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),

          // Input
          _InputBar(
            controller: _inputController,
            cargando: chatState.cargando,
            habilitado: _apiKey != null,
            onEnviar: _enviar,
          ),
        ],
      ),
    );
  }
}

// ─── Widgets internos ──────────────────────────────────────────────────────────

class _ApiKeyBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _ApiKeyBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: AppColors.warning.withOpacity(0.15),
        child: Row(
          children: [
            const Icon(Icons.key_off_outlined, color: AppColors.warning, size: 16),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Configurá tu API key de Groq para usar el asesor IA',
                style: TextStyle(color: AppColors.warning, fontSize: 13),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.warning, size: 16),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool apiKeyConfigurada;
  final VoidCallback onConfigurarKey;
  final void Function(String texto) onUsarSugerencia;

  const _EmptyState({
    required this.apiKeyConfigurada,
    required this.onConfigurarKey,
    required this.onUsarSugerencia,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'Asesor Financiero IA',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Consultá sobre tu patrimonio, inversiones, reducción de gastos y estrategias financieras personalizadas para tu situación.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            if (!apiKeyConfigurada) ...[
              ElevatedButton.icon(
                onPressed: onConfigurarKey,
                icon: const Icon(Icons.key),
                label: const Text('Configurar API Key'),
              ),
              const SizedBox(height: 24),
            ],
            const Text('Sugerencias:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            ..._sugerencias.map((s) => _SugerenciaChip(texto: s, onTap: () => onUsarSugerencia(s))),
          ],
        ),
      ),
    );
  }

  static const _sugerencias = [
    '¿Cómo está mi portfolio comparado con un inversor conservador?',
    '¿En qué debería invertir mi balance mensual?',
    '¿Cómo puedo reducir mis gastos fijos?',
    '¿Estoy bien diversificado para el contexto argentino?',
  ];
}

class _SugerenciaChip extends StatelessWidget {
  final String texto;
  final VoidCallback onTap;
  const _SugerenciaChip({required this.texto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(texto,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ),
            const Icon(Icons.arrow_forward_ios, size: 11, color: AppColors.textDisabled),
          ],
        ),
      ),
    );
  }
}

class _BurbujaMensaje extends StatelessWidget {
  final ChatMensaje mensaje;
  const _BurbujaMensaje({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    final esUsuario = mensaje.rol == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: esUsuario ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!esUsuario) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: esUsuario
                    ? AppColors.primary.withOpacity(0.15)
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(esUsuario ? 16 : 4),
                  bottomRight: Radius.circular(esUsuario ? 4 : 16),
                ),
                border: Border.all(
                  color: esUsuario
                      ? AppColors.primary.withOpacity(0.3)
                      : AppColors.surfaceBorder,
                ),
              ),
              child: Text(
                mensaje.contenido,
                style: TextStyle(
                  color: esUsuario ? AppColors.primary : AppColors.textPrimary,
                  height: 1.5,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          if (esUsuario) const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: const SizedBox(
              width: 40,
              height: 16,
              child: _DotsAnimation(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotsAnimation extends StatefulWidget {
  const _DotsAnimation();

  @override
  State<_DotsAnimation> createState() => _DotsAnimationState();
}

class _DotsAnimationState extends State<_DotsAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(3, (i) {
            final offset = ((t * 3 - i) % 1.0).clamp(0.0, 1.0);
            final opacity = offset < 0.5 ? offset * 2 : (1 - offset) * 2;
            return Opacity(
              opacity: opacity.clamp(0.3, 1.0),
              child: const CircleAvatar(
                radius: 3,
                backgroundColor: AppColors.textSecondary,
              ),
            );
          }),
        );
      },
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool cargando;
  final bool habilitado;
  final VoidCallback onEnviar;

  const _InputBar({
    required this.controller,
    required this.cargando,
    required this.habilitado,
    required this.onEnviar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: habilitado && !cargando,
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onEnviar(),
              decoration: InputDecoration(
                hintText: habilitado
                    ? 'Preguntá sobre tus finanzas...'
                    : 'Configurá tu API key primero',
                hintStyle: const TextStyle(color: AppColors.textDisabled),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: cargando
                ? const SizedBox(
                    width: 44,
                    height: 44,
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                  )
                : IconButton(
                    onPressed: habilitado ? onEnviar : null,
                    style: IconButton.styleFrom(
                      backgroundColor: habilitado ? AppColors.primary : AppColors.surfaceElevated,
                      foregroundColor: habilitado ? Colors.white : AppColors.textDisabled,
                      minimumSize: const Size(44, 44),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 20),
                  ),
          ),
        ],
      ),
    );
  }
}
