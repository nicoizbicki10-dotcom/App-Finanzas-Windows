import 'package:hive/hive.dart';

import '../../../core/storage/storage_keys.dart';
import '../domain/gasto.dart';

class GastosRepository {
  final String userId;
  GastosRepository({required this.userId});

  Box<Map> get _box => Hive.box<Map>(StorageKeys.gastosBox);

  List<Gasto> getAll() {
    return _box.values
        .where((e) => (e['_uid'] as String? ?? 'default') == userId)
        .map((e) => Gasto.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  List<Gasto> getByTipo(TipoGasto tipo) {
    return getAll().where((g) => g.tipo == tipo).toList();
  }

  List<Gasto> getByMes(DateTime mes) {
    final mesRef = DateTime(mes.year, mes.month);
    return getAll().where((g) {
      if (g.tipo == TipoGasto.fijo) {
        final inicio = DateTime(g.fecha.year, g.fecha.month);
        if (inicio.isAfter(mesRef)) return false;
        if (g.duracionMeses != null) {
          final vencimiento = DateTime(g.fecha.year, g.fecha.month + g.duracionMeses!);
          if (!mesRef.isBefore(vencimiento)) return false;
        }
        return true;
      }
      return g.fecha.year == mes.year && g.fecha.month == mes.month;
    }).toList();
  }

  Future<void> save(Gasto gasto) async {
    final json = gasto.toJson();
    json['_uid'] = userId;
    await _box.put(gasto.id, json);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  /// Elimina todos los gastos cuyo ID empieza con [prefix] (ej: 'debt_pasivoId_').
  Future<void> deleteByPrefix(String prefix) async {
    final keys = _box.keys
        .where((k) => k.toString().startsWith(prefix))
        .toList();
    for (final k in keys) {
      await _box.delete(k);
    }
  }

  bool existeConId(String id) => _box.containsKey(id);

  Future<void> update(Gasto gasto) async {
    final json = gasto.toJson();
    json['_uid'] = userId;
    await _box.put(gasto.id, json);
  }

  double totalMes(DateTime mes) {
    return getByMes(mes).fold(0.0, (sum, g) => sum + g.monto);
  }

  Map<CategoriaGasto, double> totalPorCategoria(DateTime mes) {
    final gastos = getByMes(mes);
    final Map<CategoriaGasto, double> result = {};
    for (final g in gastos) {
      result[g.categoria] = (result[g.categoria] ?? 0) + g.monto;
    }
    return result;
  }

  List<({DateTime mes, double total})> historialMensual({int meses = 6}) {
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
