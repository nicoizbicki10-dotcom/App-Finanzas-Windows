import 'package:dio/dio.dart';

import '../domain/stock_quote.dart';

class FinnhubDatasource {
  final Dio _dio;

  FinnhubDatasource(this._dio);

  /// Obtiene cotización actual de un ticker
  Future<StockQuote> fetchQuote(String symbol) async {
    final response = await _dio.get(
      '/quote',
      queryParameters: {'symbol': symbol},
    );
    return StockQuote.fromFinnhub(
      symbol,
      response.data as Map<String, dynamic>,
    );
  }

  /// Obtiene velas diarias (historial de precios)
  Future<List<Map<String, dynamic>>> fetchCandles(
    String symbol, {
    required DateTime from,
    required DateTime to,
    String resolution = 'D', // D = diario, W = semanal, M = mensual
  }) async {
    final response = await _dio.get(
      '/stock/candle',
      queryParameters: {
        'symbol': symbol,
        'resolution': resolution,
        'from': from.millisecondsSinceEpoch ~/ 1000,
        'to': to.millisecondsSinceEpoch ~/ 1000,
      },
    );

    final data = response.data as Map<String, dynamic>;
    if (data['s'] != 'ok') return [];

    final closes = List<double>.from(
      (data['c'] as List).map((e) => (e as num).toDouble()),
    );
    final timestamps = List<int>.from(data['t'] as List);

    return List.generate(
      closes.length,
      (i) => {
        'timestamp': timestamps[i],
        'close': closes[i],
      },
    );
  }

  /// Busca símbolos por nombre (para agregar acciones)
  Future<List<Map<String, dynamic>>> searchSymbol(String query) async {
    final response = await _dio.get(
      '/search',
      queryParameters: {'q': query},
    );

    final data = response.data as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(
      (data['result'] as List? ?? []).map(
        (e) => e as Map<String, dynamic>,
      ),
    );
  }
}
