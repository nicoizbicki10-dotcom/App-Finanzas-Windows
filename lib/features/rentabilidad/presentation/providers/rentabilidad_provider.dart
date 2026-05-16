import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../inversiones/data/currency_data.dart';
import '../../../inversiones/presentation/providers/inversiones_provider.dart';
import '../../../market_data/providers/market_data_providers.dart';
import '../../domain/asset_performance.dart';

final periodoSeleccionadoProvider = StateProvider<PeriodoRentabilidad>((ref) {
  return PeriodoRentabilidad.total;
});

/// Calcula la rentabilidad de todos los activos y los ordena de mayor a menor
final rentabilidadProvider = FutureProvider<List<AssetPerformance>>((ref) async {
  final periodo = ref.watch(periodoSeleccionadoProvider);
  final acciones = ref.watch(accionesProvider);
  final cryptos = ref.watch(cryptoHoldingsProvider);
  final inmuebles = ref.watch(inmueblesProvider);
  final otras = ref.watch(otrasInversionesProvider);

  final performances = <AssetPerformance>[];

  // Obtener cotización dólar blue para conversiones
  final dolarAsync = ref.watch(dolarProvider);
  final dolares = dolarAsync.value ?? [];
  final dolarVenta = dolares
      .where((d) => d.casa.toLowerCase() == 'blue')
      .map((d) => d.venta)
      .firstOrNull ?? 1050.0;

  // ─── Acciones ─────────────────────────────────────────────────────────────
  for (final accion in acciones) {
    final quoteAsync = ref.watch(stockQuoteProvider(accion.ticker));
    final quote = quoteAsync.value;
    if (quote == null) continue;

    final valorActual = accion.cantidad * quote.currentPrice;
    final costoTotal = accion.costoTotalUSD();
    final rentPct = costoTotal > 0
        ? ((valorActual - costoTotal) / costoTotal) * 100
        : 0.0;

    performances.add(AssetPerformance(
      id: accion.id,
      nombre: accion.ticker,
      tipo: 'Acción',
      emoji: '📈',
      rentabilidadPct: rentPct,
      rentabilidadARS: (valorActual - costoTotal) * dolarVenta,
      valorActualUSD: valorActual,
      costoOriginalUSD: costoTotal,
      periodo: periodo,
    ));
  }

  // ─── Criptomonedas ────────────────────────────────────────────────────────
  if (cryptos.isNotEmpty) {
    final coinIds = cryptos.map((c) => c.coingeckoId).toSet().join(',');
    final pricesAsync = ref.watch(cryptoPricesProvider(coinIds));
    final prices = pricesAsync.value ?? [];
    final priceMap = {for (final p in prices) p.id: p.currentPrice};

    for (final holding in cryptos) {
      final currentPrice = priceMap[holding.coingeckoId] ?? holding.precioCompraUSD;
      final valorActual = holding.cantidad * currentPrice;
      final costoTotal = holding.costoTotalUSD();
      final rentPct = costoTotal > 0
          ? ((valorActual - costoTotal) / costoTotal) * 100
          : 0.0;

      performances.add(AssetPerformance(
        id: holding.id,
        nombre: holding.symbol,
        tipo: 'Cripto',
        emoji: '₿',
        rentabilidadPct: rentPct,
        rentabilidadARS: (valorActual - costoTotal) * dolarVenta,
        valorActualUSD: valorActual,
        costoOriginalUSD: costoTotal,
        periodo: periodo,
      ));
    }
  }

  // ─── Inmuebles ────────────────────────────────────────────────────────────
  for (final inmueble in inmuebles) {
    final costoUSD = inmueble.costoOriginalUSD;
    final valorActual = inmueble.valorEstimadoUSD;
    final rentPct = costoUSD > 0
        ? ((valorActual - costoUSD) / costoUSD) * 100
        : 0.0;

    performances.add(AssetPerformance(
      id: inmueble.id,
      nombre: inmueble.nombre,
      tipo: 'Inmueble',
      emoji: '🏠',
      rentabilidadPct: rentPct,
      rentabilidadARS: (valorActual - costoUSD) * dolarVenta,
      valorActualUSD: valorActual,
      costoOriginalUSD: inmueble.costoOriginalUSD,
      periodo: periodo,
    ));
  }

  // ─── Otras inversiones ────────────────────────────────────────────────────
  for (final otra in otras) {
    final valorUSD = monedaToUSD(otra.monto, otra.moneda, dolarVenta);
    performances.add(AssetPerformance(
      id: otra.id,
      nombre: otra.nombre,
      tipo: 'Otra',
      emoji: '📦',
      rentabilidadPct: 0.0,
      rentabilidadARS: 0.0,
      valorActualUSD: valorUSD,
      costoOriginalUSD: valorUSD,
      periodo: periodo,
    ));
  }

  // Ordenar de mayor a menor rentabilidad
  performances.sort((a, b) => b.rentabilidadPct.compareTo(a.rentabilidadPct));
  return performances;
});
