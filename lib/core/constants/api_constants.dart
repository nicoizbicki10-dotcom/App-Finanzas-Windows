abstract class ApiConstants {
  // APIs gratuitas — sin clave necesaria
  static const String dolarApiBase = 'https://dolarapi.com/v1';
  static const String coinGeckoBase = 'https://api.coingecko.com/api/v3';
  static const String yahooFinanceBase = 'https://query1.finance.yahoo.com';
  static const String mercadoLibreBase = 'https://api.mercadolibre.com';
  static const String openErApiBase    = 'https://open.er-api.com/v6';
  static const String metalsLiveBase   = 'https://metals.live';

  // TTL de caché de tasas forex (segundos) — 6 horas
  static const int forexCacheTtl = 21600;

  // Finnhub (ya no usado — reemplazado por Yahoo Finance)
  static const String finnhubBase = 'https://finnhub.io/api/v1';
  static const String finnhubApiKey = '';

  // Timeouts (ms)
  static const int connectTimeout = 10000;
  static const int receiveTimeout = 15000;

  // TTL de caché (segundos)
  static const int dolarCacheTtl = 300;     // 5 minutos
  static const int cryptoCacheTtl = 60;     // 1 minuto
  static const int stockCacheTtl = 15;      // 15 segundos
  static const int stockHistoryCacheTtl = 3600; // 1 hora

  // Intervalo de actualización automática (segundos)
  static const int dolarRefreshInterval = 300;
  static const int cryptoRefreshInterval = 60;
  static const int stockRefreshInterval = 30;
}
