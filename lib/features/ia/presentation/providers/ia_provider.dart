import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/gemini_api_service.dart';

// ─── Modelo de mensaje ─────────────────────────────────────────────────────────

class ChatMensaje {
  final String rol; // 'user' | 'assistant'
  final String contenido;
  final DateTime timestamp;

  const ChatMensaje({
    required this.rol,
    required this.contenido,
    required this.timestamp,
  });
}

// ─── API Keys ──────────────────────────────────────────────────────────────────

const _kApiKeyPref = 'ia_grok_api_key';
const _kGeminiImportApiKeyPref = 'ia_gemini_import_api_key';

// Google Gemini key (used for vision import feature — free tier)
final geminiImportApiKeyProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kGeminiImportApiKeyPref);
});

Future<void> guardarGeminiImportApiKey(String key) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kGeminiImportApiKeyPref, key);
}

Future<void> borrarGeminiImportApiKey() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kGeminiImportApiKeyPref);
}

final apiKeyProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kApiKeyPref);
});

Future<void> guardarApiKey(String key) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kApiKeyPref, key);
}

Future<void> borrarApiKey() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kApiKeyPref);
}

// ─── Estado del chat ───────────────────────────────────────────────────────────

class IaChatState {
  final List<ChatMensaje> mensajes;
  final bool cargando;
  final String? error;
  final String? _ultimoTexto;
  final String? _ultimoSystemPrompt;

  const IaChatState({
    this.mensajes = const [],
    this.cargando = false,
    this.error,
    String? ultimoTexto,
    String? ultimoSystemPrompt,
  })  : _ultimoTexto = ultimoTexto,
        _ultimoSystemPrompt = ultimoSystemPrompt;

  bool get puedeReintentar => error != null && _ultimoTexto != null;

  IaChatState copyWith({
    List<ChatMensaje>? mensajes,
    bool? cargando,
    String? error,
    bool clearError = false,
    String? ultimoTexto,
    String? ultimoSystemPrompt,
  }) {
    return IaChatState(
      mensajes: mensajes ?? this.mensajes,
      cargando: cargando ?? this.cargando,
      error: clearError ? null : (error ?? this.error),
      ultimoTexto: ultimoTexto ?? _ultimoTexto,
      ultimoSystemPrompt: ultimoSystemPrompt ?? _ultimoSystemPrompt,
    );
  }
}

class IaChatNotifier extends Notifier<IaChatState> {
  final _service = IaApiService();

  @override
  IaChatState build() => const IaChatState();

  Future<void> enviar({
    required String apiKey,
    required String systemPrompt,
    required String texto,
  }) async {
    final mensajeUsuario = ChatMensaje(
      rol: 'user',
      contenido: texto,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      mensajes: [...state.mensajes, mensajeUsuario],
      cargando: true,
      clearError: true,
      ultimoTexto: texto,
      ultimoSystemPrompt: systemPrompt,
    );

    try {
      final historial = state.mensajes.take(20).map((m) => {
        'role': m.rol,
        'content': m.contenido,
      }).toList();

      final respuesta = await _service.enviarMensaje(
        apiKey: apiKey,
        systemPrompt: systemPrompt,
        mensajes: historial,
      );

      final mensajeIA = ChatMensaje(
        rol: 'assistant',
        contenido: respuesta,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        mensajes: [...state.mensajes, mensajeIA],
        cargando: false,
      );
    } catch (e) {
      // Elimina el mensaje del usuario si falló para permitir reintento limpio
      final sinUltimo = state.mensajes.toList()..removeLast();
      state = state.copyWith(
        mensajes: sinUltimo,
        cargando: false,
        error: _parsearError(e),
      );
    }
  }

  Future<void> reintentar({required String apiKey}) async {
    final texto = state._ultimoTexto;
    final systemPrompt = state._ultimoSystemPrompt;
    if (texto == null || systemPrompt == null) return;
    await enviar(apiKey: apiKey, systemPrompt: systemPrompt, texto: texto);
  }

  void limpiarChat() {
    state = const IaChatState();
  }

  String _parsearError(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      // Extraer mensaje de error de Google
      String? googleMsg;
      if (data is Map) {
        final errorObj = data['error'];
        if (errorObj is Map) {
          googleMsg = errorObj['message'] as String?;
        }
        googleMsg ??= errorObj?.toString();
      }
      final msgLower = googleMsg?.toLowerCase() ?? '';
      if (status == 401 || msgLower.contains('api key') || msgLower.contains('incorrect')) {
        return 'API key incorrecta. Presioná 🔑, borrá la clave actual e ingresá la nueva desde console.groq.com';
      }
      if (status == 403) return 'Acceso denegado. Verificá que la clave de Grok esté activa en console.groq.com';
      if (status == 429) return 'Límite de requests alcanzado. Esperá un momento y reintentá.';
      if (googleMsg != null) return 'Error: $googleMsg';
      if (status != null) return 'Error HTTP $status. Revisá tu API key.';
    }
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('connection')) {
      return 'Sin conexión a internet.';
    }
    return 'Error: $msg';
  }
}

final iaChatProvider = NotifierProvider<IaChatNotifier, IaChatState>(
  IaChatNotifier.new,
);
