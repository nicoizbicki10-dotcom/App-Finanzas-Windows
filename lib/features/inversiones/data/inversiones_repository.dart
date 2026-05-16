import 'package:hive/hive.dart';

import '../../../core/storage/storage_keys.dart';
import '../domain/inversion_models.dart';

class InversionesRepository {
  final String userId;
  InversionesRepository({required this.userId});

  Box<Map> get _box => Hive.box<Map>(StorageKeys.inversionesBox);

  String _key(String id, TipoInversion tipo) => '${tipo.name}_$id';

  bool _esDelUsuario(Map e) =>
      (e['_uid'] as String? ?? 'default') == userId;

  // ─── Inmuebles ──────────────────────────────────────────────────────────

  List<Inmueble> getInmuebles() {
    return _box.values
        .where((e) => e['tipo'] == TipoInversion.inmueble.name && _esDelUsuario(e))
        .map((e) => Inmueble.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveInmueble(Inmueble inmueble) async {
    final json = inmueble.toJson();
    json['_uid'] = userId;
    await _box.put(_key(inmueble.id, TipoInversion.inmueble), json);
  }

  Future<void> deleteInmueble(String id) async {
    await _box.delete(_key(id, TipoInversion.inmueble));
  }

  // ─── Acciones ───────────────────────────────────────────────────────────

  List<Accion> getAcciones() {
    return _box.values
        .where((e) => e['tipo'] == TipoInversion.accion.name && _esDelUsuario(e))
        .map((e) => Accion.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveAccion(Accion accion) async {
    final json = accion.toJson();
    json['_uid'] = userId;
    await _box.put(_key(accion.id, TipoInversion.accion), json);
  }

  Future<void> deleteAccion(String id) async {
    await _box.delete(_key(id, TipoInversion.accion));
  }

  /// Resta [delta] de la cantidad de la primera acción con ese ticker.
  /// Si la cantidad resultante es ≤ 0 elimina la entrada; si no, borra y
  /// re-inserta con nuevo ID para garantizar consistencia en Hive.
  Future<void> ajustarCantidadAccion(String ticker, double delta) async {
    final accion = getAcciones().where((a) => a.ticker == ticker).firstOrNull;
    if (accion == null) return;
    await deleteAccion(accion.id);
    final nuevaCantidad = accion.cantidad + delta;
    if (nuevaCantidad > 0) {
      await saveAccion(Accion(
        ticker: accion.ticker,
        nombre: accion.nombre,
        cantidad: nuevaCantidad,
        precioCompraUSD: accion.precioCompraUSD,
        fechaAdquisicion: accion.fechaAdquisicion,
        exchange: accion.exchange,
        notas: accion.notas,
      ));
    }
  }

  // ─── Crypto ─────────────────────────────────────────────────────────────

  List<CryptoHolding> getCryptos() {
    return _box.values
        .where((e) => e['tipo'] == TipoInversion.crypto.name && _esDelUsuario(e))
        .map((e) => CryptoHolding.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveCrypto(CryptoHolding crypto) async {
    final json = crypto.toJson();
    json['_uid'] = userId;
    await _box.put(_key(crypto.id, TipoInversion.crypto), json);
  }

  Future<void> deleteCrypto(String id) async {
    await _box.delete(_key(id, TipoInversion.crypto));
  }

  /// Resta [delta] de la cantidad del primer holding con ese symbol.
  /// Si la cantidad resultante es ≤ 0 elimina; si no, borra y re-inserta.
  Future<void> ajustarCantidadCrypto(String symbol, double delta) async {
    final crypto = getCryptos().where((c) => c.symbol == symbol).firstOrNull;
    if (crypto == null) return;
    await deleteCrypto(crypto.id);
    final nuevaCantidad = crypto.cantidad + delta;
    if (nuevaCantidad > 0) {
      await saveCrypto(CryptoHolding(
        coingeckoId: crypto.coingeckoId,
        symbol: crypto.symbol,
        nombre: crypto.nombre,
        cantidad: nuevaCantidad,
        precioCompraUSD: crypto.precioCompraUSD,
        fechaAdquisicion: crypto.fechaAdquisicion,
        wallet: crypto.wallet,
        notas: crypto.notas,
      ));
    }
  }

  // ─── Liquidez ───────────────────────────────────────────────────────────

  List<Liquidez> getLiquidez() {
    return _box.values
        .where((e) => e['tipoInversion'] == TipoInversion.liquidez.name && _esDelUsuario(e))
        .map((e) => Liquidez.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveLiquidez(Liquidez liquidez) async {
    final json = liquidez.toJson();
    json['_uid'] = userId;
    await _box.put(_key(liquidez.id, TipoInversion.liquidez), json);
  }

  Future<void> deleteLiquidez(String id) async {
    await _box.delete(_key(id, TipoInversion.liquidez));
  }

  // ─── Otras ──────────────────────────────────────────────────────────────

  List<OtraInversion> getOtras() {
    return _box.values
        .where((e) => e['tipo'] == TipoInversion.otra.name && _esDelUsuario(e))
        .map((e) => OtraInversion.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveOtra(OtraInversion otra) async {
    final json = otra.toJson();
    json['_uid'] = userId;
    await _box.put(_key(otra.id, TipoInversion.otra), json);
  }

  Future<void> deleteOtra(String id) async {
    await _box.delete(_key(id, TipoInversion.otra));
  }

  // ─── Instrumentos ───────────────────────────────────────────────────────

  List<InstrumentoFinanciero> getInstrumentos() {
    return _box.values
        .where((e) => e['tipoInversion'] == TipoInversion.instrumento.name && _esDelUsuario(e))
        .map((e) => InstrumentoFinanciero.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveInstrumento(InstrumentoFinanciero inst) async {
    final json = inst.toJson();
    json['_uid'] = userId;
    await _box.put('instrumento_${inst.id}', json);
  }

  Future<void> deleteInstrumento(String id) async {
    await _box.delete('instrumento_$id');
  }

  // ─── Bienes de Uso ──────────────────────────────────────────────────────

  List<BienDeUso> getBienes() {
    return _box.values
        .where((e) => e['tipoInversion'] == TipoInversion.bien.name && _esDelUsuario(e))
        .map((e) => BienDeUso.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveBien(BienDeUso bien) async {
    final json = bien.toJson();
    json['_uid'] = userId;
    await _box.put('bien_${bien.id}', json);
  }

  Future<void> deleteBien(String id) async {
    await _box.delete('bien_$id');
  }

  // ─── Inversiones Alternativas ──────────────────────────────────────────────

  List<InversionAlternativa> getAlternativas() {
    return _box.values
        .where((e) => e['tipoInversion'] == TipoInversion.alternativa.name && _esDelUsuario(e))
        .map((e) => InversionAlternativa.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveAlternativa(InversionAlternativa alt) async {
    final json = alt.toJson();
    json['_uid'] = userId;
    await _box.put('alt_${alt.id}', json);
  }

  Future<void> deleteAlternativa(String id) async {
    await _box.delete('alt_$id');
  }

  // ─── Negocio Personal ─────────────────────────────────────────────────────

  List<NegocioPersonal> getNegociosPersonales() {
    return _box.values
        .where((e) => e['tipo'] == TipoInversion.negocio.name && _esDelUsuario(e))
        .map((e) => NegocioPersonal.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveNegocio(NegocioPersonal negocio) async {
    final json = negocio.toJson();
    json['_uid'] = userId;
    await _box.put('negocio_${negocio.id}', json);
  }

  Future<void> deleteNegocio(String id) async {
    await _box.delete('negocio_$id');
  }

  // ─── Operaciones Log ────────────────────────────────────────────────────

  List<OperacionLog> getOperaciones({String? ticker, TipoActivoOp? tipoActivo}) {
    return _box.values
        .where((e) =>
            e['tipo'] == 'operacion' &&
            _esDelUsuario(e) &&
            (ticker == null || e['ticker'] == ticker) &&
            (tipoActivo == null || e['tipoActivo'] == tipoActivo.name))
        .map((e) => OperacionLog.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  Future<void> saveOperacion(OperacionLog op) async {
    final json = op.toJson();
    json['_uid'] = userId;
    await _box.put('operacion_${op.id}', json);
  }

  Future<void> deleteOperacion(String id) async {
    await _box.delete('operacion_$id');
  }
}
