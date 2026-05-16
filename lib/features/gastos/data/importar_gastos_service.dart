import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../domain/gasto.dart';

const _kSystemPrompt = '''Sos un asistente especializado en analizar resúmenes de tarjetas de crédito y extractos bancarios argentinos.

Tu tarea es extraer TODAS las transacciones/gastos del texto o imagen y clasificarlos.

Para cada transacción devolvé un objeto JSON con este formato exacto:
{
  "descripcion": "nombre del comercio o descripción del gasto",
  "monto": 1234.56,
  "esUSD": false,
  "categoria": "alimentacion",
  "subcategoria": "Supermercado",
  "tipo": "variable",
  "fecha": "2024-01-15",
  "notas": ""
}

CATEGORÍAS VÁLIDAS (usá exactamente estos valores):
- vivienda → subcategorías: Alquiler, Expensas, Hipoteca, Mantenimiento, Seguro del hogar
- alimentacion → subcategorías: Supermercado, Restaurante/Bar, Delivery, Verdulería/Feria
- transporte → subcategorías: Combustible, Estacionamiento, Peajes, Seguro del auto, Patente, Repuestos, SUBE
- salud → subcategorías: Prepaga/Obra Social, Farmacia, Consulta médica, Gimnasio
- educacion → subcategorías: Cuota colegio, Universidad, Cursos, Libros/Material
- entretenimiento → subcategorías: Cine/Teatro, Viajes, Juegos, Suscripciones
- servicios → subcategorías: Luz, Gas, Internet, Agua, Teléfono, Streaming, Seguro
- ropa → subcategorías: Ropa, Calzado, Accesorios
- mascotas → subcategorías: Veterinaria, Alimento, Accesorios
- otros → para todo lo que no encaje en las anteriores

TIPO DE GASTO:
- "fijo": alquiler, expensas, servicios (luz, gas, internet, agua), prepaga/obra social, gimnasio, suscripciones mensuales sin cuotas
- "variable": supermercado, restaurantes, delivery, farmacia puntual, combustible, ropa, entretenimiento, salidas, y SIEMPRE las compras en cuotas

CUOTAS (MUY IMPORTANTE):
- Si la descripción contiene un patrón "NN/NN" (ej: "1/3", "02/12", "K 3/6"), es una compra en cuotas → tipo SIEMPRE "variable"
- Incluí el número de cuota en la descripción. Ejemplo: "APPLE SERVICES 2/6" → descripcion: "Apple Services (cuota 2/6)"
- Cada cuota es un gasto separado, aunque el comercio sea el mismo que otro mes

REGLAS:
- El campo "monto" debe ser un número positivo (sin signo negativo)
- Si la moneda es USD o dólares, ponés "esUSD": true
- Si no hay fecha clara, usá la fecha de hoy en formato ISO (YYYY-MM-DD)
- La "subcategoria" es opcional; si no está clara, omitila (null)
- Ignorá pagos mínimos, totales del resumen, saldos anteriores, ajustes por tipo de cambio

Devolvé ÚNICAMENTE un array JSON válido (sin bloques markdown, sin texto adicional). Si no hay transacciones, devolvé [].''';

class ImportarGastosService {
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120),
    headers: {'Content-Type': 'application/json'},
  ));

  static const _urlGroq = 'https://api.groq.com/openai/v1/chat/completions';
  static const _modeloTexto = 'llama-3.3-70b-versatile';
  static const _modeloVision = 'meta-llama/llama-4-scout-17b-16e-instruct';

  Future<List<GastoParseado>> analizarTexto({
    required String apiKey,
    required String texto,
  }) async {
    final response = await _dio.post(
      _urlGroq,
      options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
      data: {
        'model': _modeloTexto,
        'messages': [
          {'role': 'system', 'content': _kSystemPrompt},
          {'role': 'user', 'content': texto},
        ],
        'max_tokens': 4096,
        'temperature': 0.1,
      },
    );
    final content = (response.data['choices'] as List).first['message']['content'] as String;
    return _parsearRespuesta(content);
  }

  Future<List<GastoParseado>> analizarImagen({
    required String apiKey,
    required XFile imagen,
  }) async {
    final bytes = await imagen.readAsBytes();
    final base64Image = base64Encode(bytes);
    final mediaType = _mediaType(imagen.name);

    final response = await _dio.post(
      _urlGroq,
      options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
      data: {
        'model': _modeloVision,
        'messages': [
          {'role': 'system', 'content': _kSystemPrompt},
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {'url': 'data:$mediaType;base64,$base64Image'},
              },
              {
                'type': 'text',
                'text': 'Extraé todas las transacciones de compras/consumos de esta imagen. Ignorá totales, saldos y ajustes.',
              },
            ],
          },
        ],
        'max_tokens': 4096,
        'temperature': 0.1,
      },
    );
    final content = (response.data['choices'] as List).first['message']['content'] as String;
    return _parsearRespuesta(content);
  }

  Future<List<GastoParseado>> analizarPdf({
    required String apiKey,
    required String pdfPath,
  }) async {
    final bytes = await File(pdfPath).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final texto = extractor.extractText();
    document.dispose();

    if (texto.trim().isEmpty) {
      throw Exception(
          'No se pudo extraer texto del PDF. Puede ser un PDF escaneado (imagen). '
          'Intentá sacar una captura de pantalla y usá la pestaña Imagen.');
    }

    return analizarTexto(apiKey: apiKey, texto: texto);
  }

  List<GastoParseado> _parsearRespuesta(String raw) {
    var texto = raw.trim();
    if (texto.startsWith('```')) {
      texto = texto
          .replaceFirst(RegExp(r'^```[a-z]*\n?'), '')
          .replaceFirst(RegExp(r'\n?```$'), '')
          .trim();
    }

    final List<dynamic> lista = jsonDecode(texto) as List<dynamic>;
    final hoy = DateTime.now();

    return lista.map((item) {
      final m = item as Map<String, dynamic>;

      DateTime fecha;
      try {
        fecha = DateTime.parse(m['fecha'] as String? ?? '');
      } catch (_) {
        fecha = DateTime(hoy.year, hoy.month, hoy.day);
      }

      final categoriaStr = (m['categoria'] as String? ?? 'otros').toLowerCase();
      final categoria = CategoriaGasto.values.firstWhere(
        (c) => c.name == categoriaStr,
        orElse: () => CategoriaGasto.otros,
      );

      final tipoStr = (m['tipo'] as String? ?? 'variable').toLowerCase();
      final tipo = tipoStr == 'fijo' ? TipoGasto.fijo : TipoGasto.variable;

      return GastoParseado(
        descripcion: m['descripcion'] as String? ?? 'Sin descripción',
        monto: (m['monto'] as num).toDouble().abs(),
        esUSD: m['esUSD'] as bool? ?? false,
        categoria: categoria,
        subcategoria: m['subcategoria'] as String?,
        tipo: tipo,
        fecha: fecha,
        notas: m['notas'] as String?,
      );
    }).toList();
  }

  String _mediaType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }
}

class GastoParseado {
  String descripcion;
  double monto;
  bool esUSD;
  CategoriaGasto categoria;
  String? subcategoria;
  TipoGasto tipo;
  DateTime fecha;
  String? notas;
  String? medioPagoId;

  GastoParseado({
    required this.descripcion,
    required this.monto,
    this.esUSD = false,
    required this.categoria,
    this.subcategoria,
    required this.tipo,
    required this.fecha,
    this.notas,
    this.medioPagoId,
  });

  Gasto toGasto() => Gasto(
        descripcion: descripcion,
        monto: monto,
        esUSD: esUSD,
        categoria: categoria,
        subcategoria: subcategoria,
        tipo: tipo,
        fecha: fecha,
        notas: notas,
        medioPagoId: medioPagoId,
      );
}
