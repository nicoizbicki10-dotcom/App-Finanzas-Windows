import 'package:intl/intl.dart';

abstract class CurrencyFormatter {
  static final _arsFormatter = NumberFormat.currency(
    locale: 'es_AR',
    symbol: '\$',
    decimalDigits: 2,
  );

  static final _usdFormatter = NumberFormat.currency(
    locale: 'en_US',
    symbol: 'USD ',
    decimalDigits: 2,
  );

  static final _compactFormatter = NumberFormat.compact(locale: 'es_AR');

  static String ars(double amount) => _arsFormatter.format(amount);

  static String usd(double amount) => _usdFormatter.format(amount);

  static String compact(double amount) {
    if (amount.abs() >= 1000000) {
      return '\$${_compactFormatter.format(amount)}';
    }
    return ars(amount);
  }

  static String usdCompact(double amount) {
    if (amount.abs() >= 1000000) {
      return 'USD ${(amount / 1000000).toStringAsFixed(2)}M';
    } else if (amount.abs() >= 1000) {
      return 'USD ${(amount / 1000).toStringAsFixed(1)}K';
    }
    return usd(amount);
  }

  static String percentage(double pct, {int decimals = 2}) {
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(decimals)}%';
  }

  static String crypto(double amount, String symbol) {
    if (amount < 0.001) {
      return '${amount.toStringAsFixed(8)} $symbol';
    } else if (amount < 1) {
      return '${amount.toStringAsFixed(4)} $symbol';
    }
    return '${amount.toStringAsFixed(2)} $symbol';
  }

  static String btc(double btcAmount) {
    if (btcAmount.abs() < 0.000001) return '₿ 0.00';
    if (btcAmount.abs() < 0.001) return '₿ ${btcAmount.toStringAsFixed(6)}';
    if (btcAmount.abs() < 1) return '₿ ${btcAmount.toStringAsFixed(4)}';
    return '₿ ${btcAmount.toStringAsFixed(2)}';
  }

  // Symbols and decimal config for each fiat currency code
  static const _fiatSymbol = {
    'EUR': '€',
    'CHF': 'CHF ',
    'GBP': '£',
    'BRL': 'R\$ ',
    'CNY': '¥',
    'JPY': '¥',
  };

  static String _fiatCompact(double amount, String code) {
    final symbol = _fiatSymbol[code] ?? '$code ';
    final isJPY = code == 'JPY';
    final decimals = isJPY ? 0 : 2;
    if (amount.abs() >= 1000000) {
      return '$symbol${(amount / 1000000).toStringAsFixed(decimals)}M';
    } else if (amount.abs() >= 1000) {
      return '$symbol${(amount / 1000).toStringAsFixed(decimals)}K';
    }
    return '$symbol${amount.toStringAsFixed(decimals)}';
  }

  /// Convierte un monto USD a la moneda de visualización seleccionada.
  /// [currency]: 'USD', 'ARS', 'BTC', 'EUR', 'CHF', 'GBP', 'BRL', 'CNY', 'JPY'
  static String fromUSD(
    double amountUSD,
    String currency, {
    double dolarBlue = 0,
    double btcPrice = 0,
    Map<String, double> fiatRates = const {},
  }) {
    switch (currency) {
      case 'ARS':
        return compact(amountUSD * dolarBlue);
      case 'BTC':
        return btc(btcPrice > 0 ? amountUSD / btcPrice : 0.0);
      case 'EUR':
      case 'CHF':
      case 'GBP':
      case 'BRL':
      case 'CNY':
      case 'JPY':
        final rate = fiatRates[currency] ?? 0;
        return rate > 0
            ? _fiatCompact(amountUSD * rate, currency)
            : usdCompact(amountUSD);
      default:
        return usdCompact(amountUSD);
    }
  }

  /// Texto secundario (equivalente en otra moneda).
  static String secondaryFromUSD(
    double amountUSD,
    String currency, {
    double dolarBlue = 0,
    double btcPrice = 0,
    Map<String, double> fiatRates = const {},
  }) {
    switch (currency) {
      case 'ARS':
        return '≈ ${usdCompact(amountUSD)}';
      case 'BTC':
        return '≈ ${usdCompact(amountUSD)}';
      case 'EUR':
      case 'CHF':
      case 'GBP':
      case 'BRL':
      case 'CNY':
      case 'JPY':
        if (dolarBlue > 0) {
          return '≈ ${compact(amountUSD * dolarBlue)} ARS';
        }
        return '≈ ${usdCompact(amountUSD)}';
      default:
        if (dolarBlue > 0) {
          return '≈ ${compact(amountUSD * dolarBlue)} ARS';
        }
        return '';
    }
  }
}
