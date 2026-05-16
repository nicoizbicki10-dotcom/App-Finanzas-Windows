import 'package:dio/dio.dart';

class MetalsDatasource {
  final Dio _dio;
  MetalsDatasource(this._dio);

  /// Retorna precios spot en USD por troy oz: { 'gold': X, 'silver': Y }.
  Future<Map<String, double>> fetchSpotPrices() async {
    final response = await _dio.get('/api/spot-price');
    final list = response.data as List;
    if (list.isEmpty) return {};
    final map = Map<String, dynamic>.from(list.first as Map);
    return {
      if (map['gold'] != null) 'gold': (map['gold'] as num).toDouble(),
      if (map['silver'] != null) 'silver': (map['silver'] as num).toDouble(),
    };
  }
}
