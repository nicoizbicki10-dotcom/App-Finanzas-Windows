import 'package:hive/hive.dart';

import '../../../core/storage/storage_keys.dart';
import '../domain/ingreso.dart';

class IngresosRepository {
  final String userId;
  IngresosRepository({required this.userId});

  Box<Map> get _box => Hive.box<Map>(StorageKeys.ingresosBox);

  List<Ingreso> getAll() {
    return _box.values
        .where((e) => (e['_uid'] as String? ?? 'default') == userId)
        .map((e) => Ingreso.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  /// Ingresos del mes, más ingresos fijos recurrentes activos desde antes del mes.
  List<Ingreso> getByMes(DateTime mes) {
    final mesRef = DateTime(mes.year, mes.month);
    return getAll().where((i) {
      if (i.tipo == TipoIngreso.fijo) {
        final inicio = DateTime(i.fecha.year, i.fecha.month);
        if (inicio.isAfter(mesRef)) return false;
        if (i.duracionMeses != null) {
          final vencimiento = DateTime(i.fecha.year, i.fecha.month + i.duracionMeses!);
          if (!mesRef.isBefore(vencimiento)) return false;
        }
        return true;
      }
      return i.fecha.year == mes.year && i.fecha.month == mes.month;
    }).toList();
  }

  Future<void> save(Ingreso ingreso) async {
    final json = ingreso.toJson();
    json['_uid'] = userId;
    await _box.put(ingreso.id, json);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> update(Ingreso ingreso) async {
    final json = ingreso.toJson();
    json['_uid'] = userId;
    await _box.put(ingreso.id, json);
  }

  double totalMes(DateTime mes) {
    return getByMes(mes).fold(0.0, (sum, i) => sum + i.monto);
  }

  Map<CategoriaIngreso, double> totalPorCategoria(DateTime mes) {
    final ingresos = getByMes(mes);
    final Map<CategoriaIngreso, double> result = {};
    for (final i in ingresos) {
      result[i.categoria] = (result[i.categoria] ?? 0) + i.monto;
    }
    return result;
  }

  List<({DateTime mes, double total})> historialMensual({int meses = 12}) {
    final result = <({DateTime mes, double total})>[];
    final now = DateTime.now();
    for (int i = meses - 1; i >= 0; i--) {
      final mes = DateTime(now.year, now.month - i, 1);
      result.add((mes: mes, total: totalMes(mes)));
    }
    return result;
  }

  List<({int anio, double total})> historialAnual({int anios = 5}) {
    final result = <({int anio, double total})>[];
    final now = DateTime.now();
    for (int i = anios - 1; i >= 0; i--) {
      final anio = now.year - i;
      double total = 0;
      for (int mes = 1; mes <= 12; mes++) {
        total += totalMes(DateTime(anio, mes, 1));
      }
      result.add((anio: anio, total: total));
    }
    return result;
  }
}
