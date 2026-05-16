import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/dashboard/data/patrimonio_history_repository.dart';
import '../../../../features/ingresos/domain/ingreso.dart';
import '../../../../features/ingresos/presentation/providers/ingresos_provider.dart';
import '../../../../features/market_data/data/precios_barrios.dart';
import '../../../../features/market_data/providers/market_data_providers.dart';
import '../../../../features/usuarios/presentation/providers/usuarios_provider.dart';
import '../../data/currency_data.dart';
import '../../data/inversiones_repository.dart';
import '../../domain/inversion_models.dart';

final inversionesRepositoryProvider = Provider<InversionesRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return InversionesRepository(userId: userId);
});

// ─── Refresh counter (fuerza recompilación tras mutaciones de Hive) ─────────

final _accionesVersionProvider = StateProvider<int>((ref) => 0);
final _cryptoVersionProvider = StateProvider<int>((ref) => 0);

// ─── Listas base ────────────────────────────────────────────────────────────

final inmueblesProvider = Provider<List<Inmueble>>((ref) {
  return ref.watch(inversionesRepositoryProvider).getInmuebles();
});

final accionesProvider = Provider<List<Accion>>((ref) {
  ref.watch(_accionesVersionProvider);
  return ref.watch(inversionesRepositoryProvider).getAcciones();
});

final cryptoHoldingsProvider = Provider<List<CryptoHolding>>((ref) {
  ref.watch(_cryptoVersionProvider);
  return ref.watch(inversionesRepositoryProvider).getCryptos();
});

final liquidezProvider = Provider<List<Liquidez>>((ref) {
  return ref.watch(inversionesRepositoryProvider).getLiquidez();
});

final otrasInversionesProvider = Provider<List<OtraInversion>>((ref) {
  return ref.watch(inversionesRepositoryProvider).getOtras();
});

final negociosPersonalesProvider = Provider<List<NegocioPersonal>>((ref) {
  return ref.watch(inversionesRepositoryProvider).getNegociosPersonales();
});

final instrumentosProvider = Provider<List<InstrumentoFinanciero>>((ref) {
  return ref.watch(inversionesRepositoryProvider).getInstrumentos();
});

final bienesProvider = Provider<List<BienDeUso>>((ref) {
  return ref.watch(inversionesRepositoryProvider).getBienes();
});

final alternativasProvider = Provider<List<InversionAlternativa>>((ref) {
  return ref.watch(inversionesRepositoryProvider).getAlternativas();
});

final operacionesAccionProvider =
    Provider.family<List<OperacionLog>, String>((ref, ticker) {
  return ref.watch(inversionesRepositoryProvider).getOperaciones(
        ticker: ticker,
        tipoActivo: TipoActivoOp.accion,
      );
});

final operacionesCryptoProvider =
    Provider.family<List<OperacionLog>, String>((ref, symbol) {
  return ref.watch(inversionesRepositoryProvider).getOperaciones(
        ticker: symbol,
        tipoActivo: TipoActivoOp.crypto,
      );
});

// ─── Valuación del portfolio ─────────────────────────────────────────────────

final valorAccionesUSDProvider = FutureProvider<double>((ref) async {
  final acciones = ref.watch(accionesProvider);
  if (acciones.isEmpty) return 0.0;

  double total = 0.0;
  for (final accion in acciones) {
    final quoteAsync = ref.watch(stockQuoteProvider(accion.ticker));
    final quote = quoteAsync.value;
    if (quote != null) {
      total += accion.cantidad * quote.currentPrice;
    } else {
      total += accion.costoTotalUSD();
    }
  }
  return total;
});

final valorCryptoUSDProvider = FutureProvider<double>((ref) async {
  final holdings = ref.watch(cryptoHoldingsProvider);
  if (holdings.isEmpty) return 0.0;

  final coinIds = holdings.map((h) => h.coingeckoId).toSet().join(',');
  final pricesAsync = ref.watch(cryptoPricesProvider(coinIds));

  return pricesAsync.when(
    data: (prices) {
      final priceMap = {for (final p in prices) p.id: p.currentPrice};
      return holdings.fold<double>(0.0, (sum, h) {
        final price = priceMap[h.coingeckoId] ?? h.precioCompraUSD;
        return sum + h.cantidad * price;
      });
    },
    loading: () => holdings.fold<double>(0.0, (sum, h) => sum + h.costoTotalUSD()),
    error: (_, __) => holdings.fold<double>(0.0, (sum, h) => sum + h.costoTotalUSD()),
  );
});

final valorBienesUSDProvider = FutureProvider<double>((ref) async {
  final bienes = ref.watch(bienesProvider);
  if (bienes.isEmpty) return 0.0;

  final dolarAsync = ref.watch(dolarProvider);
  final dolares = dolarAsync.value ?? [];
  final dolarVenta = dolares
          .where((d) => d.casa.toLowerCase() == 'blue')
          .map((d) => d.venta)
          .firstOrNull ??
      1050.0;

  double total = 0.0;
  for (final b in bienes) {
    final valor = b.valorEstimadoActual ?? b.precioCompra;
    if (b.moneda == 'USD') {
      total += valor;
    } else if (b.moneda == 'ARS') {
      total += valor / dolarVenta;
    } else {
      total += valor;
    }
  }
  return total;
});

final valorAlternativasUSDProvider = FutureProvider<double>((ref) async {
  final alternativas = ref.watch(alternativasProvider);
  if (alternativas.isEmpty) return 0.0;

  final dolarAsync = ref.watch(dolarProvider);
  final dolares = dolarAsync.value ?? [];
  final dolarVenta = dolares
          .where((d) => d.casa.toLowerCase() == 'blue')
          .map((d) => d.venta)
          .firstOrNull ??
      1050.0;

  final spotPrices = await ref.watch(metalSpotPricesProvider.future);
  final goldPerOz = spotPrices['gold'] ?? 0.0;
  final silverPerOz = spotPrices['silver'] ?? 0.0;

  return alternativas.fold<double>(0.0, (sum, alt) {
    if (alt.valorEstimadoManual != null) {
      return sum + monedaToUSD(alt.valorEstimadoManual!, alt.moneda, dolarVenta);
    }
    final spotUSD = alt.valorSpotUSD(goldPerOz: goldPerOz, silverPerOz: silverPerOz);
    if (spotUSD != null) return sum + spotUSD;
    return sum + monedaToUSD(alt.precioCompra, alt.moneda, dolarVenta);
  });
});

final valorInmueblesUSDProvider = FutureProvider<double>((ref) async {
  final inmuebles = ref.watch(inmueblesProvider);
  if (inmuebles.isEmpty) return 0.0;

  double total = 0.0;
  for (final i in inmuebles) {
    double valorBruto = 0.0;
    if (i.valorEstimadoUSD > 0) {
      valorBruto = i.valorEstimadoUSD;
    } else if (i.barrio != null && i.barrio!.isNotEmpty) {
      final precioM2 = PreciosBarrios.getPrecioM2(i.barrio!);
      if (precioM2 != null) {
        valorBruto = i.superficieM2 * precioM2;
      }
    }
    total += valorBruto * i.factorParteIndivisa;
  }
  return total;
});

final valorInstrumentosUSDProvider = FutureProvider<double>((ref) async {
  final instrumentos = ref.watch(instrumentosProvider);
  if (instrumentos.isEmpty) return 0.0;

  final dolarAsync = ref.watch(dolarProvider);
  final dolares = dolarAsync.value ?? [];
  final dolarVenta = dolares
          .where((d) => d.casa.toLowerCase() == 'blue')
          .map((d) => d.venta)
          .firstOrNull ??
      1050.0;

  return instrumentos.fold<double>(
    0.0,
    (sum, inst) => sum + monedaToUSD(inst.montoTotal, inst.moneda, dolarVenta),
  );
});

final distribucionPortfolioProvider =
    FutureProvider<Map<String, double>>((ref) async {
  final dolarAsync = ref.watch(dolarProvider);
  final dolares = dolarAsync.value ?? [];
  final dolarVenta = dolares
          .where((d) => d.casa.toLowerCase() == 'blue')
          .map((d) => d.venta)
          .firstOrNull ??
      1050.0;

  final accionesUSD = await ref.watch(valorAccionesUSDProvider.future);
  final cryptoUSD = await ref.watch(valorCryptoUSDProvider.future);
  final inmueblesUSD = await ref.watch(valorInmueblesUSDProvider.future);
  final instrumentosUSD = await ref.watch(valorInstrumentosUSDProvider.future);
  final bienesUSD = await ref.watch(valorBienesUSDProvider.future);
  final alternativasUSD = await ref.watch(valorAlternativasUSDProvider.future);

  final liquidez = ref.watch(liquidezProvider);
  final otras = ref.watch(otrasInversionesProvider);
  final negocios = ref.watch(negociosPersonalesProvider);

  final liquidezUSD = liquidez.fold(
    0.0,
    (sum, l) => sum + monedaToUSD(l.monto, l.moneda, dolarVenta),
  );
  final otrasUSD = otras.fold(
    0.0,
    (sum, o) => sum + monedaToUSD(o.monto, o.moneda, dolarVenta),
  );
  final negociosUSD = negocios.fold(
    0.0,
    (sum, n) => sum + monedaToUSD(n.monto, n.moneda, dolarVenta),
  );

  final total = inmueblesUSD + accionesUSD + cryptoUSD + liquidezUSD + otrasUSD + instrumentosUSD + bienesUSD + negociosUSD + alternativasUSD;
  if (total == 0) return {};

  return {
    'Inmuebles': inmueblesUSD / total * 100,
    'Acciones': accionesUSD / total * 100,
    'Cripto': cryptoUSD / total * 100,
    'Liquidez': liquidezUSD / total * 100,
    'Otras': otrasUSD / total * 100,
    'Instrumentos': instrumentosUSD / total * 100,
    'Bienes': bienesUSD / total * 100,
    'Negocios': negociosUSD / total * 100,
    'Alternativas': alternativasUSD / total * 100,
  };
});

final totalPatrimonioUSDProvider = FutureProvider<double>((ref) async {
  final dolarAsync = ref.watch(dolarProvider);
  final dolares = dolarAsync.value ?? [];
  final dolarVenta = dolares
          .where((d) => d.casa.toLowerCase() == 'blue')
          .map((d) => d.venta)
          .firstOrNull ??
      1050.0;

  final accionesUSD = await ref.watch(valorAccionesUSDProvider.future);
  final cryptoUSD = await ref.watch(valorCryptoUSDProvider.future);
  final inmueblesUSD = await ref.watch(valorInmueblesUSDProvider.future);
  final instrumentosUSD = await ref.watch(valorInstrumentosUSDProvider.future);
  final bienesUSD = await ref.watch(valorBienesUSDProvider.future);
  final alternativasUSD = await ref.watch(valorAlternativasUSDProvider.future);

  final liquidez = ref.watch(liquidezProvider);
  final otras = ref.watch(otrasInversionesProvider);
  final negocios = ref.watch(negociosPersonalesProvider);

  final liquidezUSD = liquidez.fold(
    0.0,
    (sum, l) => sum + monedaToUSD(l.monto, l.moneda, dolarVenta),
  );
  final otrasUSD = otras.fold(
    0.0,
    (sum, o) => sum + monedaToUSD(o.monto, o.moneda, dolarVenta),
  );
  final negociosUSD = negocios.fold(
    0.0,
    (sum, n) => sum + monedaToUSD(n.monto, n.moneda, dolarVenta),
  );

  return inmueblesUSD + accionesUSD + cryptoUSD + liquidezUSD + otrasUSD + instrumentosUSD + bienesUSD + negociosUSD + alternativasUSD;
});

// ─── Valores absolutos por sección (para guardar historial y calcular variación) ─

final seccionValoresUSDProvider = FutureProvider<Map<String, double>>((ref) async {
  final dolarAsync = ref.watch(dolarProvider);
  final dolares = dolarAsync.value ?? [];
  final dolarVenta = dolares
          .where((d) => d.casa.toLowerCase() == 'blue')
          .map((d) => d.venta)
          .firstOrNull ??
      1050.0;

  final inmueblesUSD = await ref.watch(valorInmueblesUSDProvider.future);
  final accionesUSD = await ref.watch(valorAccionesUSDProvider.future);
  final cryptoUSD = await ref.watch(valorCryptoUSDProvider.future);
  final instrumentosUSD = await ref.watch(valorInstrumentosUSDProvider.future);
  final bienesUSD = await ref.watch(valorBienesUSDProvider.future);
  final alternativasUSD = await ref.watch(valorAlternativasUSDProvider.future);

  final liquidez = ref.watch(liquidezProvider);
  final otras = ref.watch(otrasInversionesProvider);
  final negocios = ref.watch(negociosPersonalesProvider);

  return {
    'inmuebles': inmueblesUSD,
    'acciones': accionesUSD,
    'cripto': cryptoUSD,
    'liquidez': liquidez.fold(0.0, (s, l) => s + monedaToUSD(l.monto, l.moneda, dolarVenta)),
    'instrumentos': instrumentosUSD,
    'bienes': bienesUSD,
    'otras': otras.fold(0.0, (s, o) => s + monedaToUSD(o.monto, o.moneda, dolarVenta)),
    'negocios': negocios.fold(0.0, (s, n) => s + monedaToUSD(n.monto, n.moneda, dolarVenta)),
    'alternativas': alternativasUSD,
  };
});

/// Variación % anual de una sección vs el snapshot guardado hace 12 meses.
/// Retorna null si no hay datos históricos.
final variacionAnualSeccionProvider =
    FutureProvider.family<double?, String>((ref, seccion) async {
  final valores = await ref.watch(seccionValoresUSDProvider.future);
  final currentUSD = valores[seccion] ?? 0;
  if (currentUSD == 0) return null;

  final repo = ref.watch(patrimonioHistoryRepositoryProvider);
  final historicalUSD = repo.getSeccionHace12Meses(seccion);
  if (historicalUSD == null || historicalUSD == 0) return null;

  return (currentUSD - historicalUSD) / historicalUSD * 100;
});

// ─── Historial de patrimonio ─────────────────────────────────────────────────

final patrimonioHistoryRepositoryProvider =
    Provider<PatrimonioHistoryRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return PatrimonioHistoryRepository(userId: userId);
});

final patrimonioUltimos12MesesProvider =
    Provider<List<({DateTime mes, double valorUSD})>>((ref) {
  return ref.watch(patrimonioHistoryRepositoryProvider).getUltimosMeses(12);
});

final patrimonioUltimos10AnosProvider =
    Provider<List<({int anio, double valorUSD})>>((ref) {
  return ref.watch(patrimonioHistoryRepositoryProvider).getUltimosAnios(10);
});

// ─── CRUD Notifiers ─────────────────────────────────────────────────────────

class InversionesNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> agregarAccion(Accion accion) async {
    final repo = ref.read(inversionesRepositoryProvider);
    // Solo crear el registro Accion si no existe uno para ese ticker
    final existe = repo.getAcciones().any((a) => a.ticker == accion.ticker);
    if (!existe) {
      await repo.saveAccion(accion);
      ref.read(_accionesVersionProvider.notifier).update((n) => n + 1);
    }
    await repo.saveOperacion(OperacionLog(
      tipoActivo: TipoActivoOp.accion,
      ticker: accion.ticker,
      tipoOp: TipoOperacion.compra,
      cantidad: accion.cantidad,
      precioUSD: accion.precioCompraUSD,
      fecha: accion.fechaAdquisicion,
      exchange: accion.exchange,
    ));
    ref.invalidate(operacionesAccionProvider(accion.ticker));
  }

  Future<void> actualizarAccion(Accion accion) async {
    final repo = ref.read(inversionesRepositoryProvider);
    // Actualizar la operación de compra original para que la cantidad mostrada coincida.
    final ops = repo.getOperaciones(ticker: accion.ticker, tipoActivo: TipoActivoOp.accion);
    final oldestBuy = ops.where((op) => op.tipoOp == TipoOperacion.compra).lastOrNull;
    if (oldestBuy != null) {
      await repo.saveOperacion(OperacionLog(
        id: oldestBuy.id,
        tipoActivo: TipoActivoOp.accion,
        ticker: accion.ticker,
        tipoOp: TipoOperacion.compra,
        cantidad: accion.cantidad,
        precioUSD: accion.precioCompraUSD,
        fecha: oldestBuy.fecha,
        exchange: oldestBuy.exchange,
      ));
    }
    await repo.saveAccion(accion);
    ref.read(_accionesVersionProvider.notifier).update((n) => n + 1);
    ref.invalidate(operacionesAccionProvider(accion.ticker));
  }

  Future<void> eliminarAccion(String id) async {
    await ref.read(inversionesRepositoryProvider).deleteAccion(id);
    ref.read(_accionesVersionProvider.notifier).update((n) => n + 1);
  }

  /// Elimina todos los registros Accion con ese ticker del portfolio,
  /// incluyendo todas las operaciones asociadas para evitar acumulación al re-agregar.
  Future<void> eliminarAccionesPorTicker(String ticker) async {
    final repo = ref.read(inversionesRepositoryProvider);
    for (final a in repo.getAcciones().where((a) => a.ticker == ticker).toList()) {
      await repo.deleteAccion(a.id);
    }
    for (final op in repo.getOperaciones(ticker: ticker, tipoActivo: TipoActivoOp.accion).toList()) {
      await repo.deleteOperacion(op.id);
    }
    ref.read(_accionesVersionProvider.notifier).update((n) => n + 1);
    ref.invalidate(operacionesAccionProvider(ticker));
  }

  Future<void> registrarVentaAccion({
    required String ticker,
    required double cantidad,
    required double precioVentaUSD,
    required String exchange,
  }) async {
    final repo = ref.read(inversionesRepositoryProvider);

    // Crear operación con ID conocido para vincular con la liquidez
    final op = OperacionLog(
      tipoActivo: TipoActivoOp.accion,
      ticker: ticker,
      tipoOp: TipoOperacion.venta,
      cantidad: cantidad,
      precioUSD: precioVentaUSD,
      fecha: DateTime.now(),
      exchange: exchange,
    );
    await repo.saveOperacion(op);

    // Si la cantidad neta llega a 0, eliminar el registro del Accion
    final todasOps = repo.getOperaciones(ticker: ticker, tipoActivo: TipoActivoOp.accion);
    final cantidadNeta = todasOps.fold(0.0, (sum, o) =>
        o.tipoOp == TipoOperacion.compra ? sum + o.cantidad : sum - o.cantidad);
    if (cantidadNeta <= 0) {
      final accion = repo.getAcciones().where((a) => a.ticker == ticker).firstOrNull;
      if (accion != null) await repo.deleteAccion(accion.id);
    }

    // Liquidez con ID vinculado a la operación para poder borrarla al deshacer
    await repo.saveLiquidez(Liquidez(
      id: 'venta_liq_${op.id}',
      nombre: 'Venta de acciones: $ticker',
      monto: cantidad * precioVentaUSD,
      moneda: 'USD',
      institucion: exchange,
      tipo: TipoLiquidez.plataforma,
    ));
    ref.read(_accionesVersionProvider.notifier).update((n) => n + 1);
    ref.invalidate(liquidezProvider);
    ref.invalidate(operacionesAccionProvider(ticker));
  }

  Future<void> agregarCrypto(CryptoHolding crypto) async {
    final repo = ref.read(inversionesRepositoryProvider);
    // Solo crear el holding si no existe uno para ese symbol
    final existe = repo.getCryptos().any((c) => c.symbol == crypto.symbol);
    if (!existe) {
      await repo.saveCrypto(crypto);
      ref.read(_cryptoVersionProvider.notifier).update((n) => n + 1);
    }
    await repo.saveOperacion(OperacionLog(
      tipoActivo: TipoActivoOp.crypto,
      ticker: crypto.symbol,
      tipoOp: TipoOperacion.compra,
      cantidad: crypto.cantidad,
      precioUSD: crypto.precioCompraUSD,
      fecha: crypto.fechaAdquisicion,
      exchange: crypto.wallet,
    ));
    ref.invalidate(operacionesCryptoProvider(crypto.symbol));
  }

  Future<void> actualizarCrypto(CryptoHolding crypto) async {
    final repo = ref.read(inversionesRepositoryProvider);
    // Actualizar la operación de compra original (la más antigua) para que la
    // cantidad mostrada (derivada de ops) coincida con lo editado.
    final ops = repo.getOperaciones(ticker: crypto.symbol, tipoActivo: TipoActivoOp.crypto);
    final oldestBuy = ops.where((op) => op.tipoOp == TipoOperacion.compra).lastOrNull;
    if (oldestBuy != null) {
      await repo.saveOperacion(OperacionLog(
        id: oldestBuy.id,
        tipoActivo: TipoActivoOp.crypto,
        ticker: crypto.symbol,
        tipoOp: TipoOperacion.compra,
        cantidad: crypto.cantidad,
        precioUSD: crypto.precioCompraUSD,
        fecha: oldestBuy.fecha,
        exchange: oldestBuy.exchange,
      ));
    }
    await repo.saveCrypto(crypto);
    ref.read(_cryptoVersionProvider.notifier).update((n) => n + 1);
    ref.invalidate(operacionesCryptoProvider(crypto.symbol));
  }

  Future<void> eliminarCrypto(String id) async {
    await ref.read(inversionesRepositoryProvider).deleteCrypto(id);
    ref.read(_cryptoVersionProvider.notifier).update((n) => n + 1);
  }

  /// Elimina todos los holdings de cripto con ese symbol del portfolio,
  /// incluyendo todas las operaciones asociadas para evitar acumulación al re-agregar.
  Future<void> eliminarCryptosPorSymbol(String symbol) async {
    final repo = ref.read(inversionesRepositoryProvider);
    for (final c in repo.getCryptos().where((c) => c.symbol == symbol).toList()) {
      await repo.deleteCrypto(c.id);
    }
    for (final op in repo.getOperaciones(ticker: symbol, tipoActivo: TipoActivoOp.crypto).toList()) {
      await repo.deleteOperacion(op.id);
    }
    ref.read(_cryptoVersionProvider.notifier).update((n) => n + 1);
    ref.invalidate(operacionesCryptoProvider(symbol));
  }

  Future<void> registrarVentaCrypto({
    required String symbol,
    required double cantidad,
    required double precioVentaUSD,
    required String exchange,
  }) async {
    final repo = ref.read(inversionesRepositoryProvider);

    final op = OperacionLog(
      tipoActivo: TipoActivoOp.crypto,
      ticker: symbol,
      tipoOp: TipoOperacion.venta,
      cantidad: cantidad,
      precioUSD: precioVentaUSD,
      fecha: DateTime.now(),
      exchange: exchange,
    );
    await repo.saveOperacion(op);

    // Si la cantidad neta llega a 0, eliminar el holding
    final todasOps = repo.getOperaciones(ticker: symbol, tipoActivo: TipoActivoOp.crypto);
    final cantidadNeta = todasOps.fold(0.0, (sum, o) =>
        o.tipoOp == TipoOperacion.compra ? sum + o.cantidad : sum - o.cantidad);
    if (cantidadNeta <= 0) {
      final crypto = repo.getCryptos().where((c) => c.symbol == symbol).firstOrNull;
      if (crypto != null) await repo.deleteCrypto(crypto.id);
    }

    await repo.saveLiquidez(Liquidez(
      id: 'venta_liq_${op.id}',
      nombre: 'Venta de cripto: $symbol',
      monto: cantidad * precioVentaUSD,
      moneda: 'USD',
      institucion: exchange,
      tipo: TipoLiquidez.plataforma,
    ));
    ref.read(_cryptoVersionProvider.notifier).update((n) => n + 1);
    ref.invalidate(liquidezProvider);
    ref.invalidate(operacionesCryptoProvider(symbol));
  }

  Future<void> eliminarOperacion(OperacionLog op) async {
    final repo = ref.read(inversionesRepositoryProvider);
    await repo.deleteOperacion(op.id);
    // Si era una venta, eliminar la liquidez vinculada
    if (op.tipoOp == TipoOperacion.venta) {
      await repo.deleteLiquidez('venta_liq_${op.id}');
      ref.invalidate(liquidezProvider);
    }
    if (op.tipoActivo == TipoActivoOp.accion) {
      ref.read(_accionesVersionProvider.notifier).update((n) => n + 1);
      ref.invalidate(operacionesAccionProvider(op.ticker));
    } else {
      ref.read(_cryptoVersionProvider.notifier).update((n) => n + 1);
      ref.invalidate(operacionesCryptoProvider(op.ticker));
    }
  }

  Future<void> actualizarOperacion(OperacionLog op) async {
    final repo = ref.read(inversionesRepositoryProvider);
    await repo.saveOperacion(op);
    if (op.tipoActivo == TipoActivoOp.accion) {
      ref.read(_accionesVersionProvider.notifier).update((n) => n + 1);
      ref.invalidate(operacionesAccionProvider(op.ticker));
    } else {
      ref.read(_cryptoVersionProvider.notifier).update((n) => n + 1);
      ref.invalidate(operacionesCryptoProvider(op.ticker));
    }
  }

  Future<void> agregarInmueble(Inmueble inmueble) async {
    await ref.read(inversionesRepositoryProvider).saveInmueble(inmueble);
    ref.invalidate(inmueblesProvider);
    await _sincronizarAlquiler(inmueble);
  }

  Future<void> eliminarInmueble(String id) async {
    await ref.read(inversionesRepositoryProvider).deleteInmueble(id);
    ref.invalidate(inmueblesProvider);
    // Eliminar ingreso de alquiler vinculado
    final ingresosRepo = ref.read(ingresosRepositoryProvider);
    await ingresosRepo.delete('rent_$id');
    ref.invalidate(ingresosProvider);
    // Eliminar entrada de liquidez vinculada al alquiler
    final repo = ref.read(inversionesRepositoryProvider);
    await repo.deleteLiquidez('alq_liq_$id');
    ref.invalidate(liquidezProvider);
  }

  /// Crea o actualiza el ingreso fijo de alquiler para un inmueble,
  /// y crea/actualiza la entrada de Liquidez según la forma de cobro.
  Future<void> _sincronizarAlquiler(Inmueble inmueble) async {
    final ingresosRepo = ref.read(ingresosRepositoryProvider);
    final repo = ref.read(inversionesRepositoryProvider);

    if (inmueble.alquilerMensualUSD != null && inmueble.alquilerMensualUSD! > 0) {
      final dolarVenta = ref
              .read(dolarProvider)
              .whenOrNull(
                data: (dolares) => dolares
                    .where((d) => d.casa.toLowerCase() == 'blue')
                    .map((d) => d.venta)
                    .firstOrNull,
              ) ??
          1200.0;

      final alquilerARS = inmueble.alquilerMensualUSD! * dolarVenta;
      final ingreso = Ingreso(
        id: 'rent_${inmueble.id}',
        descripcion: 'Alquiler – ${inmueble.nombre}',
        monto: alquilerARS,
        categoria: CategoriaIngreso.alquiler,
        tipo: TipoIngreso.fijo,
        fecha: inmueble.fechaAdquisicion,
        recurrente: true,
        notas: 'USD ${inmueble.alquilerMensualUSD!.toStringAsFixed(0)}/mes · auto-generado',
      );
      await ingresosRepo.save(ingreso);

      // Crear/actualizar entrada en Liquidez según forma de cobro
      if (inmueble.alquilerFormaCobro != null) {
        final tipoLiq = inmueble.alquilerFormaCobro == FormaCobroAlquiler.efectivo
            ? TipoLiquidez.efectivo
            : TipoLiquidez.cuentaCorriente;
        final esUSD = inmueble.alquilerMoneda == 'USD';
        final montoLiq = esUSD ? inmueble.alquilerMensualUSD! : alquilerARS;
        final liq = Liquidez(
          id: 'alq_liq_${inmueble.id}',
          nombre: 'Alquiler ${inmueble.alquilerFormaCobro!.emoji} – ${inmueble.nombre}',
          monto: montoLiq,
          moneda: esUSD ? 'USD' : 'ARS',
          institucion: 'Alquiler',
          tipo: tipoLiq,
        );
        await repo.saveLiquidez(liq);
      } else {
        await repo.deleteLiquidez('alq_liq_${inmueble.id}');
      }
    } else {
      await ingresosRepo.delete('rent_${inmueble.id}');
      await repo.deleteLiquidez('alq_liq_${inmueble.id}');
    }
    ref.invalidate(ingresosProvider);
    ref.invalidate(liquidezProvider);
  }

  Future<void> agregarLiquidez(Liquidez liquidez) async {
    await ref.read(inversionesRepositoryProvider).saveLiquidez(liquidez);
    ref.invalidate(liquidezProvider);
  }

  Future<void> eliminarLiquidez(String id) async {
    await ref.read(inversionesRepositoryProvider).deleteLiquidez(id);
    ref.invalidate(liquidezProvider);
  }

  /// Suma [delta] al monto de la cuenta de liquidez con [liquidezId].
  /// Usar delta negativo para restar (ej: al eliminar un ingreso).
  Future<void> ajustarMontoLiquidez(String liquidezId, double delta) async {
    final repo = ref.read(inversionesRepositoryProvider);
    final liq = repo.getLiquidez().where((l) => l.id == liquidezId).firstOrNull;
    if (liq == null) return;
    final updated = Liquidez(
      id: liq.id,
      nombre: liq.nombre,
      monto: (liq.monto + delta).clamp(0.0, double.infinity),
      moneda: liq.moneda,
      institucion: liq.institucion,
      tipo: liq.tipo,
      vencimientoPlazoFijo: liq.vencimientoPlazoFijo,
      tasaAnualPct: liq.tasaAnualPct,
      notas: liq.notas,
    );
    await repo.saveLiquidez(updated);
    ref.invalidate(liquidezProvider);
  }

  Future<void> agregarOtra(OtraInversion otra) async {
    await ref.read(inversionesRepositoryProvider).saveOtra(otra);
    ref.invalidate(otrasInversionesProvider);
  }

  Future<void> eliminarOtra(String id) async {
    await ref.read(inversionesRepositoryProvider).deleteOtra(id);
    ref.invalidate(otrasInversionesProvider);
  }

  Future<void> agregarInstrumento(InstrumentoFinanciero inst) async {
    await ref.read(inversionesRepositoryProvider).saveInstrumento(inst);
    ref.invalidate(instrumentosProvider);
  }

  Future<void> eliminarInstrumento(String id) async {
    await ref.read(inversionesRepositoryProvider).deleteInstrumento(id);
    ref.invalidate(instrumentosProvider);
  }

  Future<void> agregarBien(BienDeUso bien) async {
    await ref.read(inversionesRepositoryProvider).saveBien(bien);
    ref.invalidate(bienesProvider);
  }

  Future<void> eliminarBien(String id) async {
    await ref.read(inversionesRepositoryProvider).deleteBien(id);
    ref.invalidate(bienesProvider);
  }

  Future<void> agregarAlternativa(InversionAlternativa alt) async {
    await ref.read(inversionesRepositoryProvider).saveAlternativa(alt);
    ref.invalidate(alternativasProvider);
  }

  Future<void> eliminarAlternativa(String id) async {
    await ref.read(inversionesRepositoryProvider).deleteAlternativa(id);
    ref.invalidate(alternativasProvider);
  }

  Future<void> agregarNegocio(NegocioPersonal negocio) async {
    await ref.read(inversionesRepositoryProvider).saveNegocio(negocio);
    ref.invalidate(negociosPersonalesProvider);
    await _sincronizarDividendos(negocio);
  }

  Future<void> actualizarNegocio(NegocioPersonal negocio) async {
    await ref.read(inversionesRepositoryProvider).saveNegocio(negocio);
    ref.invalidate(negociosPersonalesProvider);
    await _sincronizarDividendos(negocio);
  }

  Future<void> eliminarNegocio(String id) async {
    final repo = ref.read(inversionesRepositoryProvider);
    await repo.deleteNegocio(id);
    ref.invalidate(negociosPersonalesProvider);
    final ingresosRepo = ref.read(ingresosRepositoryProvider);
    await ingresosRepo.delete('div_ing_$id');
    await repo.deleteLiquidez('div_liq_$id');
    ref.invalidate(ingresosProvider);
    ref.invalidate(liquidezProvider);
  }

  Future<void> _sincronizarDividendos(NegocioPersonal negocio) async {
    final ingresosRepo = ref.read(ingresosRepositoryProvider);
    final repo = ref.read(inversionesRepositoryProvider);

    if (negocio.montoDividendo != null &&
        negocio.montoDividendo! > 0 &&
        negocio.frecuenciaDividendo != null) {
      final montoMensual = negocio.montoDividendo! / negocio.frecuenciaDividendo!.mesesPorPeriodo;
      final monedaDiv = negocio.monedaDivEfectiva;
      final esUSD = monedaDiv == 'USD';

      await ingresosRepo.save(Ingreso(
        id: 'div_ing_${negocio.id}',
        descripcion: 'Dividendos – ${negocio.nombre}',
        monto: montoMensual,
        esUSD: esUSD,
        categoria: CategoriaIngreso.dividendos,
        tipo: TipoIngreso.fijo,
        fecha: negocio.fechaDividendo ?? negocio.fechaAdquisicion,
        recurrente: true,
        duracionMeses: negocio.frecuenciaDividendo!.mesesPorPeriodo,
        notas: '${negocio.frecuenciaDividendo!.label}: ${negocio.montoDividendo!.toStringAsFixed(2)} $monedaDiv · auto-generado',
      ));

      await repo.saveLiquidez(Liquidez(
        id: 'div_liq_${negocio.id}',
        nombre: 'Dividendos ${negocio.frecuenciaDividendo!.label} – ${negocio.nombre}',
        monto: negocio.montoDividendo!,
        moneda: monedaDiv,
        institucion: negocio.nombre,
        tipo: TipoLiquidez.plataforma,
      ));
    } else {
      await ingresosRepo.delete('div_ing_${negocio.id}');
      await repo.deleteLiquidez('div_liq_${negocio.id}');
    }
    ref.invalidate(ingresosProvider);
    ref.invalidate(liquidezProvider);
  }
}

final inversionesNotifierProvider = NotifierProvider<InversionesNotifier, void>(
  InversionesNotifier.new,
);
