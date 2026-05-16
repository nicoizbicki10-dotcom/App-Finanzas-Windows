import 'package:dio/dio.dart';

import '../domain/crypto_price.dart';

class CoinGeckoDatasource {
  final Dio _dio;

  CoinGeckoDatasource(this._dio);

  /// Obtiene precios en batch para una lista de coin IDs (ej: bitcoin, ethereum)
  Future<List<CryptoPrice>> fetchMarkets(List<String> coinIds) async {
    if (coinIds.isEmpty) return [];

    final response = await _dio.get(
      '/coins/markets',
      queryParameters: {
        'vs_currency': 'usd',
        'ids': coinIds.join(','),
        'order': 'market_cap_desc',
        'per_page': 250,
        'page': 1,
        'sparkline': false,
        'price_change_percentage': '24h',
      },
    );

    final List<dynamic> data = response.data as List<dynamic>;
    return data
        .map((e) => CryptoPrice.fromCoinGecko(e as Map<String, dynamic>))
        .toList();
  }

  /// Obtiene top N criptomonedas por market cap
  Future<List<CryptoPrice>> fetchTopCryptos({int limit = 50}) async {
    final response = await _dio.get(
      '/coins/markets',
      queryParameters: {
        'vs_currency': 'usd',
        'order': 'market_cap_desc',
        'per_page': limit,
        'page': 1,
        'sparkline': false,
        'price_change_percentage': '24h',
      },
    );

    final List<dynamic> data = response.data as List<dynamic>;
    return data
        .map((e) => CryptoPrice.fromCoinGecko(e as Map<String, dynamic>))
        .toList();
  }
}
