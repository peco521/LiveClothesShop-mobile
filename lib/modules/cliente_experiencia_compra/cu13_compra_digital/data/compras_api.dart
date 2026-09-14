import 'dart:convert';

import '../models/compra.dart';
import '../../../../core/api_client.dart';

/// Acceso a datos CU13 contra /api/cliente/compras. Solo ventas propias.
class ComprasApi {
  final ApiClient _api;
  final String? Function() _credential;

  ComprasApi({ApiClient? api, required String? Function() credential})
      : _api = api ?? ApiClient(),
        // ignore: prefer_initializing_formals, el parámetro es público entre paquetes
        _credential = credential;

  /// Prepara la venta. 201 = creada, 200 = reintento idempotente reutilizado.
  Future<CompraPreparada> preparar({required int nroSuc, String? nit}) async {
    final body = <String, dynamic>{'nroSuc': nroSuc};
    if (nit != null && nit.trim().isNotEmpty) body['nit'] = nit.trim();
    final response = await _api.postRaw('/api/cliente/compras/desde-carrito', body,
        credential: _credential());
    return CompraPreparada(
      venta: VentaDetalle.fromJson(jsonDecode(response.body) as Map<String, dynamic>),
      reutilizada: response.statusCode == 200,
    );
  }

  Future<VentaDetalle> detalle(int nro) async {
    final response =
        await _api.getRaw('/api/cliente/compras/$nro', credential: _credential());
    return VentaDetalle.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
