import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Moneda seleccionada para mostrar montos en toda la app. Default: 'USD'.
final displayCurrencyProvider = StateProvider<String>((ref) => 'USD');
