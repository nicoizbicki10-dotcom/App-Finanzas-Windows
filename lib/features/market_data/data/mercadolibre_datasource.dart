import 'package:dio/dio.dart';
import 'package:hive/hive.dart';

/// Resultado de la consulta de precio por m² en un barrio
class PrecioM2Result {
  final double precioM2USD;
  final int muestraCount; // cantidad de listados usados para el cálculo
  final String barrio;

  const PrecioM2Result({
    required this.precioM2USD,
    required this.muestraCount,
    required this.barrio,
  });
}

class MercadoLibreDatasource {
  final Dio _dio;
  final Box<Map>? _cache;

  static const _cacheTtlMs = 7 * 24 * 60 * 60 * 1000; // 7 días en ms

  MercadoLibreDatasource(this._dio, {Box<Map>? cache}) : _cache = cache;

  /// Obtiene la mediana de precio por m² en USD para un barrio o localidad.
  /// Cachea el resultado en Hive por 7 días para evitar consultas frecuentes.
  Future<PrecioM2Result> fetchPrecioM2(
    String barrio, {
    double dolarVenta = 1200.0,
  }) async {
    final cacheKey = 'precioM2_${barrio.toLowerCase().replaceAll(' ', '_')}';

    // Revisar caché Hive
    final cache = _cache;
    if (cache != null) {
      final cached = cache.get(cacheKey);
      if (cached != null) {
        final timestamp = (cached['timestamp'] as num?)?.toInt() ?? 0;
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (age < _cacheTtlMs) {
          return PrecioM2Result(
            precioM2USD: (cached['precioM2USD'] as num).toDouble(),
            muestraCount: (cached['muestraCount'] as num).toInt(),
            barrio: barrio,
          );
        }
      }
    }

    // Buscar departamentos en venta en el barrio (MLA1472 = Departamentos)
    final response = await _dio.get(
      '/sites/MLA/search',
      queryParameters: {
        'category': 'MLA1472',
        'q': barrio,
        'limit': 50,
      },
    );

    final results = (response.data['results'] as List?) ?? [];
    final ratios = <double>[];

    for (final item in results) {
      final price = (item['price'] as num?)?.toDouble();
      final currencyId = item['currency_id'] as String?;
      if (price == null || price <= 0) continue;

      // Convertir a USD
      double priceUSD;
      if (currencyId == 'USD') {
        priceUSD = price;
      } else if (currencyId == 'ARS' && dolarVenta > 0) {
        priceUSD = price / dolarVenta;
      } else {
        continue;
      }

      // Filtro de rango razonable para evitar outliers de precio total
      if (priceUSD < 10000 || priceUSD > 5000000) continue;

      // Buscar área en atributos
      final area = _extraerArea(item);
      if (area == null) continue;

      final ratio = priceUSD / area;
      // Filtro de precio/m² razonable (USD 500 a USD 15.000/m²)
      if (ratio < 500 || ratio > 15000) continue;

      ratios.add(ratio);
    }

    if (ratios.isEmpty) {
      return PrecioM2Result(precioM2USD: 0, muestraCount: 0, barrio: barrio);
    }

    ratios.sort();
    final mediana = _mediana(ratios);

    final result = PrecioM2Result(
      precioM2USD: mediana,
      muestraCount: ratios.length,
      barrio: barrio,
    );

    // Guardar en caché
    if (cache != null) {
      await cache.put(cacheKey, {
        'precioM2USD': result.precioM2USD,
        'muestraCount': result.muestraCount,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }

    return result;
  }

  double? _extraerArea(Map<String, dynamic> item) {
    // 1. Buscar en atributos (TOTAL_AREA tiene prioridad sobre COVERED_AREA)
    final attrs = item['attributes'] as List? ?? [];
    double? areaTotal;
    double? areaCubierta;

    for (final attr in attrs) {
      final id = attr['id'] as String? ?? '';
      final valueStr = attr['value_name'] as String? ?? '';
      final parsed = _parsearNumeroM2(valueStr);
      if (parsed == null || parsed < 10 || parsed > 2000) continue;

      if (id == 'TOTAL_AREA') areaTotal = parsed;
      if (id == 'COVERED_AREA') areaCubierta = parsed;
    }

    if (areaTotal != null) return areaTotal;
    if (areaCubierta != null) return areaCubierta;

    // 2. Fallback: parsear del título ("80 m²", "80m2", "80 metros")
    final title = item['title'] as String? ?? '';
    return _extraerAreaDeTitulo(title);
  }

  double? _parsearNumeroM2(String text) {
    final numStr = RegExp(r'[\d.]+').firstMatch(text)?.group(0);
    return numStr != null ? double.tryParse(numStr) : null;
  }

  double? _extraerAreaDeTitulo(String title) {
    // Patrones: "80 m²", "80m²", "80 m2", "80m2", "80 metros cuadrados"
    final patterns = [
      RegExp(r'(\d+\.?\d*)\s*m[²2]', caseSensitive: false),
      RegExp(r'(\d+\.?\d*)\s*metros?\s*cuadrados?', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(title);
      if (match != null) {
        final val = double.tryParse(match.group(1)!);
        if (val != null && val > 10 && val < 2000) return val;
      }
    }
    return null;
  }

  /// Obtiene el precio promedio de un vehículo en ARS buscando en MercadoLibre.
  /// Devuelve null si no hay resultados o hubo un error.
  Future<double?> fetchPrecioVehiculo(String modelo, int anio) async {
    try {
      final response = await _dio.get(
        '/sites/MLA/search',
        queryParameters: {
          'q': '$modelo $anio',
          'category': 'MLA1744', // Autos y camionetas
          'limit': 30,
          'condition': 'used',
        },
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      final results = (response.data['results'] as List?) ?? [];
      if (results.isEmpty) return null;

      final precios = results
          .map((r) => (r['price'] as num?)?.toDouble())
          .whereType<double>()
          .where((p) => p > 0)
          .toList()
        ..sort();

      if (precios.isEmpty) return null;

      // Eliminar el 10% inferior y superior para quitar outliers
      final trimStart = (precios.length * 0.1).ceil();
      final trimEnd = (precios.length * 0.9).floor();
      final trimmed = trimEnd > trimStart
          ? precios.sublist(trimStart, trimEnd)
          : precios;

      return trimmed.reduce((a, b) => a + b) / trimmed.length;
    } catch (_) {
      return null;
    }
  }

  double _mediana(List<double> sorted) {
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }
}
