class CryptoPrice {
  final String id;
  final String symbol;
  final String name;
  final String imageUrl;
  final double currentPrice;
  final double marketCap;
  final int marketCapRank;
  final double totalVolume;
  final double high24h;
  final double low24h;
  final double priceChange24h;
  final double priceChangePercent24h;
  final double? circulatingSupply;
  final double? maxSupply;
  final double ath;
  final double athChangePercent;
  final DateTime lastUpdated;

  const CryptoPrice({
    required this.id,
    required this.symbol,
    required this.name,
    required this.imageUrl,
    required this.currentPrice,
    required this.marketCap,
    required this.marketCapRank,
    required this.totalVolume,
    required this.high24h,
    required this.low24h,
    required this.priceChange24h,
    required this.priceChangePercent24h,
    this.circulatingSupply,
    this.maxSupply,
    required this.ath,
    required this.athChangePercent,
    required this.lastUpdated,
  });

  // CoinGecko /coins/markets response format
  factory CryptoPrice.fromCoinGecko(Map<String, dynamic> json) {
    return CryptoPrice(
      id: json['id'] as String? ?? '',
      symbol: (json['symbol'] as String? ?? '').toUpperCase(),
      name: json['name'] as String? ?? '',
      imageUrl: json['image'] as String? ?? '',
      currentPrice: (json['current_price'] as num?)?.toDouble() ?? 0.0,
      marketCap: (json['market_cap'] as num?)?.toDouble() ?? 0.0,
      marketCapRank: json['market_cap_rank'] as int? ?? 0,
      totalVolume: (json['total_volume'] as num?)?.toDouble() ?? 0.0,
      high24h: (json['high_24h'] as num?)?.toDouble() ?? 0.0,
      low24h: (json['low_24h'] as num?)?.toDouble() ?? 0.0,
      priceChange24h: (json['price_change_24h'] as num?)?.toDouble() ?? 0.0,
      priceChangePercent24h:
          (json['price_change_percentage_24h'] as num?)?.toDouble() ?? 0.0,
      circulatingSupply: (json['circulating_supply'] as num?)?.toDouble(),
      maxSupply: (json['max_supply'] as num?)?.toDouble(),
      ath: (json['ath'] as num?)?.toDouble() ?? 0.0,
      athChangePercent:
          (json['ath_change_percentage'] as num?)?.toDouble() ?? 0.0,
      lastUpdated: json['last_updated'] != null
          ? DateTime.tryParse(json['last_updated'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  bool get isPositive => priceChangePercent24h >= 0;
}
