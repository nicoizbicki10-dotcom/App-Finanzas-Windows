import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/market_data/providers/market_data_providers.dart';
import '../../../../features/usuarios/presentation/providers/usuarios_provider.dart';
import '../../data/gastos_repository.dart';
import '../../domain/gasto.dart';

final gastosRepositoryProvider = Provider<GastosRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return GastosRepository(userId: userId);
});

final mesSeleccionadoGastosProvider = StateProvider<DateTime>((ref) {
  return DateTime(DateTime.now().year, DateTime.now().month, 1);
});

final gastosProvider = Provider<List<Gasto>>((ref) {
  final repo = ref.watch(gastosRepositoryProvider);
  final mes = ref.watch(mesSeleccionadoGastosProvider);
  return repo.getByMes(mes);
});

final gastosFijosProvider = Provider<List<Gasto>>((ref) {
  return ref.watch(gastosProvider).where((g) => g.tipo == TipoGasto.fijo).toList();
});

final gastosVariablesProvider = Provider<List<Gasto>>((ref) {
  return ref.watch(gastosProvider).where((g) => g.tipo == TipoGasto.variable).toList();
});

double _montoARS(Gasto g, double dolarBlue) =>
    g.esUSD ? g.monto * dolarBlue : g.monto;

final totalGastosMesProvider = Provider<double>((ref) {
  final dolar = ref.watch(dolarBlueVentaProvider);
  return ref.watch(gastosProvider).fold(0.0, (sum, g) => sum + _montoARS(g, dolar));
});

final totalGastosFijosProvider = Provider<double>((ref) {
  final dolar = ref.watch(dolarBlueVentaProvider);
  return ref.watch(gastosFijosProvider).fold(0.0, (sum, g) => sum + _montoARS(g, dolar));
});

final totalGastosVariablesProvider = Provider<double>((ref) {
  final dolar = ref.watch(dolarBlueVentaProvider);
  return ref.watch(gastosVariablesProvider).fold(0.0, (sum, g) => sum + _montoARS(g, dolar));
});

double _montoUSD(Gasto g, double dolarBlue) =>
    g.esUSD ? g.monto : g.monto / dolarBlue;

final totalGastosMesUsdProvider = Provider<double>((ref) {
  final dolar = ref.watch(dolarBlueVentaProvider);
  return ref.watch(gastosProvider).fold(0.0, (sum, g) => sum + _montoUSD(g, dolar));
});

final totalGastosFijosUsdProvider = Provider<double>((ref) {
  final dolar = ref.watch(dolarBlueVentaProvider);
  return ref.watch(gastosFijosProvider).fold(0.0, (sum, g) => sum + _montoUSD(g, dolar));
});

final totalGastosVariablesUsdProvider = Provider<double>((ref) {
  final dolar = ref.watch(dolarBlueVentaProvider);
  return ref.watch(gastosVariablesProvider).fold(0.0, (sum, g) => sum + _montoUSD(g, dolar));
});

final gastosPorCategoriaProvider = Provider<Map<CategoriaGasto, double>>((ref) {
  final gastos = ref.watch(gastosProvider);
  final dolar = ref.watch(dolarBlueVentaProvider);
  final Map<CategoriaGasto, double> result = {};
  for (final g in gastos) {
    result[g.categoria] = (result[g.categoria] ?? 0) + _montoARS(g, dolar);
  }
  return result;
});

List<({DateTime mes, double total})> _historialMensualGastos(
    GastosRepository repo, double dolar, int meses) {
  final now = DateTime.now();
  return List.generate(meses, (i) {
    final mes = DateTime(now.year, now.month - (meses - 1 - i));
    final total = repo
        .getByMes(mes)
        .fold(0.0, (sum, g) => sum + _montoARS(g, dolar));
    return (mes: mes, total: total);
  });
}

List<({int anio, double total})> _historialAnualGastos(
    GastosRepository repo, double dolar, int anios) {
  final now = DateTime.now();
  return List.generate(anios, (i) {
    final anio = now.year - (anios - 1 - i);
    double total = 0;
    for (int mes = 1; mes <= 12; mes++) {
      total += repo
          .getByMes(DateTime(anio, mes))
          .fold(0.0, (sum, g) => sum + _montoARS(g, dolar));
    }
    return (anio: anio, total: total);
  });
}

final historialGastosProvider =
    Provider<List<({DateTime mes, double total})>>((ref) {
  ref.watch(gastosProvider); // reactivo a cambios
  final repo = ref.read(gastosRepositoryProvider);
  final dolar = ref.watch(dolarBlueVentaProvider);
  return _historialMensualGastos(repo, dolar, 6);
});

final historial12MesesGastosProvider =
    Provider<List<({DateTime mes, double total})>>((ref) {
  ref.watch(gastosProvider);
  final repo = ref.read(gastosRepositoryProvider);
  final dolar = ref.watch(dolarBlueVentaProvider);
  return _historialMensualGastos(repo, dolar, 12);
});

final historial5AnosGastosProvider =
    Provider<List<({int anio, double total})>>((ref) {
  ref.watch(gastosProvider);
  final repo = ref.read(gastosRepositoryProvider);
  final dolar = ref.watch(dolarBlueVentaProvider);
  return _historialAnualGastos(repo, dolar, 5);
});

final historial10AnosGastosProvider =
    Provider<List<({int anio, double total})>>((ref) {
  ref.watch(gastosProvider);
  final repo = ref.read(gastosRepositoryProvider);
  final dolar = ref.watch(dolarBlueVentaProvider);
  return _historialAnualGastos(repo, dolar, 10);
});

class GastosNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> agregar(Gasto gasto) async {
    await ref.read(gastosRepositoryProvider).save(gasto);
    ref.invalidate(gastosProvider);
  }

  Future<void> eliminar(String id) async {
    await ref.read(gastosRepositoryProvider).delete(id);
    ref.invalidate(gastosProvider);
  }

  Future<void> actualizar(Gasto gasto) async {
    await ref.read(gastosRepositoryProvider).update(gasto);
    ref.invalidate(gastosProvider);
  }
}

final gastosNotifierProvider = NotifierProvider<GastosNotifier, void>(
  GastosNotifier.new,
);
