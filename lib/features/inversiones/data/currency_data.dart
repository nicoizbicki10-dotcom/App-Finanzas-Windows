class MonedaInfo {
  final String codigo;
  final String nombre;
  final String simbolo;
  /// Tasa aproximada frente al USD (ARS = 0 porque se usa el dólar blue).
  final double approxUSD;

  const MonedaInfo({
    required this.codigo,
    required this.nombre,
    required this.simbolo,
    required this.approxUSD,
  });
}

const List<MonedaInfo> kMonedas = [
  MonedaInfo(codigo: 'USD', nombre: 'Dólar estadounidense', simbolo: 'USD', approxUSD: 1.00),
  MonedaInfo(codigo: 'ARS', nombre: 'Peso Argentino',       simbolo: '\$',  approxUSD: 0.00),
  MonedaInfo(codigo: 'EUR', nombre: 'Euro',                 simbolo: '€',   approxUSD: 1.08),
  MonedaInfo(codigo: 'GBP', nombre: 'Libra esterlina',      simbolo: '£',   approxUSD: 1.27),
  MonedaInfo(codigo: 'CNY', nombre: 'Yuan chino',           simbolo: '¥',   approxUSD: 0.14),
  MonedaInfo(codigo: 'CHF', nombre: 'Franco suizo',         simbolo: 'CHF', approxUSD: 1.12),
  MonedaInfo(codigo: 'UYU', nombre: 'Peso Uruguayo',        simbolo: '\$U', approxUSD: 0.025),
  MonedaInfo(codigo: 'AUD', nombre: 'Dólar australiano',    simbolo: 'A\$', approxUSD: 0.65),
  MonedaInfo(codigo: 'CAD', nombre: 'Dólar canadiense',     simbolo: 'C\$', approxUSD: 0.73),
  MonedaInfo(codigo: 'MXN', nombre: 'Peso mexicano',        simbolo: '\$',  approxUSD: 0.057),
  MonedaInfo(codigo: 'NZD', nombre: 'Dólar neozelandés',    simbolo: 'NZ\$',approxUSD: 0.60),
  MonedaInfo(codigo: 'BRL', nombre: 'Real brasileño',       simbolo: 'R\$', approxUSD: 0.17),
];

MonedaInfo monedaInfo(String codigo) =>
    kMonedas.firstWhere((m) => m.codigo == codigo, orElse: () => kMonedas.first);

/// Convierte monto en [moneda] a USD.
/// Para ARS usa el dólar blue real; para otras usa tasas aproximadas.
double monedaToUSD(double monto, String moneda, double dolarBlue) {
  if (moneda == 'ARS') return monto / dolarBlue;
  if (moneda == 'USD') return monto;
  return monto * (monedaInfo(moneda).approxUSD);
}
