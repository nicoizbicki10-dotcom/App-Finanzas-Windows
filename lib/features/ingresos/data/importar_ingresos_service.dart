import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../domain/ingreso.dart';

const _kSystemPrompt =
    '''Sos un asistente especializado en analizar recibos de sueldo, extractos bancarios y comprobantes de pago argentinos.

Tu tarea es extraer TODOS los ingresos del texto o imagen y clasificarlos.

Para cada ingreso devolvé un objeto JSON con este formato exacto:
{
  "descripcion": "nombre o descripción del ingreso",
  "monto": 1234.56,
  "esUSD": false,
  "tipo": "fijo",
  "fecha": "2024-01-15",
  "notas": ""
}

TIPO DE INGRESO:
- "fijo": sueldo/salario mensual, alquiler cobrado regularmente, pensión, jubilación, cuota societaria fija
- "variable": freelance puntual, venta, bono, aguinaldo, dividendo, comisión, ingreso extra, honorario puntual

REGLAS:
- El campo "monto" debe ser un número positivo
- Si la moneda es USD o dólares, ponés "esUSD": true
- Si no hay fecha clara, usá la fecha de hoy en formato ISO (YYYY-MM-DD)
- Ignorá retenciones, descuentos y deducciones — solo incluí ingresos netos o brutos claramente indicados
- No incluyas transferencias entre propias cuentas

Devolvé ÚNICAMENTE un array JSON válido (sin bloques markdown, sin texto adicional). Si no hay ingresos, devolvé [].''';

class ImportarIngresosService {
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120),
    headers: {'Content-Type': 'application/json'},
  ));

  static const _urlGroq = 'https://api.groq.com/openai/v1/chat/completions';
  static const _modeloTexto = 'llama-3.3-70b-versatile';
  static const _modeloVision = 'meta-llama/llama-4-scout-17b-16e-instruct';

  Future<List<IngresoParseado>> analizarTexto({
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
    final content =
        (response.data['choices'] as List).first['message']['content'] as String;
    return _parsearRespuesta(content);
  }

  Future<List<IngresoParseado>> analizarImagen({
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
                'text':
                    'Extraé todos los ingresos de esta imagen. Ignorá retenciones y descuentos.',
              },
            ],
          },
        ],
        'max_tokens': 4096,
        'temperature': 0.1,
      },
    );
    final content =
        (response.data['choices'] as List).first['message']['content'] as String;
    return _parsearRespuesta(content);
  }

  Future<List<IngresoParseado>> analizarPdf({
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
          'No se pudo extraer texto del PDF. Puede ser un PDF escaneado. '
          'Intentá sacar una captura de pantalla y usá la pestaña Imagen.');
    }

    return analizarTexto(apiKey: apiKey, texto: texto);
  }

  List<IngresoParseado> _parsearRespuesta(String raw) {
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

      final tipoStr = (m['tipo'] as String? ?? 'variable').toLowerCase();
      final tipo = tipoStr == 'fijo' ? TipoIngreso.fijo : TipoIngreso.variable;

      return IngresoParseado(
        descripcion: m['descripcion'] as String? ?? 'Sin descripción',
        monto: (m['monto'] as num).toDouble().abs(),
        esUSD: m['esUSD'] as bool? ?? false,
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

class IngresoParseado {
  String descripcion;
  double monto;
  bool esUSD;
  TipoIngreso tipo;
  DateTime fecha;
  String? notas;
  String? medioPagoId;

  IngresoParseado({
    required this.descripcion,
    required this.monto,
    this.esUSD = false,
    required this.tipo,
    required this.fecha,
    this.notas,
    this.medioPagoId,
  });

  Ingreso toIngreso() => Ingreso(
        descripcion: descripcion,
        monto: monto,
        esUSD: esUSD,
        categoria: CategoriaIngreso.otro,
        tipo: tipo,
        fecha: fecha,
        notas: notas,
        liquidezDestinoId: medioPagoId,
      );
}
