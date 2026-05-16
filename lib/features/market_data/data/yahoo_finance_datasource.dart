import 'package:dio/dio.dart';

import '../domain/stock_quote.dart';

class YahooFinanceDatasource {
  final Dio _dio;

  YahooFinanceDatasource(this._dio);

  /// Obtiene cotización actual de un ticker usando Yahoo Finance (sin API key)
  /// Para acciones argentinas en BYMA usar sufijo .BA (ej: GGAL.BA, YPF.BA)
  /// Para acciones en NYSE/NASDAQ usar el ticker directo (ej: AAPL, MSFT)
  Future<StockQuote> fetchQuote(String symbol) async {
    final response = await _dio.get(
      '/v8/finance/chart/$symbol',
      queryParameters: {
        'interval': '1d',
        'range': '1d',
      },
    );

    final chart = response.data['chart'] as Map<String, dynamic>;
    final results = chart['result'] as List?;
    if (results == null || results.isEmpty) {
      throw Exception('No data for $symbol');
    }

    final meta = results.first['meta'] as Map<String, dynamic>;

    final currentPrice = (meta['regularMarketPrice'] as num?)?.toDouble() ?? 0.0;
    final previousClose = (meta['chartPreviousClose'] as num?)?.toDouble() ??
        (meta['previousClose'] as num?)?.toDouble() ?? 0.0;
    final change = currentPrice - previousClose;
    final changePercent = previousClose > 0 ? (change / previousClose) * 100 : 0.0;

    return StockQuote(
      symbol: symbol,
      currentPrice: currentPrice,
      change: change,
      changePercent: changePercent,
      high24h: (meta['regularMarketDayHigh'] as num?)?.toDouble() ?? 0.0,
      low24h: (meta['regularMarketDayLow'] as num?)?.toDouble() ?? 0.0,
      openPrice: (meta['regularMarketOpen'] as num?)?.toDouble() ?? 0.0,
      previousClose: previousClose,
      timestamp: DateTime.now(),
    );
  }
}
