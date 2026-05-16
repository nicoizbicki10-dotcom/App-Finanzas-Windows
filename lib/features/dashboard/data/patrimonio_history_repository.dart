import 'package:hive/hive.dart';

import '../../../core/storage/storage_keys.dart';

/// Guarda snapshots mensuales del patrimonio total e individual por sección.
/// Key total:   '_psnap_{userId}_{YYYY}_{MM}'
/// Key sección: '_psnap_sec_{userId}_{seccion}_{YYYY}_{MM}'
class PatrimonioHistoryRepository {
  final String userId;
  PatrimonioHistoryRepository({required this.userId});

  Box<Map> get _box => Hive.box<Map>(StorageKeys.cacheBox);

  String _key(int year, int month) =>
      '_psnap_${userId}_${year}_${month.toString().padLeft(2, '0')}';

  String _secKey(String seccion, int year, int month) =>
      '_psnap_sec_${userId}_${seccion}_${year}_${month.toString().padLeft(2, '0')}';

  Future<void> guardarMesActual(double valorUSD) async {
    final now = DateTime.now();
    await _box.put(_key(now.year, now.month), {'v': valorUSD});
  }

  Future<void> guardarSecciones(Map<String, double> valores) async {
    final now = DateTime.now();
    for (final e in valores.entries) {
      if (e.value > 0) {
        await _box.put(_secKey(e.key, now.year, now.month), {'v': e.value});
      }
    }
  }

  /// Valor guardado hace exactamente 12 meses para una sección.
  double? getSeccionHace12Meses(String seccion) {
    final now = DateTime.now();
    final hace12 = DateTime(now.year - 1, now.month);
    final raw = _box.get(_secKey(seccion, hace12.year, hace12.month));
    return (raw?['v'] as num?)?.toDouble();
  }

  /// Solo para testing: guarda valores de hace 12 meses con factores distintos por sección.
  /// Permite verificar que cada sección muestra su propia variación independiente.
  Future<void> seedDatosHace12Meses(Map<String, double> valoresActuales) async {
    final now = DateTime.now();
    final hace12 = DateTime(now.year - 1, now.month);
    // Factores distintos para que cada sección muestre un % diferente
    const factores = {
      'inmuebles':    0.85,  // → +17.6%
      'acciones':     0.60,  // → +66.7%
      'cripto':       0.40,  // → +150%
      'liquidez':     0.95,  // → +5.3%
      'instrumentos': 0.80,  // → +25%
      'bienes':       0.90,  // → +11.1%
      'otras':        1.10,  // → -9.1%  (bajó)
      'negocios':     0.70,  // → +42.9%
    };
    for (final e in valoresActuales.entries) {
      if (e.value > 0) {
        final factor = factores[e.key] ?? 0.80;
        await _box.put(
          _secKey(e.key, hace12.year, hace12.month),
          {'v': e.value * factor},
        );
      }
    }
  }

  /// Elimina los datos de testing de hace 12 meses.
  Future<void> borrarDatosHace12Meses() async {
    final now = DateTime.now();
    final hace12 = DateTime(now.year - 1, now.month);
    for (final sec in ['inmuebles', 'acciones', 'cripto', 'liquidez', 'instrumentos', 'bienes', 'otras', 'negocios']) {
      await _box.delete(_secKey(sec, hace12.year, hace12.month));
    }
  }

  /// Últimos N meses (más reciente al final). Meses sin datos = 0.
  List<({DateTime mes, double valorUSD})> getUltimosMeses(int n) {
    final result = <({DateTime mes, double valorUSD})>[];
    final now = DateTime.now();
    for (int i = n - 1; i >= 0; i--) {
      final mes = DateTime(now.year, now.month - i, 1);
      final raw = _box.get(_key(mes.year, mes.month));
      final valor = (raw?['v'] as num?)?.toDouble() ?? 0.0;
      result.add((mes: mes, valorUSD: valor));
    }
    return result;
  }

  /// Valor por año para los últimos N años.
  /// Año en curso: último snapshot disponible (el año no está completo).
  /// Años anteriores: promedio de los meses con datos.
  List<({int anio, double valorUSD})> getUltimosAnios(int n) {
    final result = <({int anio, double valorUSD})>[];
    final now = DateTime.now();
    for (int i = n - 1; i >= 0; i--) {
      final anio = now.year - i;
      if (anio == now.year) {
        // Año actual: usar el valor del mes más reciente disponible
        double valorActual = 0;
        for (int mes = now.month; mes >= 1; mes--) {
          final raw = _box.get(_key(anio, mes));
          final valor = (raw?['v'] as num?)?.toDouble();
          if (valor != null && valor > 0) {
            valorActual = valor;
            break;
          }
        }
        result.add((anio: anio, valorUSD: valorActual));
      } else {
        // Años anteriores: promedio anual
        double suma = 0;
        int count = 0;
        for (int mes = 1; mes <= 12; mes++) {
          final raw = _box.get(_key(anio, mes));
          final valor = (raw?['v'] as num?)?.toDouble();
          if (valor != null && valor > 0) {
            suma += valor;
            count++;
          }
        }
        result.add((anio: anio, valorUSD: count > 0 ? suma / count : 0.0));
      }
    }
    return result;
  }
}
