class StockQuote {
  final String symbol;
  final double currentPrice;
  final double change;
  final double changePercent;
  final double high24h;
  final double low24h;
  final double openPrice;
  final double previousClose;
  final DateTime timestamp;

  const StockQuote({
    required this.symbol,
    required this.currentPrice,
    required this.change,
    required this.changePercent,
    required this.high24h,
    required this.low24h,
    required this.openPrice,
    required this.previousClose,
    required this.timestamp,
  });

  // Finnhub /quote response format
  factory StockQuote.fromFinnhub(String symbol, Map<String, dynamic> json) {
    return StockQuote(
      symbol: symbol,
      currentPrice: (json['c'] as num?)?.toDouble() ?? 0.0,
      change: (json['d'] as num?)?.toDouble() ?? 0.0,
      changePercent: (json['dp'] as num?)?.toDouble() ?? 0.0,
      high24h: (json['h'] as num?)?.toDouble() ?? 0.0,
      low24h: (json['l'] as num?)?.toDouble() ?? 0.0,
      openPrice: (json['o'] as num?)?.toDouble() ?? 0.0,
      previousClose: (json['pc'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['t'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['t'] as int) * 1000)
          : DateTime.now(),
    );
  }

  bool get isPositive => changePercent >= 0;

  StockQuote copyWith({String? symbol, double? currentPrice}) {
    return StockQuote(
      symbol: symbol ?? this.symbol,
      currentPrice: currentPrice ?? this.currentPrice,
      change: change,
      changePercent: changePercent,
      high24h: high24h,
      low24h: low24h,
      openPrice: openPrice,
      previousClose: previousClose,
      timestamp: timestamp,
    );
  }
}
