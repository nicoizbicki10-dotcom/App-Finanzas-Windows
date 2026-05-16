import 'package:dio/dio.dart';

class IaApiService {
  static const _modelo = 'llama-3.3-70b-versatile';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
  ));

  Future<String> enviarMensaje({
    required String apiKey,
    required String systemPrompt,
    required List<Map<String, String>> mensajes,
  }) async {
    final messages = [
      {'role': 'system', 'content': systemPrompt},
      ...mensajes.map((m) => {'role': m['role']!, 'content': m['content']!}),
    ];

    final response = await _dio.post(
      'https://api.groq.com/openai/v1/chat/completions',
      options: Options(headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      }),
      data: {
        'model': _modelo,
        'messages': messages,
        'max_tokens': 2048,
        'temperature': 0.7,
      },
    );

    final choices = response.data['choices'] as List;
    return (choices.first as Map)['message']['content'] as String;
  }
}
