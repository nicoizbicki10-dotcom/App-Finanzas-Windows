import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/gastos/data/gastos_repository.dart';
import '../../../../features/gastos/domain/gasto.dart';
import '../../../../features/gastos/presentation/providers/gastos_provider.dart';
import '../../../../features/inversiones/data/currency_data.dart';
import '../../../../features/market_data/providers/market_data_providers.dart';
import '../../../../features/usuarios/presentation/providers/usuarios_provider.dart';
import '../../data/pasivos_repository.dart';
import '../../domain/pasivo_models.dart';

final pasivosRepositoryProvider = Provider<PasivosRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return PasivosRepository(userId: userId);
});

final pasivosProvider = Provider<List<Pasivo>>((ref) {
  return ref.watch(pasivosRepositoryProvider).getAll();
});

final totalPasivosUSDProvider = Provider<double>((ref) {
  final pasivos = ref.watch(pasivosProvider);
  if (pasivos.isEmpty) return 0.0;

  final dolarAsync = ref.watch(dolarProvider);
  final dolares = dolarAsync.value ?? [];
  final dolarVenta = dolares
          .where((d) => d.casa.toLowerCase() == 'blue')
          .map((d) => d.venta)
          .firstOrNull ??
      1050.0;

  return pasivos.fold(
    0.0,
    (sum, p) => sum + monedaToUSD(p.montoTotal, p.moneda, dolarVenta),
  );
});

final _gastosRepoForPasivosProvider = Provider<GastosRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return GastosRepository(userId: userId);
});

class PasivosNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> agregar(Pasivo pasivo) async {
    final gastosRepo = ref.read(_gastosRepoForPasivosProvider);
    await gastosRepo.deleteByPrefix('debt_${pasivo.id}_');
    await ref.read(pasivosRepositoryProvider).save(pasivo);
    await _sincronizarCuotas(pasivo, gastosRepo);
    ref.invalidate(pasivosProvider);
    ref.invalidate(gastosProvider);
  }

  Future<void> eliminar(String id) async {
    final gastosRepo = ref.read(_gastosRepoForPasivosProvider);
    await ref.read(pasivosRepositoryProvider).delete(id);
    await gastosRepo.deleteByPrefix('debt_${id}_');
    ref.invalidate(pasivosProvider);
    ref.invalidate(gastosProvider);
  }

  /// Migración: crea gastos para todos los pasivos que aún no los tienen.
  Future<void> migrarCuotasExistentes() async {
    final gastosRepo = ref.read(_gastosRepoForPasivosProvider);
    final pasivos = ref.read(pasivosRepositoryProvider).getAll();
    bool algoCambio = false;

    for (final p in pasivos) {
      final yaExiste = gastosRepo.existeConId('debt_${p.id}_0');
      if (!yaExiste) {
        await _sincronizarCuotas(p, gastosRepo);
        algoCambio = true;
      }
    }

    if (algoCambio) ref.invalidate(gastosProvider);
  }

  Future<void> _sincronizarCuotas(Pasivo p, GastosRepository gastosRepo) async {
    final esUSD = p.moneda == 'USD';

    // Simple / Compuesto → un único gasto al vencimiento por el total
    if (p.metodo == MetodoPasivo.simple || p.metodo == MetodoPasivo.compuesto) {
      final gasto = Gasto(
        id: 'debt_${p.id}_0',
        descripcion: '💳 ${p.concepto} – vencimiento (${p.metodo.label})',
        monto: p.montoTotal,
        esUSD: esUSD,
        categoria: CategoriaGasto.otros,
        tipo: TipoGasto.fijo,
        fecha: p.fechaVencimiento,
        recurrente: false,
        notas: 'Auto-generado desde Pasivos',
      );
      await gastosRepo.save(gasto);
      return;
    }

    // Amortización (Francés / Alemán / Americano) → cuota mensual por período
    final n = p.periodosMensuales;
    final rM = p.tasaInteresPct / 100.0 / 12;

    for (int k = 0; k < n; k++) {
      final cuota = _cuotaPeriodo(p, k, n, rM);
      final fecha = _sumarMeses(p.fechaEndeudamiento, k + 1);
      final esUltima = k == n - 1;

      String desc;
      switch (p.metodo) {
        case MetodoPasivo.frances:
          desc = '💳 ${p.concepto} – cuota ${k + 1}/$n (Francés)';
        case MetodoPasivo.aleman:
          desc = '💳 ${p.concepto} – cuota ${k + 1}/$n (Alemán)';
        case MetodoPasivo.americano:
          desc = esUltima
              ? '💳 ${p.concepto} – cuota final + capital (Americano)'
              : '💳 ${p.concepto} – interés ${k + 1}/$n (Americano)';
        default:
          desc = '💳 ${p.concepto} – cuota ${k + 1}/$n';
      }

      final gasto = Gasto(
        id: 'debt_${p.id}_$k',
        descripcion: desc,
        monto: cuota,
        esUSD: esUSD,
        categoria: CategoriaGasto.otros,
        tipo: TipoGasto.fijo,
        fecha: fecha,
        recurrente: false,
        notas: 'Auto-generado desde Pasivos',
      );
      await gastosRepo.save(gasto);
    }
  }

  double _cuotaPeriodo(Pasivo p, int k, int n, double rM) {
    switch (p.metodo) {
      case MetodoPasivo.frances:
        // Cuota fija: usa el getter del modelo
        return p.cuotaMensual ?? p.monto / n;

      case MetodoPasivo.aleman:
        // Cuota k (0-indexed): P/n + P*rM*(n-k)/n  (decreciente)
        return p.monto / n + p.monto * rM * (n - k) / n;

      case MetodoPasivo.americano:
        // Interés periódico; última cuota suma el capital
        return k == n - 1
            ? p.monto + p.monto * rM
            : p.monto * rM;

      default:
        return p.monto / n;
    }
  }

  DateTime _sumarMeses(DateTime base, int meses) {
    var year = base.year + (base.month + meses - 1) ~/ 12;
    var month = (base.month + meses - 1) % 12 + 1;
    final day = base.day.clamp(1, _diasEnMes(year, month));
    return DateTime(year, month, day);
  }

  int _diasEnMes(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }
}

final pasivosNotifierProvider = NotifierProvider<PasivosNotifier, void>(
  PasivosNotifier.new,
);
