import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/providers.dart';
import '../../shared/providers/sesion_provider.dart';
import '../models/compra_historial.dart';

/// CU15 Historial de compras propias (solo lectura).
class HistorialRepository {
  const HistorialRepository(this._client);

  final ApiClient _client;

  Future<HistorialCompras> listar({int offset = 0, int limit = 20}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/cliente/historial-compras',
      query: {'offset': offset, 'limit': limit},
    );
    return HistorialCompras.fromJson(response.data ?? const {});
  }

  Future<CompraDetalle> detalle(int nroVenta) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/cliente/historial-compras/$nroVenta',
    );
    return CompraDetalle.fromJson(response.data ?? const {});
  }
}

final historialRepositoryProvider = Provider<HistorialRepository>(
  (ref) => HistorialRepository(ref.watch(apiClientProvider)),
);

/// Historial completo del cliente (paginado según lo que pida la pantalla).
final historialProvider = FutureProvider<HistorialCompras>((ref) {
  ref.watch(sesionProvider);
  return ref.watch(historialRepositoryProvider).listar();
});

/// Detalle de una compra del historial.
final compraHistorialDetalleProvider =
    FutureProvider.family<CompraDetalle, int>((ref, nroVenta) {
      ref.watch(sesionProvider);
      return ref.watch(historialRepositoryProvider).detalle(nroVenta);
    });
