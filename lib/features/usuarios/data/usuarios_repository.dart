import 'package:hive/hive.dart';

import '../../../core/storage/storage_keys.dart';
import '../domain/usuario.dart';

class UsuariosRepository {
  Box<Map> get _box => Hive.box<Map>(StorageKeys.cacheBox);

  static const _usuariosKey = '_usuarios';
  static const _currentUidKey = '_current_uid';

  List<UsuarioPerfil> getAll() {
    final raw = _box.get(_usuariosKey);
    if (raw == null) return [];
    final list = (raw['list'] as List?) ?? [];
    return list
        .map((e) => UsuarioPerfil.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> save(UsuarioPerfil usuario) async {
    final all = getAll();
    final idx = all.indexWhere((u) => u.id == usuario.id);
    if (idx >= 0) {
      all[idx] = usuario;
    } else {
      all.add(usuario);
    }
    await _box.put(_usuariosKey, {
      'list': all.map((u) => u.toJson()).toList(),
    });
  }

  Future<void> delete(String id) async {
    final all = getAll()..removeWhere((u) => u.id == id);
    await _box.put(_usuariosKey, {
      'list': all.map((u) => u.toJson()).toList(),
    });
  }

  String getCurrentId() {
    final raw = _box.get(_currentUidKey);
    return (raw is Map ? raw['id'] : null) as String? ?? 'default';
  }

  Future<void> setCurrentId(String id) async {
    await _box.put(_currentUidKey, {'id': id});
  }

  bool get hasUsers => getAll().isNotEmpty;
}
