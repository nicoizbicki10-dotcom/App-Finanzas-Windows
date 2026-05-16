class DolarQuote {
  final String casa;
  final String nombre;
  final double compra;
  final double venta;
  final DateTime fechaActualizacion;

  const DolarQuote({
    required this.casa,
    required this.nombre,
    required this.compra,
    required this.venta,
    required this.fechaActualizacion,
  });

  factory DolarQuote.fromJson(Map<String, dynamic> json) {
    return DolarQuote(
      casa: json['casa'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      compra: (json['compra'] as num?)?.toDouble() ?? 0.0,
      venta: (json['venta'] as num?)?.toDouble() ?? 0.0,
      fechaActualizacion: json['fechaActualizacion'] != null
          ? DateTime.tryParse(json['fechaActualizacion'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  DolarQuote copyWith({
    String? casa,
    String? nombre,
    double? compra,
    double? venta,
    DateTime? fechaActualizacion,
  }) {
    return DolarQuote(
      casa: casa ?? this.casa,
      nombre: nombre ?? this.nombre,
      compra: compra ?? this.compra,
      venta: venta ?? this.venta,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
    );
  }

  @override
  String toString() =>
      'DolarQuote(casa: $casa, compra: $compra, venta: $venta)';
}
