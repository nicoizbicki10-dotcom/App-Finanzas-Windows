import 'package:flutter/material.dart';

abstract class AppColors {
  // Fondos
  static const Color background = Color(0xFF0D0D0D);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceElevated = Color(0xFF16213E);
  static const Color surfaceBorder = Color(0xFF2A2A4A);

  // Acentos principales
  static const Color primary = Color(0xFF00D4FF);
  static const Color secondary = Color(0xFF7B2FBE);

  // Semánticos
  static const Color success = Color(0xFF00C896);
  static const Color danger = Color(0xFFFF4757);
  static const Color warning = Color(0xFFFFA502);
  static const Color info = Color(0xFF3742FA);

  // Texto
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8892B0);
  static const Color textDisabled = Color(0xFF4A4A6A);

  // Paleta de gráficos (6 colores accesibles)
  static const List<Color> chartPalette = [
    Color(0xFF00D4FF), // Cyan — Acciones
    Color(0xFF7B2FBE), // Violeta — Inmuebles
    Color(0xFF00C896), // Verde — Cripto
    Color(0xFFFFA502), // Ámbar — Liquidez
    Color(0xFFFF6B81), // Rosa — Otras
    Color(0xFF3742FA), // Azul real — Reservado
  ];

  // Gradientes
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00D4FF), Color(0xFF7B2FBE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00C896), Color(0xFF00D4FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFFF4757), Color(0xFFFFA502)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
