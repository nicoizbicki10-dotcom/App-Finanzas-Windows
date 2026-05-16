import 'package:dio/dio.dart';

import '../domain/dolar_quote.dart';

class DolarDatasource {
  final Dio _dio;

  DolarDatasource(this._dio);

  /// Obtiene todos los valores del dólar disponibles en Argentina
  Future<List<DolarQuote>> fetchAllDolares() async {
    final response = await _dio.get('/dolares');
    final List<dynamic> data = response.data as List<dynamic>;
    return data
        .map((e) => DolarQuote.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Obtiene un tipo específico de dólar
  Future<DolarQuote> fetchDolar(String tipo) async {
    // tipos: oficial, blue, bolsa, contadoconliqui, mayorista, tarjeta, cripto
    final response = await _dio.get('/dolares/$tipo');
    return DolarQuote.fromJson(response.data as Map<String, dynamic>);
  }
}
