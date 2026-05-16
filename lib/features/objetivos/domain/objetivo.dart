import 'package:uuid/uuid.dart';

enum TipoObjetivo {
  ahorro('Ahorro', '💰'),
  inversion('Inversión', '📈'),
  deuda('Pagar Deuda', '💳'),
  compra('Compra', '🛒'),
  emergencia('Fondo de Emergencia', '🛡️'),
  viaje('Viaje', '✈️'),
  otro('Otro', '🎯');

  const TipoObjetivo(this.label, this.emoji);
  final String label;
  final String emoji;
}

enum MonedaObjetivo { ars, usd }

class Objetivo {
  final String id;
  final String nombre;
  final String descripcion;
  final double montoMeta;
  final double montoActual;
  final MonedaObjetivo moneda;
  final TipoObjetivo tipo;
  final DateTime fechaInicio;
  final DateTime fechaMeta;
  final String? colorHex;
  final List<double> historialMensual;
  final String? link;

  Objetivo({
    String? id,
    required this.nombre,
    required this.descripcion,
    required this.montoMeta,
    required this.montoActual,
    required this.moneda,
    required this.tipo,
    required this.fechaInicio,
    required this.fechaMeta,
    this.colorHex,
    List<double>? historialMensual,
    this.link,
  })  : id = id ?? const Uuid().v4(),
        historialMensual = historialMensual ?? [];

  double get progresoPct =>
      montoMeta > 0 ? (montoActual / montoMeta).clamp(0.0, 1.0) : 0.0;

  int get diasRestantes =>
      fechaMeta.difference(DateTime.now()).inDays.clamp(0, 9999);

  bool get completado => montoActual >= montoMeta;

  /// Ahorro mensual requerido para alcanzar la meta
  double get ahorroMensualRequerido {
    if (completado) return 0;
    final restante = montoMeta - montoActual;
    final mesesRestantes = (fechaMeta.difference(DateTime.now()).inDays / 30)
        .ceil()
        .clamp(1, 9999);
    return restante / mesesRestantes;
  }

  Objetivo copyWith({
    String? nombre,
    String? descripcion,
    double? montoMeta,
    double? montoActual,
    MonedaObjetivo? moneda,
    TipoObjetivo? tipo,
    DateTime? fechaInicio,
    DateTime? fechaMeta,
    String? colorHex,
    List<double>? historialMensual,
    String? link,
    bool clearLink = false,
  }) {
    return Objetivo(
      id: id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      montoMeta: montoMeta ?? this.montoMeta,
      montoActual: montoActual ?? this.montoActual,
      moneda: moneda ?? this.moneda,
      tipo: tipo ?? this.tipo,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaMeta: fechaMeta ?? this.fechaMeta,
      colorHex: colorHex ?? this.colorHex,
      historialMensual: historialMensual ?? this.historialMensual,
      link: clearLink ? null : (link ?? this.link),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'descripcion': descripcion,
        'montoMeta': montoMeta,
        'montoActual': montoActual,
        'moneda': moneda.name,
        'tipo': tipo.name,
        'fechaInicio': fechaInicio.toIso8601String(),
        'fechaMeta': fechaMeta.toIso8601String(),
        'colorHex': colorHex,
        'historialMensual': historialMensual,
        'link': link,
      };

  factory Objetivo.fromJson(Map<String, dynamic> json) {
    return Objetivo(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String,
      montoMeta: (json['montoMeta'] as num).toDouble(),
      montoActual: (json['montoActual'] as num).toDouble(),
      moneda: MonedaObjetivo.values.firstWhere(
        (m) => m.name == json['moneda'],
        orElse: () => MonedaObjetivo.ars,
      ),
      tipo: TipoObjetivo.values.firstWhere(
        (t) => t.name == json['tipo'],
        orElse: () => TipoObjetivo.ahorro,
      ),
      fechaInicio: DateTime.parse(json['fechaInicio'] as String),
      fechaMeta: DateTime.parse(json['fechaMeta'] as String),
      colorHex: json['colorHex'] as String?,
      historialMensual: (json['historialMensual'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      link: json['link'] as String?,
    );
  }
}
