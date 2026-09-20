import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/sesion_provider.dart';
import '../data/reservas_repository.dart';
import '../models/reserva.dart';

/// Listado de reservas propias (CU11). Se refresca tras crear o cancelar.
final reservasProvider =
    AsyncNotifierProvider<ReservasController, ReservasListado>(
      ReservasController.new,
    );

class ReservasController extends AsyncNotifier<ReservasListado> {
  @override
  Future<ReservasListado> build() async {
    ref.watch(sesionProvider);
    return ref.watch(reservasRepositoryProvider).listar();
  }

  Future<void> refrescar() async {
    state = await AsyncValue.guard(
      () => ref.read(reservasRepositoryProvider).listar(),
    );
  }

  /// Crea la reserva y devuelve la reserva resultante (para ver su detalle).
  Future<Reserva> crear({
    required int nroSuc,
    required String fechaReserva,
    required String horaAtencion,
    required List<Map<String, Object>> items,
  }) async {
    final reserva = await ref
        .read(reservasRepositoryProvider)
        .crear(
          nroSuc: nroSuc,
          fechaReserva: fechaReserva,
          horaAtencion: horaAtencion,
          items: items,
        );
    await refrescar();
    // El detalle individual también se invalida para reflejar el estado nuevo.
    ref.invalidate(reservaDetalleProvider(reserva.nroReserva));
    return reserva;
  }

  Future<void> cancelar(int nroReserva) async {
    await ref.read(reservasRepositoryProvider).cancelar(nroReserva);
    ref.invalidate(reservaDetalleProvider(nroReserva));
    await refrescar();
  }
}

/// Detalle de una reserva propia.
final reservaDetalleProvider = FutureProvider.family<Reserva, int>((
  ref,
  nroReserva,
) {
  ref.watch(sesionProvider);
  return ref.watch(reservasRepositoryProvider).detalle(nroReserva);
});

/// Sucursales activas donde el cliente puede reservar.
final sucursalesProvider = FutureProvider<List<SucursalCliente>>((ref) {
  ref.watch(sesionProvider);
  return ref.watch(reservasRepositoryProvider).sucursales();
});

/// Horarios de atención declarados para una sucursal.
final horariosSucursalProvider = FutureProvider.family<HorariosSucursal, int>((
  ref,
  nroSuc,
) {
  ref.watch(sesionProvider);
  return ref.watch(reservasRepositoryProvider).horarios(nroSuc);
});
