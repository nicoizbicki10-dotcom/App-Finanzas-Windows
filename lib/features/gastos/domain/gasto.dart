import 'package:uuid/uuid.dart';

enum TipoGasto { fijo, variable }

enum CategoriaGasto {
  vivienda('Vivienda', '🏠'),
  alimentacion('Alimentación', '🛒'),
  transporte('Transporte', '🚗'),
  salud('Salud', '🏥'),
  educacion('Educación', '📚'),
  entretenimiento('Entretenimiento', '🎬'),
  servicios('Servicios', '📱'),
  ropa('Ropa', '👕'),
  mascotas('Mascotas', '🐾'),
  otros('Otros', '📦');

  const CategoriaGasto(this.label, this.emoji);
  final String label;
  final String emoji;
}

const Map<CategoriaGasto, List<String>> subcategoriasPorCategoria = {
  CategoriaGasto.vivienda: ['Alquiler', 'Expensas', 'Hipoteca', 'Mantenimiento', 'Seguro del hogar'],
  CategoriaGasto.alimentacion: ['Supermercado', 'Restaurante/Bar', 'Delivery', 'Verdulería/Feria'],
  CategoriaGasto.transporte: ['Combustible', 'Estacionamiento', 'Peajes', 'Seguro del auto', 'Patente', 'Repuestos', 'SUBE'],
  CategoriaGasto.salud: ['Prepaga/Obra Social', 'Farmacia', 'Consulta médica', 'Gimnasio'],
  CategoriaGasto.educacion: ['Cuota colegio', 'Universidad', 'Cursos', 'Libros/Material'],
  CategoriaGasto.entretenimiento: ['Cine/Teatro', 'Viajes', 'Juegos', 'Suscripciones'],
  CategoriaGasto.servicios: ['Luz', 'Gas', 'Internet', 'Agua', 'Teléfono', 'Streaming', 'Seguro'],
  CategoriaGasto.ropa: ['Ropa', 'Calzado', 'Accesorios'],
  CategoriaGasto.mascotas: ['Veterinaria', 'Alimento', 'Accesorios'],
};

class Gasto {
  final String id;
  final String descripcion;
  final double monto;
  final bool esUSD;
  final CategoriaGasto categoria;
  final String? subcategoria;
  final TipoGasto tipo;
  final DateTime fecha;
  final String? notas;
  final bool recurrente;
  /// Duración en meses para gastos fijos. null = indefinido.
  final int? duracionMeses;
  /// ID de la cuenta de liquidez (medio de pago) que se debita.
  final String? medioPagoId;

  Gasto({
    String? id,
    required this.descripcion,
    required this.monto,
    this.esUSD = false,
    required this.categoria,
    this.subcategoria,
    required this.tipo,
    required this.fecha,
    this.notas,
    this.recurrente = false,
    this.duracionMeses,
    this.medioPagoId,
  }) : id = id ?? const Uuid().v4();

  Gasto copyWith({
    String? descripcion,
    double? monto,
    bool? esUSD,
    CategoriaGasto? categoria,
    String? subcategoria,
    TipoGasto? tipo,
    DateTime? fecha,
    String? notas,
    bool? recurrente,
    int? duracionMeses,
    String? medioPagoId,
    bool clearMedioPago = false,
  }) {
    return Gasto(
      id: id,
      descripcion: descripcion ?? this.descripcion,
      monto: monto ?? this.monto,
      esUSD: esUSD ?? this.esUSD,
      categoria: categoria ?? this.categoria,
      subcategoria: subcategoria ?? this.subcategoria,
      tipo: tipo ?? this.tipo,
      fecha: fecha ?? this.fecha,
      notas: notas ?? this.notas,
      recurrente: recurrente ?? this.recurrente,
      duracionMeses: duracionMeses ?? this.duracionMeses,
      medioPagoId: clearMedioPago ? null : (medioPagoId ?? this.medioPagoId),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'descripcion': descripcion,
        'monto': monto,
        'esUSD': esUSD,
        'categoria': categoria.name,
        'subcategoria': subcategoria,
        'tipo': tipo.name,
        'fecha': fecha.toIso8601String(),
        'notas': notas,
        'recurrente': recurrente,
        'duracionMeses': duracionMeses,
        'medioPagoId': medioPagoId,
      };

  factory Gasto.fromJson(Map<String, dynamic> json) {
    return Gasto(
      id: json['id'] as String,
      descripcion: json['descripcion'] as String,
      monto: (json['monto'] as num).toDouble(),
      esUSD: json['esUSD'] as bool? ?? false,
      categoria: CategoriaGasto.values.firstWhere(
        (c) => c.name == json['categoria'],
        orElse: () => CategoriaGasto.otros,
      ),
      subcategoria: json['subcategoria'] as String?,
      tipo: TipoGasto.values.firstWhere(
        (t) => t.name == json['tipo'],
        orElse: () => TipoGasto.variable,
      ),
      fecha: DateTime.parse(json['fecha'] as String),
      notas: json['notas'] as String?,
      recurrente: json['recurrente'] as bool? ?? false,
      duracionMeses: json['duracionMeses'] as int?,
      medioPagoId: json['medioPagoId'] as String?,
    );
  }
}
