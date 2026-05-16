import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/storage/storage_keys.dart';
import 'features/usuarios/data/usuarios_repository.dart';
import 'features/usuarios/domain/usuario.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_AR', null);

  final appDocDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocDir.path);

  await Future.wait([
    Hive.openBox<Map>(StorageKeys.gastosBox),
    Hive.openBox<Map>(StorageKeys.ingresosBox),
    Hive.openBox<Map>(StorageKeys.inversionesBox),
    Hive.openBox<Map>(StorageKeys.objetivosBox),
    Hive.openBox<Map>(StorageKeys.cacheBox),
    Hive.openBox<Map>(StorageKeys.pasivosBox),
  ]);

  // Si no hay usuarios creados, crear el usuario 'default' para backward compat
  final usuariosRepo = UsuariosRepository();
  if (!usuariosRepo.hasUsers) {
    await usuariosRepo.save(UsuarioPerfil(
      id: 'default',
      nombre: 'Mi cuenta',
      colorValue: 0xFF2196F3,
    ));
    await usuariosRepo.setCurrentId('default');
  }

  runApp(
    const ProviderScope(
      child: FinanzasApp(),
    ),
  );
}
