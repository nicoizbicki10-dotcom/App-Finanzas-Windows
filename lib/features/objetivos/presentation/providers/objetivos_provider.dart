import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/usuarios/presentation/providers/usuarios_provider.dart';
import '../../data/objetivos_repository.dart';
import '../../domain/objetivo.dart';

final objetivosRepositoryProvider = Provider<ObjetivosRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return ObjetivosRepository(userId: userId);
});

final objetivosProvider = Provider<List<Objetivo>>((ref) {
  return ref.watch(objetivosRepositoryProvider).getAll();
});

final objetivosActivosProvider = Provider<List<Objetivo>>((ref) {
  return ref.watch(objetivosProvider).where((o) => !o.completado).toList();
});

final objetivosCompletadosProvider = Provider<List<Objetivo>>((ref) {
  return ref.watch(objetivosProvider).where((o) => o.completado).toList();
});

class ObjetivosNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> agregar(Objetivo objetivo) async {
    await ref.read(objetivosRepositoryProvider).save(objetivo);
    ref.invalidate(objetivosProvider);
  }

  Future<void> eliminar(String id) async {
    await ref.read(objetivosRepositoryProvider).delete(id);
    ref.invalidate(objetivosProvider);
  }

  Future<void> actualizarMonto(String id, double monto) async {
    await ref.read(objetivosRepositoryProvider).actualizarMonto(id, monto);
    ref.invalidate(objetivosProvider);
  }

  Future<void> actualizar(Objetivo objetivo) async {
    await ref.read(objetivosRepositoryProvider).save(objetivo);
    ref.invalidate(objetivosProvider);
  }
}

final objetivosNotifierProvider = NotifierProvider<ObjetivosNotifier, void>(
  ObjetivosNotifier.new,
);
