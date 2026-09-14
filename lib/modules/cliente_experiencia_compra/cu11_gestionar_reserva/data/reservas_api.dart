import 'dart:convert';

import '../models/reserva.dart';
import '../../../../core/api_client.dart';

/// Acceso a datos CU11 contra /api/cliente. Solo reservas propias.
class ReservasApi {
  final ApiClient _api;
  final String? Function() _credential;

  ReservasApi({ApiClient? api, required String? Function() credential})
      : _api = api ?? ApiClient(),
        // ignore: prefer_initializing_formals, el parámetro es público entre paquetes
        _credential = credential;

  Future<ReservaDetalle> crear(ReservaCrear input) async {
    final response = await _api.postRaw('/api/cliente/reservas', input.toJson(), credential: _credential());
    return ReservaDetalle.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ReservasListado> listar({String? estado, int offset = 0, int limit = 20}) async {
    final query = <String, String>{'offset': '$offset', 'limit': '$limit'};
    if (estado != null && estado.isNotEmpty) query['estado'] = estado;
    final response =
        await _api.getRaw('/api/cliente/reservas', query: query, credential: _credential());
    return ReservasListado.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ReservaDetalle> detalle(int nro) async {
    final response = await _api.getRaw('/api/cliente/reservas/$nro', credential: _credential());
    return ReservaDetalle.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ReservaDetalle> cancelar(int nro) async {
    final response = await _api.patchRaw('/api/cliente/reservas/$nro/cancelar', {}, credential: _credential());
    return ReservaDetalle.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<SucursalCliente>> sucursales() async {
    final response = await _api.getRaw('/api/cliente/sucursales', credential: _credential());
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return ((body['items'] as List? ?? []).map((e) => SucursalCliente.fromJson(e as Map<String, dynamic>))).toList();
  }

  Future<List<HorarioRango>> horarios(int nroSuc) async {
    final response = await _api.getRaw('/api/cliente/sucursales/$nroSuc/horarios', credential: _credential());
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return ((body['rangos'] as List? ?? []).map((e) => HorarioRango.fromJson(e as Map<String, dynamic>))).toList();
  }
}
