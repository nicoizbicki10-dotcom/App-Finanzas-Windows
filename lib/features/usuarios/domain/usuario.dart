import 'package:uuid/uuid.dart';

class UsuarioPerfil {
  final String id;
  final String nombre;
  final int colorValue;
  final DateTime creadoEn;
  final String? pin; // null = sin PIN; almacenado como texto simple (4 dígitos)
  final String? fotoUrl;

  UsuarioPerfil({
    String? id,
    required this.nombre,
    required this.colorValue,
    DateTime? creadoEn,
    this.pin,
    this.fotoUrl,
  })  : id = id ?? const Uuid().v4(),
        creadoEn = creadoEn ?? DateTime.now();

  UsuarioPerfil copyWith({
    String? nombre,
    int? colorValue,
    String? pin,
    bool clearPin = false,
    String? fotoUrl,
    bool clearFoto = false,
  }) {
    return UsuarioPerfil(
      id: id,
      nombre: nombre ?? this.nombre,
      colorValue: colorValue ?? this.colorValue,
      creadoEn: creadoEn,
      pin: clearPin ? null : (pin ?? this.pin),
      fotoUrl: clearFoto ? null : (fotoUrl ?? this.fotoUrl),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'colorValue': colorValue,
        'creadoEn': creadoEn.toIso8601String(),
        'pin': pin,
        'fotoUrl': fotoUrl,
      };

  factory UsuarioPerfil.fromJson(Map<String, dynamic> json) {
    return UsuarioPerfil(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      colorValue: json['colorValue'] as int,
      creadoEn: DateTime.parse(json['creadoEn'] as String),
      pin: json['pin'] as String?,
      fotoUrl: json['fotoUrl'] as String?,
    );
  }
}
