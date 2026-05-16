import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/storage/storage_keys.dart';
import '../../../core/network/dio_client.dart';
import '../data/coingecko_datasource.dart';
import '../data/dolar_datasource.dart';
import '../data/finnhub_datasource.dart';
import '../data/forex_datasource.dart';
import '../data/mercadolibre_datasource.dart';
import '../data/metals_datasource.dart';
import '../data/yahoo_finance_datasource.dart';
import '../domain/crypto_price.dart';
import '../domain/dolar_quote.dart';
import '../domain/stock_quote.dart';

// ─── Infraestructura ──────────────────────────────────────────────────────────

final dioClientProvider = Provider<DioClient>((ref) => DioClient());

final dolarDatasourceProvider = Provider<DolarDatasource>((ref) {
  return DolarDatasource(ref.watch(dioClientProvider).dolar);
});

final coinGeckoDatasourceProvider = Provider<CoinGeckoDatasource>((ref) {
  return CoinGeckoDatasource(ref.watch(dioClientProvider).coinGecko);
});

final finnhubDatasourceProvider = Provider<FinnhubDatasource>((ref) {
  return FinnhubDatasource(ref.watch(dioClientProvider).finnhub);
});

final yahooFinanceDatasourceProvider = Provider<YahooFinanceDatasource>((ref) {
  return YahooFinanceDatasource(ref.watch(dioClientProvider).yahooFinance);
});

final mercadoLibreDatasourceProvider = Provider<MercadoLibreDatasource>((ref) {
  return MercadoLibreDatasource(
    ref.watch(dioClientProvider).mercadoLibre,
    cache: Hive.box<Map>(StorageKeys.cacheBox),
  );
});

final metalsDatasourceProvider = Provider<MetalsDatasource>((ref) {
  return MetalsDatasource(ref.watch(dioClientProvider).metals);
});

// ─── Metales Preciosos (via Yahoo Finance) ────────────────────────────────────

/// Precio del oro en USD por troy oz (GC=F — COMEX Gold Futures). 0 si no disponible.
final goldSpotPriceUSDProvider = Provider<double>((ref) {
  return ref.watch(stockQuoteProvider('GC=F')).value?.currentPrice ?? 0.0;
});

/// Precio de la plata en USD por troy oz (SI=F — COMEX Silver Futures). 0 si no disponible.
final silverSpotPriceUSDProvider = Provider<double>((ref) {
  return ref.watch(stockQuoteProvider('SI=F')).value?.currentPrice ?? 0.0;
});

/// Precios spot de metales en USD por troy oz: { 'gold': X, 'silver': Y }.
final metalSpotPricesProvider = FutureProvider<Map<String, double>>((ref) async {
  return {
    'gold': ref.watch(goldSpotPriceUSDProvider),
    'silver': ref.watch(silverSpotPriceUSDProvider),
  };
});

// ─── Dólar ────────────────────────────────────────────────────────────────────

/// Polling automático cada 5 minutos
final dolarProvider = StreamProvider<List<DolarQuote>>((ref) async* {
  final ds = ref.watch(dolarDatasourceProvider);

  while (true) {
    try {
      final data = await ds.fetchAllDolares();
      yield data;
    } catch (e) {
      yield [];
    }
    await Future.delayed(
      const Duration(seconds: ApiConstants.dolarRefreshInterval),
    );
  }
});

/// Dólar blue venta actual (fallback 1000 si no hay datos)
final dolarBlueVentaProvider = Provider<double>((ref) {
  final quotes = ref.watch(dolarProvider).whenOrNull(data: (q) => q) ?? [];
  final blue = quotes.where((d) => d.casa.toLowerCase() == 'blue').firstOrNull;
  return blue?.venta ?? 1000.0;
});

// ─── Criptomonedas ────────────────────────────────────────────────────────────

/// Precios en tiempo real con auto-refresh cada 60 segundos.
/// El parámetro es una String con los coin IDs separados por coma (ej: "bitcoin,ethereum").
/// Usar String en lugar de List para que Riverpod detecte correctamente el cambio de key.
final cryptoPricesProvider =
    StreamProvider.family<List<CryptoPrice>, String>((ref, coinIdsStr) async* {
  if (coinIdsStr.isEmpty) {
    yield [];
    return;
  }

  final ds = ref.watch(coinGeckoDatasourceProvider);
  final coinIds = coinIdsStr.split(',').where((s) => s.isNotEmpty).toList();

  while (true) {
    try {
      final prices = await ds.fetchMarkets(coinIds);
      yield prices;
    } catch (e) {
      // silenciar — se mantiene el último valor emitido
    }
    await Future.delayed(
      const Duration(seconds: ApiConstants.cryptoRefreshInterval),
    );
  }
});

/// Tasas de cambio vs USD para monedas fiat adicionales.
/// { "EUR": 0.92, "CHF": 0.90, "GBP": 0.79, "BRL": 5.1, "CNY": 7.3, "JPY": 155.0 }
final fiatRatesProvider = FutureProvider<Map<String, double>>((ref) async {
  final ds = ForexDatasource(ref.watch(dioClientProvider).forex);
  return ds.fetchRates();
});

/// Precio de Bitcoin en USD (actualizado via streaming de CoinGecko).
final btcPriceUSDProvider = Provider<double>((ref) {
  final prices = ref.watch(cryptoPricesProvider('bitcoin')).value;
  return prices?.firstOrNull?.currentPrice ?? 0.0;
});

/// Top 50 criptomonedas por market cap (para selección al agregar)
final topCryptosProvider = FutureProvider<List<CryptoPrice>>((ref) async {
  final ds = ref.watch(coinGeckoDatasourceProvider);
  return ds.fetchTopCryptos(limit: 50);
});

// ─── Acciones (Yahoo Finance — sin API key) ───────────────────────────────────

/// Cotización en tiempo real con auto-refresh cada 30 segundos.
/// Para acciones argentinas (BYMA) agregar sufijo .BA al ticker (ej: GGAL.BA).
final stockQuoteProvider =
    StreamProvider.family<StockQuote, String>((ref, symbol) async* {
  final ds = ref.watch(yahooFinanceDatasourceProvider);

  while (true) {
    try {
      final quote = await ds.fetchQuote(symbol);
      yield quote;
    } catch (e) {
      // silenciar — se reintenta en el próximo ciclo
    }
    await Future.delayed(
      const Duration(seconds: ApiConstants.stockRefreshInterval),
    );
  }
});

/// Búsqueda de símbolos (mantiene Finnhub como fallback)
final stockSearchProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, query) async {
    if (query.isEmpty) return [];
    final ds = ref.watch(finnhubDatasourceProvider);
    return ds.searchSymbol(query);
  },
);

// ─── Top 20 acciones mundiales ────────────────────────────────────────────────

/// IDs de CoinGecko de las 20 criptomonedas más populares
const List<String> topCryptoIds = [
  'bitcoin', 'ethereum', 'tether', 'binancecoin', 'solana',
  'ripple', 'usd-coin', 'dogecoin', 'cardano', 'tron',
  'avalanche-2', 'shiba-inu', 'chainlink', 'polkadot', 'bitcoin-cash',
  'near', 'litecoin', 'uniswap', 'pepe', 'stellar',
];

/// Tickers de las 20 acciones más populares del mundo (Yahoo Finance)
const List<String> worldStockTickers = [
  'AAPL', 'MSFT', 'GOOGL', 'AMZN', 'META',
  'TSLA', 'NVDA', 'JPM', 'V', 'WMT',
  'JNJ', 'PG', 'UNH', 'MA', 'HD',
  'BAC', 'DIS', 'NFLX', 'XOM', 'BRK-B',
];

// ─── Inmuebles (MercadoLibre) ─────────────────────────────────────────────────

// ─── Vehículos (MercadoLibre) ─────────────────────────────────────────────────

/// Precio promedio de un vehículo en ARS obtenido de MercadoLibre.
/// Parámetro: "$modelo|$anio" (separado por pipe para usar como family key).
final precioVehiculoProvider =
    FutureProvider.family<double?, String>((ref, key) async {
  final parts = key.split('|');
  if (parts.length < 2) return null;
  final modelo = parts[0].trim();
  final anio = int.tryParse(parts[1].trim());
  if (modelo.isEmpty || anio == null) return null;
  final ds = ref.watch(mercadoLibreDatasourceProvider);
  return ds.fetchPrecioVehiculo(modelo, anio);
});

// ─── Inmuebles (MercadoLibre) ─────────────────────────────────────────────────

/// Precio por m² en USD para un barrio/localidad.
/// Se calcula a partir de la mediana de listados de MercadoLibre.
/// Se actualiza una vez por sesión (los precios inmobiliarios no cambian por hora).
final precioM2BarrioProvider =
    FutureProvider.family<PrecioM2Result, String>((ref, barrio) async {
  if (barrio.trim().isEmpty) {
    return PrecioM2Result(precioM2USD: 0, muestraCount: 0, barrio: barrio);
  }

  // Usar el dólar blue actual para convertir precios ARS
  final dolarAsync = ref.watch(dolarProvider);
  final dolares = dolarAsync.value ?? [];
  final dolarVenta = dolares
          .where((d) => d.casa.toLowerCase() == 'blue')
          .map((d) => d.venta)
          .firstOrNull ??
      1200.0;

  final ds = ref.watch(mercadoLibreDatasourceProvider);
  try {
    return await ds.fetchPrecioM2(barrio.trim(), dolarVenta: dolarVenta);
  } catch (_) {
    // API error (403, timeout, etc.) — fallback silencioso
    return PrecioM2Result(precioM2USD: 0, muestraCount: 0, barrio: barrio);
  }
});
