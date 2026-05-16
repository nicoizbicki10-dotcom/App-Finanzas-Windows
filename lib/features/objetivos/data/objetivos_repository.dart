import 'package:hive/hive.dart';

import '../../../core/storage/storage_keys.dart';
import '../domain/objetivo.dart';

class ObjetivosRepository {
  final String userId;
  ObjetivosRepository({required this.userId});

  Box<Map> get _box => Hive.box<Map>(StorageKeys.objetivosBox);

  List<Objetivo> getAll() {
    return _box.values
        .where((e) => (e['_uid'] as String? ?? 'default') == userId)
        .map((e) => Objetivo.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.fechaMeta.compareTo(b.fechaMeta));
  }

  Future<void> save(Objetivo objetivo) async {
    final json = objetivo.toJson();
    json['_uid'] = userId;
    await _box.put(objetivo.id, json);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> actualizarMonto(String id, double nuevoMonto) async {
    final all = getAll();
    final objetivo = all.firstWhere((o) => o.id == id);
    final updated = objetivo.copyWith(
      montoActual: nuevoMonto,
      historialMensual: [...objetivo.historialMensual, nuevoMonto],
    );
    await save(updated);
  }
}
