import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/market_data/providers/market_data_providers.dart';
import '../../../../features/usuarios/presentation/providers/usuarios_provider.dart';
import '../../data/ingresos_repository.dart';
import '../../domain/ingreso.dart';

final ingresosRepositoryProvider = Provider<IngresosRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return IngresosRepository(userId: userId);
});

final mesSeleccionadoIngresosProvider = StateProvider<DateTime>((ref) {
  return DateTime(DateTime.now().year, DateTime.now().month, 1);
});

final ingresosProvider = Provider<List<Ingreso>>((ref) {
  final repo = ref.watch(ingresosRepositoryProvider);
  final mes = ref.watch(mesSeleccionadoIngresosProvider);
  return repo.getByMes(mes);
});

final ingresosFijosProvider = Provider<List<Ingreso>>((ref) {
  return ref.watch(ingresosProvider).where((i) => i.tipo == TipoIngreso.fijo).toList();
});

final ingresosVariablesProvider = Provider<List<Ingreso>>((ref) {
  return ref.watch(ingresosProvider).where((i) => i.tipo == TipoIngreso.variable).toList();
});

double _montoIngARS(Ingreso i, double dolarBlue) =>
    i.esUSD ? i.monto * dolarBlue : i.monto;

double _montoIngUSD(Ingreso i, double dolarBlue) =>
    i.esUSD ? i.monto : (dolarBlue > 0 ? i.monto / dolarBlue : 0);

final totalIngresosMesProvider = Provider<double>((ref) {
  final dolar = ref.watch(dolarBlueVentaProvider);
  return ref.watch(ingresosProvider).fold(0.0, (sum, i) => sum + _montoIngARS(i, dolar));
});

final totalIngresosFijosArsProvider = Provider<double>((ref) {
  final dolar = ref.watch(dolarBlueVentaProvider);
  return ref.watch(ingresosFijosProvider).fold(0.0, (s, i) => s + _montoIngARS(i, dolar));
});

final totalIngresosVariablesArsProvider = Provider<double>((ref) {
  final dolar = ref.watch(dolarBlueVentaProvider);
  return ref.watch(ingresosVariablesProvider).fold(0.0, (s, i) => s + _montoIngARS(i, dolar));
});

final totalIngresosFijosUsdProvider = Provider<double>((ref) {
  final dolar = ref.watch(dolarBlueVentaProvider);
  return ref.watch(ingresosFijosProvider).fold(0.0, (s, i) => s + _montoIngUSD(i, dolar));
});

final totalIngresosVariablesUsdProvider = Provider<double>((ref) {
  final dolar = ref.watch(dolarBlueVentaProvider);
  return ref.watch(ingresosVariablesProvider).fold(0.0, (s, i) => s + _montoIngUSD(i, dolar));
});

final ingresosPorCategoriaProvider = Provider<Map<CategoriaIngreso, double>>((ref) {
  final ingresos = ref.watch(ingresosProvider);
  final dolar = ref.watch(dolarBlueVentaProvider);
  final Map<CategoriaIngreso, double> result = {};
  for (final i in ingresos) {
    result[i.categoria] = (result[i.categoria] ?? 0) + _montoIngARS(i, dolar);
  }
  return result;
});

List<({DateTime mes, double total})> _historialMensualIngresos(
    IngresosRepository repo, double dolar, int meses) {
  final now = DateTime.now();
  return List.generate(meses, (i) {
    final mes = DateTime(now.year, now.month - (meses - 1 - i));
    final total = repo
        .getByMes(mes)
        .fold(0.0, (sum, ing) => sum + _montoIngARS(ing, dolar));
    return (mes: mes, total: total);
  });
}

List<({int anio, double total})> _historialAnualIngresos(
    IngresosRepository repo, double dolar, int anios) {
  final now = DateTime.now();
  return List.generate(anios, (i) {
    final anio = now.year - (anios - 1 - i);
    double total = 0;
    for (int mes = 1; mes <= 12; mes++) {
      total += repo
          .getByMes(DateTime(anio, mes))
          .fold(0.0, (sum, ing) => sum + _montoIngARS(ing, dolar));
    }
    return (anio: anio, total: total);
  });
}

final historialIngresosProvider =
    Provider<List<({DateTime mes, double total})>>((ref) {
  ref.watch(ingresosProvider); // reactivo a cambios
  final repo = ref.read(ingresosRepositoryProvider);
  final dolar = ref.watch(dolarBlueVentaProvider);
  return _historialMensualIngresos(repo, dolar, 12);
});

final historial5AnosIngresosProvider =
    Provider<List<({int anio, double total})>>((ref) {
  ref.watch(ingresosProvider);
  final repo = ref.read(ingresosRepositoryProvider);
  final dolar = ref.watch(dolarBlueVentaProvider);
  return _historialAnualIngresos(repo, dolar, 5);
});

final historial10AnosIngresosProvider =
    Provider<List<({int anio, double total})>>((ref) {
  ref.watch(ingresosProvider);
  final repo = ref.read(ingresosRepositoryProvider);
  final dolar = ref.watch(dolarBlueVentaProvider);
  return _historialAnualIngresos(repo, dolar, 10);
});

final ingresosPasivosProvider = Provider<({double mensual, double anual})>((ref) {
  final dolar = ref.watch(dolarBlueVentaProvider);
  final fijos = ref.watch(ingresosFijosProvider);
  final mensual = fijos
      .where((i) => i.categoria == CategoriaIngreso.alquiler ||
          i.categoria == CategoriaIngreso.dividendos)
      .fold(0.0, (s, i) => s + (i.esUSD ? i.monto * dolar : i.monto));
  return (mensual: mensual, anual: mensual * 12);
});

class IngresosNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> agregar(Ingreso ingreso) async {
    await ref.read(ingresosRepositoryProvider).save(ingreso);
    ref.invalidate(ingresosProvider);
  }

  Future<void> eliminar(String id) async {
    await ref.read(ingresosRepositoryProvider).delete(id);
    ref.invalidate(ingresosProvider);
  }

  Future<void> actualizar(Ingreso ingreso) async {
    await ref.read(ingresosRepositoryProvider).update(ingreso);
    ref.invalidate(ingresosProvider);
  }
}

final ingresosNotifierProvider = NotifierProvider<IngresosNotifier, void>(
  IngresosNotifier.new,
);
