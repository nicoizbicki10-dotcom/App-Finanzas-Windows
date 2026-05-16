import 'package:dio/dio.dart';

class ClaudeApiService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120),
  ));

  Future<String> enviarMensaje({
    required String apiKey,
    required String systemPrompt,
    required List<Map<String, String>> mensajes,
  }) async {
    final response = await _dio.post(
      'https://api.anthropic.com/v1/messages',
      options: Options(
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
      ),
      data: {
        'model': 'claude-sonnet-4-6',
        'max_tokens': 4096,
        'system': systemPrompt,
        'messages': mensajes.map((m) => {
          'role': m['role'],
          'content': m['content'],
        }).toList(),
      },
    );
    final content = response.data['content'] as List;
    return (content.first as Map)['text'] as String;
  }

  /// Analiza una imagen en base64 y devuelve texto (JSON de transacciones).
  Future<String> analizarConVision({
    required String apiKey,
    required String systemPrompt,
    required String base64Image,
    required String mediaType,
    String? textoAdicional,
  }) async {
    final response = await _dio.post(
      'https://api.anthropic.com/v1/messages',
      options: Options(
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
      ),
      data: {
        'model': 'claude-sonnet-4-6',
        'max_tokens': 4096,
        'system': systemPrompt,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': mediaType,
                  'data': base64Image,
                },
              },
              {
                'type': 'text',
                'text': textoAdicional ??
                    'Extraé todas las transacciones de esta imagen.',
              },
            ],
          }
        ],
      },
    );
    final content = response.data['content'] as List;
    return (content.first as Map)['text'] as String;
  }

  /// Analiza texto plano (extracto pegado) y devuelve JSON de transacciones.
  Future<String> analizarTexto({
    required String apiKey,
    required String systemPrompt,
    required String texto,
  }) async {
    final response = await _dio.post(
      'https://api.anthropic.com/v1/messages',
      options: Options(
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
      ),
      data: {
        'model': 'claude-sonnet-4-6',
        'max_tokens': 4096,
        'system': systemPrompt,
        'messages': [
          {
            'role': 'user',
            'content': texto,
          }
        ],
      },
    );
    final content = response.data['content'] as List;
    return (content.first as Map)['text'] as String;
  }
}
