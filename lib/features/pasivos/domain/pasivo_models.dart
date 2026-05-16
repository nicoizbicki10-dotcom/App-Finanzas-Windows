import 'dart:math';

import 'package:uuid/uuid.dart';

import '../../inversiones/domain/inversion_models.dart';

// Re-export for convenience
export '../../inversiones/domain/inversion_models.dart' show TipoInteres, UnidadDuracion;

enum TipoPasivo {
  particular('Particular', '👤', 'Particulares'),
  bancario('Bancario', '🏦', 'Bancarias'),
  financiero('Financiero', '📊', 'Financieras'),
  otro('Otro', '📌', 'Otras');

  const TipoPasivo(this.label, this.emoji, this.labelPlural);
  final String label;
  final String emoji;
  final String labelPlural;
}

/// Método de cálculo de intereses / amortización aplicado al pasivo.
enum MetodoPasivo {
  ninguno('Ninguno', '—'),
  simple('Simple', '📊'),
  compuesto('Compuesto', '📈'),
  frances('Francés', '🇫🇷'),
  aleman('Alemán', '🇩🇪'),
  americano('Americano', '🇺🇸');

  const MetodoPasivo(this.label, this.emoji);
  final String label;
  final String emoji;
}

class Pasivo {
  final String id;
  final String concepto;
  final TipoPasivo tipo;
  final double monto;
  final String moneda;
  final DateTime fechaEndeudamiento;
  final double tasaInteresPct;
  final MetodoPasivo metodo;
  final double duracion;
  final UnidadDuracion unidadDuracion;
  final String? notas;

  Pasivo({
    String? id,
    required this.concepto,
    required this.tipo,
    required this.monto,
    this.moneda = 'ARS',
    required this.fechaEndeudamiento,
    this.tasaInteresPct = 0.0,
    this.metodo = MetodoPasivo.ninguno,
    required this.duracion,
    this.unidadDuracion = UnidadDuracion.meses,
    this.notas,
  }) : id = id ?? const Uuid().v4();

  // Backward compat: expone tipoInteres para código que lo use
  TipoInteres get tipoInteres => metodo == MetodoPasivo.compuesto
      ? TipoInteres.compuesto
      : TipoInteres.simple;

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

  /// Número de períodos mensuales (para cálculos de amortización).
  int get periodosMensuales {
    switch (unidadDuracion) {
      case UnidadDuracion.dias:
        return (duracion / 30).round().clamp(1, 9999);
      case UnidadDuracion.meses:
        return duracion.round().clamp(1, 9999);
      case UnidadDuracion.anios:
        return (duracion * 12).round().clamp(1, 9999);
    }
  }

  DateTime get fechaVencimiento {
    switch (unidadDuracion) {
      case UnidadDuracion.dias:
        return fechaEndeudamiento.add(Duration(days: duracion.round()));
      case UnidadDuracion.meses:
        final months = duracion.round();
        var year = fechaEndeudamiento.year + months ~/ 12;
        var month = fechaEndeudamiento.month + months % 12;
        if (month > 12) { month -= 12; year++; }
        return DateTime(year, month, fechaEndeudamiento.day);
      case UnidadDuracion.anios:
        return DateTime(
          fechaEndeudamiento.year + duracion.floor(),
          fechaEndeudamiento.month,
          fechaEndeudamiento.day,
        );
    }
  }

  double get montoTotal {
    final r = tasaInteresPct / 100.0;
    if (r <= 0) return monto;

    switch (metodo) {
      case MetodoPasivo.ninguno:
        return monto;

      case MetodoPasivo.simple:
        return monto * (1 + r * tiempoEnAnios);

      case MetodoPasivo.compuesto:
        return monto * pow(1 + r, tiempoEnAnios);

      case MetodoPasivo.frances:
        // Cuota fija: PMT = P * (rM * (1+rM)^n) / ((1+rM)^n - 1)
        final n = periodosMensuales;
        final rM = r / 12;
        if (rM == 0) return monto;
        final factor = pow(1 + rM, n);
        final pmt = monto * (rM * factor) / (factor - 1);
        return pmt * n;

      case MetodoPasivo.aleman:
        // Amortización constante: intereses decrecientes
        // Total intereses = P * rM * (n+1) / 2
        final n = periodosMensuales;
        final rM = r / 12;
        return monto + monto * rM * (n + 1) / 2;

      case MetodoPasivo.americano:
        // Bullet: solo intereses cada período, capital al final
        final n = periodosMensuales;
        final rM = r / 12;
        return monto + monto * rM * n;
    }
  }

  double get intereses => montoTotal - monto;

  /// Cuota mensual (solo relevante para francés, alemán, americano).
  /// Para alemán y americano devuelve la cuota del primer período.
  double? get cuotaMensual {
    final r = tasaInteresPct / 100.0;
    final n = periodosMensuales;
    final rM = r / 12;
    switch (metodo) {
      case MetodoPasivo.frances:
        if (n == 0) return null;
        if (rM == 0) return monto / n;
        final factor = pow(1 + rM, n);
        return monto * (rM * factor) / (factor - 1);
      case MetodoPasivo.aleman:
        if (n == 0) return null;
        // Primera cuota (la más alta) = P/n + P*rM
        return monto / n + monto * rM;
      case MetodoPasivo.americano:
        // Cuota periódica = solo interés; última cuota incluye capital
        return monto * rM;
      case MetodoPasivo.ninguno:
      case MetodoPasivo.simple:
      case MetodoPasivo.compuesto:
        return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'concepto': concepto,
        'tipo': tipo.name,
        'monto': monto,
        'moneda': moneda,
        'fechaEndeudamiento': fechaEndeudamiento.toIso8601String(),
        'tasaInteresPct': tasaInteresPct,
        'metodo': metodo.name,
        'duracion': duracion,
        'unidadDuracion': unidadDuracion.name,
        'notas': notas,
        'category': 'pasivo',
      };

  factory Pasivo.fromJson(Map<String, dynamic> json) {
    // Backward compat: versiones antiguas guardaban 'tipoInteres' en vez de 'metodo'
    MetodoPasivo metodo;
    if (json.containsKey('metodo')) {
      metodo = MetodoPasivo.values.firstWhere(
        (m) => m.name == json['metodo'],
        orElse: () => MetodoPasivo.ninguno,
      );
    } else {
      final ti = json['tipoInteres'] as String? ?? 'simple';
      metodo = ti == 'compuesto' ? MetodoPasivo.compuesto : MetodoPasivo.simple;
    }

    return Pasivo(
      id: json['id'] as String,
      concepto: json['concepto'] as String,
      tipo: TipoPasivo.values.firstWhere(
        (t) => t.name == json['tipo'],
        orElse: () => TipoPasivo.otro,
      ),
      monto: (json['monto'] as num).toDouble(),
      moneda: json['moneda'] as String? ?? 'ARS',
      fechaEndeudamiento: DateTime.parse(json['fechaEndeudamiento'] as String),
      tasaInteresPct: (json['tasaInteresPct'] as num?)?.toDouble() ?? 0.0,
      metodo: metodo,
      duracion: (json['duracion'] as num).toDouble(),
      unidadDuracion: UnidadDuracion.values.firstWhere(
        (u) => u.name == json['unidadDuracion'],
        orElse: () => UnidadDuracion.meses,
      ),
      notas: json['notas'] as String?,
    );
  }
}
