import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/providers.dart';
import '../models/carrito.dart';

/// CU12 Carrito de compras: el backend sigue siendo la fuente de verdad del
/// precio, la promoción y la disponibilidad (no se recalcula en la app).
class CarritoRepository {
  const CarritoRepository(this._client);

  final ApiClient _client;

  Future<Carrito> obtener() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/cliente/carrito',
    );
    return Carrito.fromJson(response.data ?? const {});
  }

  Future<Carrito> agregar({
    required String idVar,
    required int cantidad,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/cliente/carrito/items',
      body: {'idVar': idVar, 'cantidad': cantidad},
    );
    return Carrito.fromJson(response.data ?? const {});
  }

  Future<Carrito> cambiarCantidad({
    required int idDetalleCarro,
    required int cantidad,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/cliente/carrito/items/$idDetalleCarro',
      body: {'cantidad': cantidad},
    );
    return Carrito.fromJson(response.data ?? const {});
  }

  Future<Carrito> eliminar(int idDetalleCarro) async {
    final response = await _client.delete<Map<String, dynamic>>(
      '/cliente/carrito/items/$idDetalleCarro',
    );
    return Carrito.fromJson(response.data ?? const {});
  }
}

final carritoRepositoryProvider = Provider<CarritoRepository>(
  (ref) => CarritoRepository(ref.watch(apiClientProvider)),
);
