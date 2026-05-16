import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/usuarios_repository.dart';
import '../../domain/usuario.dart';

final usuariosRepositoryProvider = Provider<UsuariosRepository>((ref) {
  return UsuariosRepository();
});

/// true = app bloqueada, mostrar pantalla de PIN
final isLockedProvider = StateProvider<bool>((ref) {
  final userId = ref.read(usuariosRepositoryProvider).getCurrentId();
  final user = ref.read(usuariosRepositoryProvider).getAll()
      .where((u) => u.id == userId).firstOrNull;
  return user?.pin != null; // bloqueada al inicio si tiene PIN
});

/// ID del usuario actualmente activo.
/// Inicializado desde Hive (backward compat: 'default' si nunca se configuró).
final currentUserIdProvider = StateProvider<String>((ref) {
  return ref.read(usuariosRepositoryProvider).getCurrentId();
});

final usuariosListProvider = Provider<List<UsuarioPerfil>>((ref) {
  return ref.watch(usuariosRepositoryProvider).getAll();
});

class UsuariosNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<UsuarioPerfil> crearUsuario(String nombre, int colorValue) async {
    final repo = ref.read(usuariosRepositoryProvider);
    final usuario = UsuarioPerfil(nombre: nombre, colorValue: colorValue);
    await repo.save(usuario);
    ref.invalidate(usuariosListProvider);
    return usuario;
  }

  Future<void> actualizarNombre(String id, String nuevoNombre) async {
    final repo = ref.read(usuariosRepositoryProvider);
    final usuario = repo.getAll().firstWhere((u) => u.id == id);
    await repo.save(usuario.copyWith(nombre: nuevoNombre));
    ref.invalidate(usuariosListProvider);
  }

  Future<void> actualizarPerfil(
      String id, String nombre, int colorValue, String? fotoUrl) async {
    final repo = ref.read(usuariosRepositoryProvider);
    final usuario = repo.getAll().firstWhere((u) => u.id == id);
    await repo.save(usuario.copyWith(
      nombre: nombre,
      colorValue: colorValue,
      fotoUrl: fotoUrl,
      clearFoto: fotoUrl == null,
    ));
    ref.invalidate(usuariosListProvider);
  }

  Future<void> eliminarUsuario(String id) async {
    final repo = ref.read(usuariosRepositoryProvider);
    await repo.delete(id);
    ref.invalidate(usuariosListProvider);
  }

  Future<void> seleccionar(String id) async {
    await ref.read(usuariosRepositoryProvider).setCurrentId(id);
    ref.read(currentUserIdProvider.notifier).state = id;
    // Bloquear si la nueva cuenta tiene PIN
    final user = ref.read(usuariosRepositoryProvider).getAll()
        .where((u) => u.id == id).firstOrNull;
    if (user?.pin != null) {
      ref.read(isLockedProvider.notifier).state = true;
    }
  }

  Future<void> setPin(String id, String? pin) async {
    final repo = ref.read(usuariosRepositoryProvider);
    final user = repo.getAll().firstWhere((u) => u.id == id);
    await repo.save(user.copyWith(pin: pin, clearPin: pin == null));
    ref.invalidate(usuariosListProvider);
  }

  UsuarioPerfil? getUsuario(String id) {
    return ref.read(usuariosRepositoryProvider).getAll()
        .where((u) => u.id == id).firstOrNull;
  }
}

final usuariosNotifierProvider = NotifierProvider<UsuariosNotifier, void>(
  UsuariosNotifier.new,
);
