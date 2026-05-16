import 'package:dio/dio.dart';

import '../constants/api_constants.dart';

class DioClient {
  late final Dio dolar;
  late final Dio coinGecko;
  late final Dio finnhub;
  late final Dio yahooFinance;
  late final Dio mercadoLibre;
  late final Dio forex;
  late final Dio metals;

  DioClient() {
    dolar = _createDio(ApiConstants.dolarApiBase);
    coinGecko = _createDio(ApiConstants.coinGeckoBase);
    finnhub = _createDio(
      ApiConstants.finnhubBase,
      queryParams: {'token': ApiConstants.finnhubApiKey},
    );
    yahooFinance = _createDio(
      ApiConstants.yahooFinanceBase,
      headers: {
        'User-Agent': 'Mozilla/5.0',
        'Accept': 'application/json',
      },
    );
    forex = _createDio(ApiConstants.openErApiBase);
    metals = _createDio(ApiConstants.metalsLiveBase);
    mercadoLibre = _createDio(
      ApiConstants.mercadoLibreBase,
      includeContentType: false,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    );
  }

  Dio _createDio(String baseUrl, {Map<String, dynamic>? queryParams, Map<String, String>? headers, bool includeContentType = true}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(milliseconds: ApiConstants.connectTimeout),
        receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeout),
        queryParameters: queryParams,
        headers: {
          'Accept': 'application/json',
          if (includeContentType) 'Content-Type': 'application/json',
          ...?headers,
        },
      ),
    );

    // Logging en debug
    dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        error: true,
        logPrint: (obj) => debugPrint('[DIO] $obj'),
      ),
    );

    return dio;
  }
}

void debugPrint(String message) {
  // ignore: avoid_print
  print(message);
}
