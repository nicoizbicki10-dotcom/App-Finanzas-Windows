import 'package:uuid/uuid.dart';

enum TipoIngreso { fijo, variable }

enum CategoriaIngreso {
  salario('Salario', '💼'),
  freelance('Freelance', '💻'),
  alquiler('Alquiler', '🏠'),
  dividendos('Dividendos', '📈'),
  venta('Venta', '🛍️'),
  bono('Bono', '🎁'),
  pension('Pensión/Jubilación', '👴'),
  otro('Otro', '💰');

  const CategoriaIngreso(this.label, this.emoji);
  final String label;
  final String emoji;
}

class Ingreso {
  final String id;
  final String descripcion;
  final double monto;
  final bool esUSD;
  final CategoriaIngreso categoria;
  final TipoIngreso tipo;
  final DateTime fecha;
  final String? notas;
  final bool recurrente;
  /// ID de la cuenta de liquidez donde se acredita este ingreso (opcional).
  final String? liquidezDestinoId;
  /// Duración en meses para ingresos fijos. null = indefinido.
  final int? duracionMeses;

  Ingreso({
    String? id,
    required this.descripcion,
    required this.monto,
    this.esUSD = false,
    required this.categoria,
    required this.tipo,
    required this.fecha,
    this.notas,
    this.recurrente = false,
    this.liquidezDestinoId,
    this.duracionMeses,
  }) : id = id ?? const Uuid().v4();

  Ingreso copyWith({
    String? descripcion,
    double? monto,
    bool? esUSD,
    CategoriaIngreso? categoria,
    TipoIngreso? tipo,
    DateTime? fecha,
    String? notas,
    bool? recurrente,
    String? liquidezDestinoId,
    bool clearLiquidezDestino = false,
    int? duracionMeses,
  }) {
    return Ingreso(
      id: id,
      descripcion: descripcion ?? this.descripcion,
      monto: monto ?? this.monto,
      esUSD: esUSD ?? this.esUSD,
      categoria: categoria ?? this.categoria,
      tipo: tipo ?? this.tipo,
      fecha: fecha ?? this.fecha,
      notas: notas ?? this.notas,
      recurrente: recurrente ?? this.recurrente,
      liquidezDestinoId: clearLiquidezDestino
          ? null
          : (liquidezDestinoId ?? this.liquidezDestinoId),
      duracionMeses: duracionMeses ?? this.duracionMeses,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'descripcion': descripcion,
        'monto': monto,
        'esUSD': esUSD,
        'categoria': categoria.name,
        'tipo': tipo.name,
        'fecha': fecha.toIso8601String(),
        'notas': notas,
        'recurrente': recurrente,
        'liquidezDestinoId': liquidezDestinoId,
        'duracionMeses': duracionMeses,
      };

  factory Ingreso.fromJson(Map<String, dynamic> json) {
    return Ingreso(
      id: json['id'] as String,
      descripcion: json['descripcion'] as String,
      monto: (json['monto'] as num).toDouble(),
      esUSD: json['esUSD'] as bool? ?? false,
      categoria: CategoriaIngreso.values.firstWhere(
        (c) => c.name == json['categoria'],
        orElse: () => CategoriaIngreso.otro,
      ),
      tipo: TipoIngreso.values.firstWhere(
        (t) => t.name == json['tipo'],
        orElse: () => TipoIngreso.variable,
      ),
      fecha: DateTime.parse(json['fecha'] as String),
      notas: json['notas'] as String?,
      recurrente: json['recurrente'] as bool? ?? false,
      liquidezDestinoId: json['liquidezDestinoId'] as String?,
      duracionMeses: json['duracionMeses'] as int?,
    );
  }
}
