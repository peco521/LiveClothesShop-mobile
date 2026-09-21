import 'dart:convert';

import '../models/pago.dart';
import '../../../../core/api_client.dart';
/// Acceso a datos CU14 contra /api/cliente/pagos. Solo pagos propios.
class PagosApi {
  final ApiClient _api;
  final String? Function() _credential;

  PagosApi({ApiClient? api, required String? Function() credential})
      : _api = api ?? ApiClient(),
        // ignore: prefer_initializing_formals, el parámetro es público entre paquetes
        _credential = credential;

  /// Paga la venta. 201 = nuevo pago, 200 = pago existente reutilizado.
  Future<PagoPreparado> pagar({
    required int nroVenta,
    required String metodo,
    String? escenario,
  }) async {
    final body = <String, dynamic>{'nroVenta': nroVenta, 'metodo': metodo};
    if (escenario != null && escenario.isNotEmpty) body['escenario'] = escenario;
    final response = await _api.postRaw('/api/cliente/pagos', body, credential: _credential());
    return PagoPreparado(
      pago: PagoDetalle.fromJson(jsonDecode(response.body) as Map<String, dynamic>),
      reutilizado: response.statusCode == 200,
    );
  }

  Future<PagoDetalle> detalle(int idPago) async {
    final response =
        await _api.getRaw('/api/cliente/pagos/$idPago', credential: _credential());
    return PagoDetalle.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<PagoDetalle> procesar(int idPago, {String? escenario}) async {
    final body = <String, dynamic>{};
    if (escenario != null && escenario.isNotEmpty) body['escenario'] = escenario;
    final response = await _api.postRaw('/api/cliente/pagos/$idPago/procesar', body,
        credential: _credential());
    return PagoDetalle.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
