import 'dart:math';

import 'package:uuid/uuid.dart';

// ─── Enums ─────────────────────────────────────────────────────────────────

enum TipoInversion { inmueble, accion, crypto, liquidez, otra, instrumento, bien, negocio, alternativa }

enum FrecuenciaDividendo {
  mensual('Mensual', 1),
  trimestral('Trimestral', 3),
  semestral('Semestral', 6),
  anual('Anual', 12);

  const FrecuenciaDividendo(this.label, this.mesesPorPeriodo);
  final String label;
  final int mesesPorPeriodo;
}

enum FormaCobroAlquiler {
  efectivo('Efectivo', '💵'),
  transferencia('Transferencia', '🏦');

  const FormaCobroAlquiler(this.label, this.emoji);
  final String label;
  final String emoji;
}

enum EstadoInmueble {
  pozo('En Pozo', '🏗️'),
  enConstruccion('En Construcción', '🚧'),
  pendienteEntrega('Pendiente de Entrega', '📋'),
  finalizado('Finalizado', '✅');

  const EstadoInmueble(this.label, this.emoji);
  final String label;
  final String emoji;
}

enum TipoBienDeUso {
  auto('Auto', '🚗'),
  moto('Moto', '🏍️'),
  camioneta('Camioneta', '🚙'),
  barco('Barco', '⛵'),
  camion('Camión', '🚛'),
  maquinaria('Maquinaria', '🏗️'),
  electrodomestico('Electrodoméstico', '📺'),
  otro('Otro', '📦');

  const TipoBienDeUso(this.label, this.emoji);
  final String label;
  final String emoji;
}

enum TipoAlternativa {
  oro24k('Oro 24K', '🥇', 'g', 1.0),
  oro18k('Oro 18K', '🥇', 'g', 0.75),
  oro14k('Oro 14K', '🥇', 'g', 0.5833),
  plata('Plata', '🥈', 'g', 1.0),
  reloj('Reloj', '⌚', 'u', 0.0),
  joya('Joya', '💎', 'u', 0.0),
  arte('Arte', '🎨', 'u', 0.0),
  coleccionable('Coleccionable', '🏺', 'u', 0.0),
  otro('Otro', '📦', 'u', 0.0);

  const TipoAlternativa(this.label, this.emoji, this.unidad, this.pureza);
  final String label;
  final String emoji;
  final String unidad; // 'g' = gramos (metales), 'u' = unidades
  final double pureza; // factor de pureza para oro (0 para no-metales)

  bool get esMetal => unidad == 'g';
  bool get esOro => this == oro24k || this == oro18k || this == oro14k;
  bool get esPlata => this == plata;
}

enum TipoOperacion { compra, venta }
enum TipoActivoOp { accion, crypto }

enum TipoLiquidez {
  cuentaCorriente('Cuenta Corriente', '🏦'),
  cajaAhorroARS('Caja Ahorro ARS', '💵'),
  cajaAhorroUSD('Caja Ahorro USD', '💰'),
  plazoFijo('Plazo Fijo', '📅'),
  fondoComun('Fondo Común', '📊'),
  efectivo('Efectivo', '💵'),
  plataforma('Liquidez en Plataforma', '🖥️'),
  personalizado('Personalizado', '🏷️');

  const TipoLiquidez(this.label, this.emoji);
  final String label;
  final String emoji;
}

enum TipoInteres { simple, compuesto }

enum UnidadDuracion { dias, meses, anios }

enum TipoInstrumento {
  plazoFijo('Plazo Fijo', '📅'),
  fci('Fondo Común de Inversión', '📊'),
  bono('Bono', '📜'),
  on('Obligación Negociable', '📋'),
  lecer('LECER', '🏛️'),
  lecap('LECAP', '🏛️'),
  cdt('CDT', '🏦'),
  otro('Otro', '📌');

  const TipoInstrumento(this.label, this.emoji);
  final String label;
  final String emoji;
}

// ─── Inmueble ───────────────────────────────────────────────────────────────

class Inmueble {
  final String id;
  final String nombre;
  final String direccion;
  final String? barrio;
  final double costoOriginalUSD;
  final double valorEstimadoUSD;
  final DateTime fechaAdquisicion;
  final double superficieM2;
  final double? alquilerMensualUSD;
  /// Moneda en la que se cobra el alquiler (default: 'USD').
  final String alquilerMoneda;
  /// Forma de cobro del alquiler.
  final FormaCobroAlquiler? alquilerFormaCobro;
  /// Porcentaje de propiedad (Parte Indivisa). Default 100.
  final double parteIndivisaPct;
  final String? notas;
  /// Cantidad de ambientes (1, 2, 3, …).
  final int? ambientes;
  /// Año de construcción del inmueble.
  final int? anioConstru;
  /// Estado del inmueble.
  final EstadoInmueble? estadoInmueble;

  Inmueble({
    String? id,
    required this.nombre,
    required this.direccion,
    this.barrio,
    required this.costoOriginalUSD,
    required this.valorEstimadoUSD,
    required this.fechaAdquisicion,
    required this.superficieM2,
    this.alquilerMensualUSD,
    this.alquilerMoneda = 'USD',
    this.alquilerFormaCobro,
    this.parteIndivisaPct = 100.0,
    this.notas,
    this.ambientes,
    this.anioConstru,
    this.estadoInmueble,
  }) : id = id ?? const Uuid().v4();

  double get factorParteIndivisa => parteIndivisaPct / 100.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'direccion': direccion,
        'barrio': barrio,
        'costoOriginalUSD': costoOriginalUSD,
        'valorEstimadoUSD': valorEstimadoUSD,
        'fechaAdquisicion': fechaAdquisicion.toIso8601String(),
        'superficieM2': superficieM2,
        'alquilerMensualUSD': alquilerMensualUSD,
        'alquilerMoneda': alquilerMoneda,
        'alquilerFormaCobro': alquilerFormaCobro?.name,
        'parteIndivisaPct': parteIndivisaPct,
        'notas': notas,
        'ambientes': ambientes,
        'anioConstru': anioConstru,
        'estadoInmueble': estadoInmueble?.name,
        'tipo': TipoInversion.inmueble.name,
      };

  factory Inmueble.fromJson(Map<String, dynamic> json) {
    return Inmueble(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      direccion: json['direccion'] as String,
      barrio: json['barrio'] as String?,
      costoOriginalUSD: ((json['costoOriginalUSD'] ?? json['costoOriginalARS']) as num).toDouble(),
      valorEstimadoUSD: (json['valorEstimadoUSD'] as num).toDouble(),
      fechaAdquisicion: DateTime.parse(json['fechaAdquisicion'] as String),
      superficieM2: (json['superficieM2'] as num).toDouble(),
      alquilerMensualUSD: ((json['alquilerMensualUSD'] ?? json['alquilerMensualARS']) as num?)?.toDouble(),
      alquilerMoneda: json['alquilerMoneda'] as String? ?? 'USD',
      alquilerFormaCobro: json['alquilerFormaCobro'] != null
          ? FormaCobroAlquiler.values.firstWhere(
              (f) => f.name == json['alquilerFormaCobro'],
              orElse: () => FormaCobroAlquiler.efectivo,
            )
          : null,
      parteIndivisaPct: (json['parteIndivisaPct'] as num?)?.toDouble() ?? 100.0,
      notas: json['notas'] as String?,
      ambientes: (json['ambientes'] as num?)?.toInt(),
      anioConstru: (json['anioConstru'] as num?)?.toInt(),
      estadoInmueble: json['estadoInmueble'] != null
          ? EstadoInmueble.values.firstWhere(
              (e) => e.name == json['estadoInmueble'],
              orElse: () => EstadoInmueble.finalizado,
            )
          : null,
    );
  }
}

// ─── Accion ─────────────────────────────────────────────────────────────────

class Accion {
  final String id;
  final String ticker;
  final String nombre;
  final double cantidad;
  final double precioCompraUSD;
  final DateTime fechaAdquisicion;
  final String exchange;
  final String? notas;

  Accion({
    String? id,
    required this.ticker,
    required this.nombre,
    required this.cantidad,
    required this.precioCompraUSD,
    required this.fechaAdquisicion,
    required this.exchange,
    this.notas,
  }) : id = id ?? const Uuid().v4();

  double costoTotalUSD() => cantidad * precioCompraUSD;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ticker': ticker,
        'nombre': nombre,
        'cantidad': cantidad,
        'precioCompraUSD': precioCompraUSD,
        'fechaAdquisicion': fechaAdquisicion.toIso8601String(),
        'exchange': exchange,
        'notas': notas,
        'tipo': TipoInversion.accion.name,
      };

  factory Accion.fromJson(Map<String, dynamic> json) {
    return Accion(
      id: json['id'] as String,
      ticker: json['ticker'] as String,
      nombre: json['nombre'] as String,
      cantidad: (json['cantidad'] as num).toDouble(),
      precioCompraUSD: (json['precioCompraUSD'] as num).toDouble(),
      fechaAdquisicion: DateTime.parse(json['fechaAdquisicion'] as String),
      exchange: json['exchange'] as String? ?? 'NASDAQ',
      notas: json['notas'] as String?,
    );
  }
}

// ─── CryptoHolding ──────────────────────────────────────────────────────────

class CryptoHolding {
  final String id;
  final String coingeckoId;
  final String symbol;
  final String nombre;
  final double cantidad;
  final double precioCompraUSD;
  final DateTime fechaAdquisicion;
  final String? wallet;
  final String? notas;

  CryptoHolding({
    String? id,
    required this.coingeckoId,
    required this.symbol,
    required this.nombre,
    required this.cantidad,
    required this.precioCompraUSD,
    required this.fechaAdquisicion,
    this.wallet,
    this.notas,
  }) : id = id ?? const Uuid().v4();

  double costoTotalUSD() => cantidad * precioCompraUSD;

  Map<String, dynamic> toJson() => {
        'id': id,
        'coingeckoId': coingeckoId,
        'symbol': symbol,
        'nombre': nombre,
        'cantidad': cantidad,
        'precioCompraUSD': precioCompraUSD,
        'fechaAdquisicion': fechaAdquisicion.toIso8601String(),
        'wallet': wallet,
        'notas': notas,
        'tipo': TipoInversion.crypto.name,
      };

  factory CryptoHolding.fromJson(Map<String, dynamic> json) {
    return CryptoHolding(
      id: json['id'] as String,
      coingeckoId: json['coingeckoId'] as String,
      symbol: json['symbol'] as String,
      nombre: json['nombre'] as String,
      cantidad: (json['cantidad'] as num).toDouble(),
      precioCompraUSD: (json['precioCompraUSD'] as num).toDouble(),
      fechaAdquisicion: DateTime.parse(json['fechaAdquisicion'] as String),
      wallet: json['wallet'] as String?,
      notas: json['notas'] as String?,
    );
  }
}

// ─── Liquidez ───────────────────────────────────────────────────────────────

class Liquidez {
  final String id;
  final String nombre;
  final double monto;
  final String moneda; // 'ARS', 'USD', 'EUR', etc.
  final String institucion;
  final TipoLiquidez tipo;
  final String? tipoPersonalizado; // label when tipo == personalizado
  final DateTime? vencimientoPlazoFijo;
  final double? tasaAnualPct;
  final String? notas;

  Liquidez({
    String? id,
    required this.nombre,
    required this.monto,
    this.moneda = 'ARS',
    required this.institucion,
    required this.tipo,
    this.tipoPersonalizado,
    this.vencimientoPlazoFijo,
    this.tasaAnualPct,
    this.notas,
  }) : id = id ?? const Uuid().v4();

  String get tipoLabel => (tipo == TipoLiquidez.personalizado && tipoPersonalizado != null && tipoPersonalizado!.isNotEmpty)
      ? tipoPersonalizado!
      : tipo.label;

  // Getters de compatibilidad con el código existente
  double get montoARS => moneda == 'ARS' ? monto : 0.0;
  double get montoUSD => moneda == 'USD' ? monto : 0.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'monto': monto,
        'moneda': moneda,
        'institucion': institucion,
        'tipo': tipo.name,
        'tipoPersonalizado': tipoPersonalizado,
        'vencimientoPlazoFijo': vencimientoPlazoFijo?.toIso8601String(),
        'tasaAnualPct': tasaAnualPct,
        'notas': notas,
        'tipoInversion': TipoInversion.liquidez.name,
      };

  factory Liquidez.fromJson(Map<String, dynamic> json) {
    // Backward compat: formato antiguo tenía montoARS y montoUSD separados
    double monto;
    String moneda;
    if (json.containsKey('moneda')) {
      monto = (json['monto'] as num).toDouble();
      moneda = json['moneda'] as String;
    } else {
      final ars = (json['montoARS'] as num?)?.toDouble() ?? 0.0;
      final usd = (json['montoUSD'] as num?)?.toDouble() ?? 0.0;
      if (usd > 0) { monto = usd; moneda = 'USD'; }
      else { monto = ars; moneda = 'ARS'; }
    }

    return Liquidez(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      monto: monto,
      moneda: moneda,
      institucion: json['institucion'] as String,
      tipo: TipoLiquidez.values.firstWhere(
        (t) => t.name == json['tipo'],
        orElse: () => TipoLiquidez.cuentaCorriente,
      ),
      tipoPersonalizado: json['tipoPersonalizado'] as String?,
      vencimientoPlazoFijo: json['vencimientoPlazoFijo'] != null
          ? DateTime.tryParse(json['vencimientoPlazoFijo'] as String)
          : null,
      tasaAnualPct: (json['tasaAnualPct'] as num?)?.toDouble(),
      notas: json['notas'] as String?,
    );
  }
}

// ─── OtraInversion ──────────────────────────────────────────────────────────

class OtraInversion {
  final String id;
  final String nombre;
  final String descripcion;
  final double monto;
  final String moneda;
  final DateTime fechaAdquisicion;
  final String? notas;

  OtraInversion({
    String? id,
    required this.nombre,
    required this.descripcion,
    required this.monto,
    this.moneda = 'ARS',
    required this.fechaAdquisicion,
    this.notas,
  }) : id = id ?? const Uuid().v4();

  double get rentabilidadPct => 0.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'descripcion': descripcion,
        'monto': monto,
        'moneda': moneda,
        'fechaAdquisicion': fechaAdquisicion.toIso8601String(),
        'notas': notas,
        'tipo': TipoInversion.otra.name,
      };

  factory OtraInversion.fromJson(Map<String, dynamic> json) {
    double monto;
    String moneda;
    if (json.containsKey('moneda')) {
      monto = (json['monto'] as num).toDouble();
      moneda = json['moneda'] as String;
    } else {
      // Backward compat: formato antiguo usaba costoOriginalARS / valorEstimadoARS
      final valorEstimado = (json['valorEstimadoARS'] as num?)?.toDouble();
      final costoOriginal = (json['costoOriginalARS'] as num?)?.toDouble();
      monto = valorEstimado ?? costoOriginal ?? 0.0;
      moneda = 'ARS';
    }
    return OtraInversion(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String,
      monto: monto,
      moneda: moneda,
      fechaAdquisicion: DateTime.parse(json['fechaAdquisicion'] as String),
      notas: json['notas'] as String?,
    );
  }
}

// ─── NegocioPersonal ────────────────────────────────────────────────────────

class NegocioPersonal {
  final String id;
  final String nombre;
  final String descripcion;
  final double monto;
  final String moneda;
  final DateTime fechaAdquisicion;
  final String? sector;
  final String? notas;
  final double? montoDividendo;
  final String? monedaDividendo;
  final FrecuenciaDividendo? frecuenciaDividendo;
  final DateTime? fechaDividendo;

  NegocioPersonal({
    String? id,
    required this.nombre,
    required this.descripcion,
    required this.monto,
    this.moneda = 'ARS',
    required this.fechaAdquisicion,
    this.sector,
    this.notas,
    this.montoDividendo,
    this.monedaDividendo,
    this.frecuenciaDividendo,
    this.fechaDividendo,
  }) : id = id ?? const Uuid().v4();

  /// Moneda efectiva del dividendo (cae en la moneda del negocio si no se especifica).
  String get monedaDivEfectiva => monedaDividendo ?? moneda;

  /// Monto mensual equivalente del dividendo (null si no hay dividendos).
  double? get dividendoMensual {
    if (montoDividendo == null || frecuenciaDividendo == null) return null;
    return montoDividendo! / frecuenciaDividendo!.mesesPorPeriodo;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'descripcion': descripcion,
    'monto': monto,
    'moneda': moneda,
    'fechaAdquisicion': fechaAdquisicion.toIso8601String(),
    'sector': sector,
    'notas': notas,
    'montoDividendo': montoDividendo,
    'monedaDividendo': monedaDividendo,
    'frecuenciaDividendo': frecuenciaDividendo?.name,
    'fechaDividendo': fechaDividendo?.toIso8601String(),
    'tipo': TipoInversion.negocio.name,
  };

  factory NegocioPersonal.fromJson(Map<String, dynamic> json) {
    return NegocioPersonal(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String,
      monto: (json['monto'] as num).toDouble(),
      moneda: json['moneda'] as String? ?? 'ARS',
      fechaAdquisicion: DateTime.parse(json['fechaAdquisicion'] as String),
      sector: json['sector'] as String?,
      notas: json['notas'] as String?,
      montoDividendo: (json['montoDividendo'] as num?)?.toDouble(),
      monedaDividendo: json['monedaDividendo'] as String?,
      frecuenciaDividendo: json['frecuenciaDividendo'] != null
          ? FrecuenciaDividendo.values.firstWhere(
              (f) => f.name == json['frecuenciaDividendo'],
              orElse: () => FrecuenciaDividendo.mensual,
            )
          : null,
      fechaDividendo: json['fechaDividendo'] != null
          ? DateTime.tryParse(json['fechaDividendo'] as String)
          : null,
    );
  }
}

// ─── InstrumentoFinanciero ──────────────────────────────────────────────────

class InstrumentoFinanciero {
  final String id;
  final TipoInstrumento tipo;
  final double monto;
  final String moneda;
  final String entidad;
  final String entidadUrl;
  final DateTime fechaInicio;
  final TipoInteres tipoInteres;
  final double tasaAnualPct;
  final double duracion;
  final UnidadDuracion unidadDuracion;
  final String? descripcion;
  final String? notas;

  InstrumentoFinanciero({
    String? id,
    required this.tipo,
    required this.monto,
    this.moneda = 'ARS',
    required this.entidad,
    this.entidadUrl = '',
    required this.fechaInicio,
    this.tipoInteres = TipoInteres.simple,
    required this.tasaAnualPct,
    required this.duracion,
    this.unidadDuracion = UnidadDuracion.dias,
    this.descripcion,
    this.notas,
  }) : id = id ?? const Uuid().v4();

  double get tiempoEnAnios {
    switch (unidadDuracion) {
      case UnidadDuracion.dias:
        return duracion / 365.0;
      case UnidadDuracion.meses:
        return duracion / 12.0;
      case UnidadDuracion.anios:
        return duracion;
    }
  }

  DateTime get fechaFin {
    switch (unidadDuracion) {
      case UnidadDuracion.dias:
        return fechaInicio.add(Duration(days: duracion.round()));
      case UnidadDuracion.meses:
        final months = duracion.round();
        var year = fechaInicio.year + months ~/ 12;
        var month = fechaInicio.month + months % 12;
        if (month > 12) { month -= 12; year++; }
        return DateTime(year, month, fechaInicio.day);
      case UnidadDuracion.anios:
        return DateTime(
          fechaInicio.year + duracion.floor(),
          fechaInicio.month,
          fechaInicio.day,
        );
    }
  }

  double get montoTotal {
    final t = tiempoEnAnios;
    final r = tasaAnualPct / 100.0;
    if (tipoInteres == TipoInteres.compuesto) {
      return monto * pow(1 + r, t);
    } else {
      return monto * (1 + r * t);
    }
  }

  double get interesesGanados => montoTotal - monto;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo': tipo.name,
        'monto': monto,
        'moneda': moneda,
        'entidad': entidad,
        'entidadUrl': entidadUrl,
        'fechaInicio': fechaInicio.toIso8601String(),
        'tipoInteres': tipoInteres.name,
        'tasaAnualPct': tasaAnualPct,
        'duracion': duracion,
        'unidadDuracion': unidadDuracion.name,
        'descripcion': descripcion,
        'notas': notas,
        'tipoInversion': TipoInversion.instrumento.name,
      };

  factory InstrumentoFinanciero.fromJson(Map<String, dynamic> json) {
    return InstrumentoFinanciero(
      id: json['id'] as String,
      tipo: TipoInstrumento.values.firstWhere(
        (t) => t.name == json['tipo'],
        orElse: () => TipoInstrumento.otro,
      ),
      monto: (json['monto'] as num).toDouble(),
      moneda: json['moneda'] as String? ?? 'ARS',
      entidad: json['entidad'] as String,
      entidadUrl: json['entidadUrl'] as String? ?? '',
      fechaInicio: DateTime.parse(json['fechaInicio'] as String),
      tipoInteres: TipoInteres.values.firstWhere(
        (t) => t.name == json['tipoInteres'],
        orElse: () => TipoInteres.simple,
      ),
      tasaAnualPct: (json['tasaAnualPct'] as num).toDouble(),
      duracion: (json['duracion'] as num).toDouble(),
      unidadDuracion: UnidadDuracion.values.firstWhere(
        (u) => u.name == json['unidadDuracion'],
        orElse: () => UnidadDuracion.dias,
      ),
      descripcion: json['descripcion'] as String?,
      notas: json['notas'] as String?,
    );
  }
}

// ─── BienDeUso ──────────────────────────────────────────────────────────────

class BienDeUso {
  final String id;
  final String nombre;
  final TipoBienDeUso tipo;
  final String modelo;
  final int anio;
  final DateTime fechaCompra;
  final double precioCompra;
  final String moneda;
  final double? valorEstimadoActual;
  final String? notas;

  BienDeUso({
    String? id,
    required this.nombre,
    required this.tipo,
    required this.modelo,
    required this.anio,
    required this.fechaCompra,
    required this.precioCompra,
    this.moneda = 'USD',
    this.valorEstimadoActual,
    this.notas,
  }) : id = id ?? const Uuid().v4();

  double? get variacionMonto =>
      valorEstimadoActual != null ? valorEstimadoActual! - precioCompra : null;

  double? get variacionPct => (valorEstimadoActual != null && precioCompra > 0)
      ? (valorEstimadoActual! - precioCompra) / precioCompra * 100
      : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'tipo': tipo.name,
        'modelo': modelo,
        'anio': anio,
        'fechaCompra': fechaCompra.toIso8601String(),
        'precioCompra': precioCompra,
        'moneda': moneda,
        'valorEstimadoActual': valorEstimadoActual,
        'notas': notas,
        'tipoInversion': TipoInversion.bien.name,
      };

  factory BienDeUso.fromJson(Map<String, dynamic> json) {
    return BienDeUso(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      tipo: TipoBienDeUso.values.firstWhere(
        (t) => t.name == json['tipo'],
        orElse: () => TipoBienDeUso.otro,
      ),
      modelo: json['modelo'] as String? ?? '',
      anio: (json['anio'] as num?)?.toInt() ?? DateTime.now().year,
      fechaCompra: DateTime.parse(json['fechaCompra'] as String),
      precioCompra: (json['precioCompra'] as num).toDouble(),
      moneda: json['moneda'] as String? ?? 'USD',
      valorEstimadoActual: (json['valorEstimadoActual'] as num?)?.toDouble(),
      notas: json['notas'] as String?,
    );
  }

  BienDeUso copyWith({
    String? nombre,
    TipoBienDeUso? tipo,
    String? modelo,
    int? anio,
    DateTime? fechaCompra,
    double? precioCompra,
    String? moneda,
    double? valorEstimadoActual,
    String? notas,
  }) {
    return BienDeUso(
      id: id,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      modelo: modelo ?? this.modelo,
      anio: anio ?? this.anio,
      fechaCompra: fechaCompra ?? this.fechaCompra,
      precioCompra: precioCompra ?? this.precioCompra,
      moneda: moneda ?? this.moneda,
      valorEstimadoActual: valorEstimadoActual ?? this.valorEstimadoActual,
      notas: notas ?? this.notas,
    );
  }
}

// ─── InversionAlternativa ────────────────────────────────────────────────────

class InversionAlternativa {
  final String id;
  final TipoAlternativa tipo;
  final String nombre;
  /// Gramos para metales preciosos; unidades para el resto.
  final double cantidad;
  /// Precio total pagado al momento de la compra.
  final double precioCompra;
  final String moneda;
  final DateTime fechaCompra;
  /// Valor estimado manual (override). Si es null y es metal, se calcula del spot.
  final double? valorEstimadoManual;
  final String? notas;

  InversionAlternativa({
    String? id,
    required this.tipo,
    required this.nombre,
    required this.cantidad,
    required this.precioCompra,
    this.moneda = 'USD',
    required this.fechaCompra,
    this.valorEstimadoManual,
    this.notas,
  }) : id = id ?? const Uuid().v4();

  /// Valor calculado en USD usando precio spot.
  /// Retorna null si no es metal o no hay precio spot disponible.
  double? valorSpotUSD({double goldPerOz = 0, double silverPerOz = 0}) {
    if (tipo.esOro && goldPerOz > 0) {
      return cantidad * (goldPerOz / 31.1035) * tipo.pureza;
    }
    if (tipo.esPlata && silverPerOz > 0) {
      return cantidad * (silverPerOz / 31.1035);
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo': tipo.name,
        'nombre': nombre,
        'cantidad': cantidad,
        'precioCompra': precioCompra,
        'moneda': moneda,
        'fechaCompra': fechaCompra.toIso8601String(),
        'valorEstimadoManual': valorEstimadoManual,
        'notas': notas,
        'tipoInversion': TipoInversion.alternativa.name,
      };

  factory InversionAlternativa.fromJson(Map<String, dynamic> json) {
    return InversionAlternativa(
      id: json['id'] as String,
      tipo: TipoAlternativa.values.firstWhere(
        (t) => t.name == json['tipo'],
        orElse: () => TipoAlternativa.otro,
      ),
      nombre: json['nombre'] as String,
      cantidad: (json['cantidad'] as num).toDouble(),
      precioCompra: (json['precioCompra'] as num).toDouble(),
      moneda: json['moneda'] as String? ?? 'USD',
      fechaCompra: DateTime.parse(json['fechaCompra'] as String),
      valorEstimadoManual: (json['valorEstimadoManual'] as num?)?.toDouble(),
      notas: json['notas'] as String?,
    );
  }

  InversionAlternativa copyWith({
    TipoAlternativa? tipo,
    String? nombre,
    double? cantidad,
    double? precioCompra,
    String? moneda,
    DateTime? fechaCompra,
    double? valorEstimadoManual,
    bool clearValorEstimado = false,
    String? notas,
  }) {
    return InversionAlternativa(
      id: id,
      tipo: tipo ?? this.tipo,
      nombre: nombre ?? this.nombre,
      cantidad: cantidad ?? this.cantidad,
      precioCompra: precioCompra ?? this.precioCompra,
      moneda: moneda ?? this.moneda,
      fechaCompra: fechaCompra ?? this.fechaCompra,
      valorEstimadoManual: clearValorEstimado ? null : (valorEstimadoManual ?? this.valorEstimadoManual),
      notas: notas ?? this.notas,
    );
  }
}

// ─── OperacionLog ───────────────────────────────────────────────────────────

class OperacionLog {
  final String id;
  final TipoActivoOp tipoActivo;
  final String ticker;
  final TipoOperacion tipoOp;
  final double cantidad;
  final double precioUSD;
  final DateTime fecha;
  final String? exchange;

  OperacionLog({
    String? id,
    required this.tipoActivo,
    required this.ticker,
    required this.tipoOp,
    required this.cantidad,
    required this.precioUSD,
    required this.fecha,
    this.exchange,
  }) : id = id ?? const Uuid().v4();

  double get montoTotal => cantidad * precioUSD;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo': 'operacion',
        'tipoActivo': tipoActivo.name,
        'ticker': ticker,
        'tipoOp': tipoOp.name,
        'cantidad': cantidad,
        'precioUSD': precioUSD,
        'fecha': fecha.toIso8601String(),
        'exchange': exchange,
      };

  factory OperacionLog.fromJson(Map<String, dynamic> json) {
    return OperacionLog(
      id: json['id'] as String,
      tipoActivo: TipoActivoOp.values.firstWhere(
        (t) => t.name == json['tipoActivo'],
        orElse: () => TipoActivoOp.accion,
      ),
      ticker: json['ticker'] as String,
      tipoOp: TipoOperacion.values.firstWhere(
        (t) => t.name == json['tipoOp'],
        orElse: () => TipoOperacion.compra,
      ),
      cantidad: (json['cantidad'] as num).toDouble(),
      precioUSD: (json['precioUSD'] as num).toDouble(),
      fecha: DateTime.parse(json['fecha'] as String),
      exchange: json['exchange'] as String?,
    );
  }
}
