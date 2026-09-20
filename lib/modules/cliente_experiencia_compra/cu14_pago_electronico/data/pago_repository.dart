import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/providers.dart';
import '../models/pago.dart';

/// CU14 Pago electrónico: inicia el cobro y consulta su estado real.
class PagoRepository {
  const PagoRepository(this._client);

  final ApiClient _client;

  Future<ConfiguracionPago> configuracion() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/cliente/pagos/configuracion',
    );
    return ConfiguracionPago.fromJson(response.data ?? const {});
  }

  Future<PagoDetalle> iniciar({
    required int nroVenta,
    required String metodo,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/cliente/pagos',
      body: {'nroVenta': nroVenta, 'metodo': metodo},
    );
    return PagoDetalle.fromJson(response.data ?? const {});
  }

  Future<PagoDetalle> detalle(int idPago) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/cliente/pagos/$idPago',
    );
    return PagoDetalle.fromJson(response.data ?? const {});
  }

  /// Consulta la pasarela sin crear un cobro nuevo (Stripe Checkout).
  Future<PagoDetalle> reconciliar(int idPago) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/cliente/pagos/$idPago/reconciliar',
    );
    return PagoDetalle.fromJson(response.data ?? const {});
  }

  /// Solo para el modo simulación (pasarela mock en desarrollo).
  Future<PagoDetalle> procesar(int idPago, {String? escenario}) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/cliente/pagos/$idPago/procesar',
      body: {if (escenario != null) 'escenario': escenario},
    );
    return PagoDetalle.fromJson(response.data ?? const {});
  }
}

final pagoRepositoryProvider = Provider<PagoRepository>(
  (ref) => PagoRepository(ref.watch(apiClientProvider)),
);
