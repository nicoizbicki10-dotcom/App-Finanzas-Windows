import 'package:hive/hive.dart';

import '../../../core/storage/storage_keys.dart';
import '../domain/pasivo_models.dart';

class PasivosRepository {
  final String userId;
  PasivosRepository({required this.userId});

  Box<Map> get _box => Hive.box<Map>(StorageKeys.pasivosBox);

  bool _esDelUsuario(Map e) =>
      (e['_uid'] as String? ?? 'default') == userId;

  List<Pasivo> getAll() {
    return _box.values
        .where((e) => e['category'] == 'pasivo' && _esDelUsuario(e))
        .map((e) => Pasivo.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> save(Pasivo pasivo) async {
    final json = pasivo.toJson();
    json['_uid'] = userId;
    await _box.put('pasivo_${pasivo.id}', json);
  }

  Future<void> delete(String id) async {
    await _box.delete('pasivo_$id');
  }
}
