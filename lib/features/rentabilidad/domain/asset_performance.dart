enum PeriodoRentabilidad {
  unMes('1M'),
  tresMeses('3M'),
  seisMeses('6M'),
  unAnio('1A'),
  total('Total');

  const PeriodoRentabilidad(this.label);
  final String label;
}

class AssetPerformance {
  final String id;
  final String nombre;
  final String tipo;
  final String emoji;
  final double rentabilidadPct;
  final double rentabilidadARS;
  final double valorActualUSD;
  final double costoOriginalUSD;
  final PeriodoRentabilidad periodo;

  const AssetPerformance({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.emoji,
    required this.rentabilidadPct,
    required this.rentabilidadARS,
    required this.valorActualUSD,
    required this.costoOriginalUSD,
    required this.periodo,
  });

  bool get isPositive => rentabilidadPct >= 0;
}
