import 'package:dio/dio.dart';

class GeminiVisionService {
  static const _modelo = 'gemini-2.0-flash';
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_modelo:generateContent';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120),
  ));

  Future<String> analizarTexto({
    required String apiKey,
    required String systemPrompt,
    required String texto,
  }) async {
    final response = await _dio.post(
      '$_baseUrl?key=$apiKey',
      data: {
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt}
          ],
        },
        'contents': [
          {
            'parts': [
              {'text': texto}
            ],
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'maxOutputTokens': 4096,
        },
      },
    );
    return _extraerTexto(response.data);
  }

  Future<String> analizarImagen({
    required String apiKey,
    required String systemPrompt,
    required String base64Image,
    required String mediaType,
    String? textoAdicional,
  }) async {
    final response = await _dio.post(
      '$_baseUrl?key=$apiKey',
      data: {
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt}
          ],
        },
        'contents': [
          {
            'parts': [
              {
                'inlineData': {
                  'mimeType': mediaType,
                  'data': base64Image,
                },
              },
              {
                'text': textoAdicional ??
                    'Extraé todas las transacciones de esta imagen.',
              },
            ],
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'maxOutputTokens': 4096,
        },
      },
    );
    return _extraerTexto(response.data);
  }

  String _extraerTexto(dynamic data) {
    final candidates = data['candidates'] as List;
    final content = candidates.first['content'] as Map;
    final parts = content['parts'] as List;
    return (parts.first as Map)['text'] as String;
  }
}
