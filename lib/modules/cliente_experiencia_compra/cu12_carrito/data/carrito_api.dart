import 'dart:convert';

import '../models/carrito.dart';
import '../../../../core/api_client.dart';

/// Acceso a datos CU12 contra /api/cliente/carrito. Solo carrito activo propio.
class CarritoApi {
  final ApiClient _api;
  final String? Function() _credential;

  CarritoApi({ApiClient? api, required String? Function() credential})
      : _api = api ?? ApiClient(),
        // ignore: prefer_initializing_formals, el parámetro es público entre paquetes
        _credential = credential;

  Future<CarritoDetalle> obtener() async {
    final response = await _api.getRaw('/api/cliente/carrito', credential: _credential());
    return CarritoDetalle.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<CarritoDetalle> agregar(String idVar, int cantidad) async {
    final response = await _api.postRaw(
        '/api/cliente/carrito/items', {'idVar': idVar, 'cantidad': cantidad},
        credential: _credential());
    return CarritoDetalle.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<CarritoDetalle> modificar(int idDetalle, int cantidad) async {
    final response = await _api.patchRaw(
        '/api/cliente/carrito/items/$idDetalle', {'cantidad': cantidad},
        credential: _credential());
    return CarritoDetalle.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<CarritoDetalle> eliminar(int idDetalle) async {
    final response =
        await _api.deleteRaw('/api/cliente/carrito/items/$idDetalle', credential: _credential());
    return CarritoDetalle.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
