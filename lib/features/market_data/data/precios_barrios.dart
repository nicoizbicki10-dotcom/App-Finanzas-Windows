/// Precios de referencia por m² en USD por barrio/localidad.
/// Fuente: Mudafy / Roomix — datos de mercado Q1 2026.
abstract class PreciosBarrios {
  static const String ultimaActualizacion = 'Q1 2026';
  static const String periodoAnterior = 'Q1 2025';

  // Normaliza el texto para matching flexible
  static String _normalizar(String s) {
    const from = 'áéíóúàèìòùäëïöüñÁÉÍÓÚÀÈÌÒÙÄËÏÖÜÑ';
    const to   = 'aeiouaeiouaeiounAEIOUAEIOUAEIOUN';
    var result = s.toLowerCase().trim();
    for (var i = 0; i < from.length; i++) {
      result = result.replaceAll(from[i], to[i]);
    }
    return result;
  }

  // Precios Q1 2025 (período anterior) para calcular variación interanual
  static const Map<String, double> _tablaAnterior = {
    'puerto madero': 5200,
    'recoleta': 2800,
    'palermo': 2750,
    'palermo soho': 2900,
    'palermo hollywood': 2800,
    'belgrano': 2600,
    'belgrano r': 2800,
    'nuñez': 2500,
    'nunez': 2500,
    'colegiales': 2400,
    'san isidro': 3000,
    'martinez': 3100,
    'olivos': 2900,
    'vicente lopez': 2800,
    'villa crespo': 2200,
    'chacarita': 2100,
    'caballito': 2050,
    'villa urquiza': 2000,
    'villa del parque': 1850,
    'almagro': 1950,
    'san telmo': 2100,
    'montserrat': 1900,
    'balvanera': 1750,
    'boedo': 1800,
    'parque centenario': 1950,
    'parque chacabuco': 1850,
    'paternal': 1800,
    'villa ortuzar': 1900,
    'devoto': 1900,
    'agronomia': 1750,
    'flores': 1650,
    'floresta': 1550,
    'barracas': 1700,
    'parque patricios': 1600,
    'nueva pompeya': 1400,
    'villa lugano': 1200,
    'villa soldati': 1150,
    'mataderos': 1300,
    'tigre': 1800,
    'san fernando': 1900,
    'nordelta': 3200,
    'pilar': 1700,
    'escobar': 1500,
    'moron': 1400,
    'haedo': 1350,
    'ramos mejia': 1500,
    'san justo': 1300,
    'la tablada': 1200,
    'lomas de zamora': 1300,
    'quilmes': 1250,
    'avellaneda': 1400,
    'lanus': 1300,
    'bernal': 1350,
    'rosario': 1450,
    'rosario centro': 1500,
    'cordoba': 1350,
    'cordoba centro': 1400,
    'nueva cordoba': 1600,
    'mendoza': 1250,
    'mendoza centro': 1300,
    'mar del plata': 1550,
    'bariloche': 2300,
    'salta': 1150,
    'salta centro': 1200,
    'tucuman': 1050,
    'san miguel de tucuman': 1050,
    'santa fe': 1150,
    'santa fe centro': 1200,
    'neuquen': 1300,
    'bahia blanca': 1100,
    'la plata': 1350,
    'la plata centro': 1400,
  };

  // Precios Q1 2026 — Fuente: Mudafy / Roomix
  static const Map<String, double> _tabla = {
    // ── CABA premium ──────────────────────────────────────────────────────────
    'puerto madero': 5800,
    'recoleta': 3100,
    'palermo': 3050,
    'palermo soho': 3200,
    'palermo hollywood': 3100,
    'belgrano': 2900,
    'belgrano r': 3100,
    'nuñez': 2750,
    'nunez': 2750,
    'colegiales': 2650,
    'san isidro': 3300,
    'martinez': 3450,
    'olivos': 3200,
    'vicente lopez': 3100,

    // ── CABA intermedio ───────────────────────────────────────────────────────
    'villa crespo': 2450,
    'chacarita': 2300,
    'caballito': 2280,
    'villa urquiza': 2200,
    'villa del parque': 2050,
    'almagro': 2150,
    'san telmo': 2350,
    'montserrat': 2100,
    'balvanera': 1950,
    'boedo': 2000,
    'parque centenario': 2150,
    'parque chacabuco': 2050,
    'paternal': 2000,
    'villa ortuzar': 2100,
    'devoto': 2100,
    'agronomia': 1950,
    'constitucion': 1850,
    'once': 1850,
    'liniers': 1700,
    'villa pueyrredon': 2050,
    'saavedra': 2300,

    // ── CABA popular ─────────────────────────────────────────────────────────
    'flores': 1820,
    'floresta': 1720,
    'barracas': 1880,
    'parque patricios': 1760,
    'nueva pompeya': 1550,
    'villa lugano': 1320,
    'villa soldati': 1270,
    'mataderos': 1440,

    // ── GBA Norte ─────────────────────────────────────────────────────────────
    'tigre': 2000,
    'san fernando': 2100,
    'nordelta': 3600,
    'pilar': 1900,
    'escobar': 1650,
    'san isidro centro': 3200,
    'acassuso': 3000,
    'beccar': 2800,
    'la lucila': 2700,
    'munro': 1900,
    'florida': 2000,

    // ── GBA Oeste ─────────────────────────────────────────────────────────────
    'moron': 1560,
    'haedo': 1500,
    'ramos mejia': 1660,
    'san justo': 1440,
    'la tablada': 1330,
    'ituzaingo': 1500,
    'merlo': 1200,

    // ── GBA Sur ───────────────────────────────────────────────────────────────
    'lomas de zamora': 1440,
    'quilmes': 1380,
    'avellaneda': 1560,
    'lanus': 1440,
    'bernal': 1500,
    'adrogué': 1550,
    'monte grande': 1350,
    'temperley': 1420,

    // ── Interior ─────────────────────────────────────────────────────────────
    'rosario': 1600,
    'rosario centro': 1680,
    'cordoba': 1500,
    'cordoba centro': 1580,
    'nueva cordoba': 1780,
    'mendoza': 1380,
    'mendoza centro': 1450,
    'mar del plata': 1720,
    'bariloche': 2550,
    'salta': 1280,
    'salta centro': 1340,
    'tucuman': 1160,
    'san miguel de tucuman': 1160,
    'santa fe': 1280,
    'santa fe centro': 1340,
    'neuquen': 1450,
    'bahia blanca': 1220,
    'la plata': 1500,
    'la plata centro': 1560,
    'san luis': 1100,
    'resistencia': 980,
    'posadas': 1050,
    'corrientes': 1020,
  };

  static double? _buscarEnTabla(Map<String, double> tabla, String key) {
    if (tabla.containsKey(key)) return tabla[key];
    for (final entry in tabla.entries) {
      if (entry.key.contains(key) || key.contains(entry.key)) return entry.value;
    }
    return null;
  }

  /// Retorna la variación interanual del precio/m² en porcentaje,
  /// comparando Q1 2025 vs Q1 2024. Retorna null si no hay datos de ambos períodos.
  static double? getVariacionAnualPct(String barrio) {
    final key = _normalizar(barrio);
    final actual = _buscarEnTabla(_tabla, key);
    final anterior = _buscarEnTabla(_tablaAnterior, key);
    if (actual == null || anterior == null || anterior == 0) return null;
    return (actual - anterior) / anterior * 100;
  }

  /// Retorna el precio estimado por m² en USD para el barrio dado,
  /// o null si no hay datos disponibles.
  static double? getPrecioM2(String barrio) {
    return _buscarEnTabla(_tabla, _normalizar(barrio));
  }
}
