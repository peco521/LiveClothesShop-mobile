import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/providers.dart';
import '../models/reserva.dart';

/// CU11 Reservas: crear, listar, ver, cancelar, sucursales y horarios.
class ReservasRepository {
  const ReservasRepository(this._client);

  final ApiClient _client;

  Future<ReservasListado> listar({
    int offset = 0,
    int limit = 20,
    String? estado,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/cliente/reservas',
      query: {
        'offset': offset,
        'limit': limit,
        if (estado != null) 'estado': estado,
      },
    );
    return ReservasListado.fromJson(response.data ?? const {});
  }

  Future<Reserva> detalle(int nroReserva) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/cliente/reservas/$nroReserva',
    );
    return Reserva.fromJson(response.data ?? const {});
  }

  /// `fechaReserva` en `yyyy-MM-dd` y `horaAtencion` en `HH:mm:ss`.
  Future<Reserva> crear({
    required int nroSuc,
    required String fechaReserva,
    required String horaAtencion,
    required List<Map<String, Object>> items,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/cliente/reservas',
      body: {
        'nroSuc': nroSuc,
        'fechaReserva': fechaReserva,
        'horaAtencion': horaAtencion,
        'items': items,
      },
    );
    return Reserva.fromJson(response.data ?? const {});
  }

  Future<Reserva> cancelar(int nroReserva) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/cliente/reservas/$nroReserva/cancelar',
    );
    return Reserva.fromJson(response.data ?? const {});
  }

  Future<List<SucursalCliente>> sucursales() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/cliente/sucursales',
    );
    final data = response.data ?? const <String, dynamic>{};
    return (data['items'] as List? ?? const [])
        .map(
          (item) =>
              SucursalCliente.fromJson((item as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  Future<HorariosSucursal> horarios(int nroSuc) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/cliente/sucursales/$nroSuc/horarios',
    );
    return HorariosSucursal.fromJson(response.data ?? const {});
  }
}

final reservasRepositoryProvider = Provider<ReservasRepository>(
  (ref) => ReservasRepository(ref.watch(apiClientProvider)),
);
