import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/providers.dart';
import '../models/compra.dart';

/// CU13 Compra digital: registra la venta desde el carrito y consulta su estado.
/// El backend calcula descuentos y total definitivos.
class CompraRepository {
  const CompraRepository(this._client);

  final ApiClient _client;

  Future<VentaDetalle> checkout({required int nroSuc, String? nit}) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/cliente/compras/desde-carrito',
      body: {
        'nroSuc': nroSuc,
        if (nit != null && nit.trim().isNotEmpty) 'nit': nit.trim(),
      },
    );
    return VentaDetalle.fromJson(response.data ?? const {});
  }

  /// Venta registrada pendiente de pago (o `null` si no hay ninguna).
  Future<VentaDetalle?> pendiente() async {
    final response = await _client.get<Map<String, dynamic>?>(
      '/cliente/compras/pendiente',
    );
    final data = response.data;
    if (data == null || data.isEmpty) return null;
    return VentaDetalle.fromJson(data);
  }

  Future<VentaDetalle> detalle(int nroVenta) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/cliente/compras/$nroVenta',
    );
    return VentaDetalle.fromJson(response.data ?? const {});
  }

  Future<VentaDetalle> cancelar(int nroVenta) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/cliente/compras/$nroVenta/cancelar',
    );
    return VentaDetalle.fromJson(response.data ?? const {});
  }
}

final compraRepositoryProvider = Provider<CompraRepository>(
  (ref) => CompraRepository(ref.watch(apiClientProvider)),
);
