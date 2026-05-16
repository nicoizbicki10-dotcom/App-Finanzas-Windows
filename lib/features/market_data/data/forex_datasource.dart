import 'package:dio/dio.dart';

/// Obtiene tasas de cambio respecto al USD usando open.er-api.com (gratuito, sin clave).
/// Retorna un mapa { "EUR": 0.92, "GBP": 0.79, ... } donde el valor es cuántas
/// unidades de esa moneda equivalen a 1 USD.
class ForexDatasource {
  final Dio _dio;
  ForexDatasource(this._dio);

  static const _needed = ['EUR', 'CHF', 'GBP', 'BRL', 'CNY', 'JPY'];

  Future<Map<String, double>> fetchRates() async {
    final response = await _dio.get<Map<String, dynamic>>('/latest/USD');
    final data = response.data;
    if (data == null) return {};
    final rates = data['rates'] as Map<String, dynamic>? ?? {};
    return {
      for (final code in _needed)
        if (rates.containsKey(code)) code: (rates[code] as num).toDouble(),
    };
  }
}
