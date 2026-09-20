import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/sesion_provider.dart';
import '../data/pago_repository.dart';
import '../models/pago.dart';

/// Configuración de la pasarela (proveedor, simulación, moneda).
final configuracionPagoProvider = FutureProvider<ConfiguracionPago>((ref) {
  ref.watch(sesionProvider);
  return ref.watch(pagoRepositoryProvider).configuracion();
});

/// Estado del pago en curso (CU14). El estado real siempre lo confirma el
/// backend: volver de Stripe nunca marca el pago como aprobado por sí solo.
final pagoProvider = NotifierProvider<PagoController, PagoDetalle?>(
  PagoController.new,
);

class PagoController extends Notifier<PagoDetalle?> {
  @override
  PagoDetalle? build() {
    ref.watch(sesionProvider);
    return null;
  }

  Future<PagoDetalle> iniciar({
    required int nroVenta,
    required String metodo,
  }) async {
    final pago = await ref
        .read(pagoRepositoryProvider)
        .iniciar(nroVenta: nroVenta, metodo: metodo);
    state = pago;
    return pago;
  }

  /// Consulta la pasarela (Stripe) sin crear otro cobro.
  Future<PagoDetalle> reconciliar() async {
    final actual = state;
    if (actual == null) return Future.error(StateError('No hay pago en curso'));
    final pago = await ref
        .read(pagoRepositoryProvider)
        .reconciliar(actual.idPago);
    state = pago;
    return pago;
  }

  /// Solo modo simulación (pasarela mock en desarrollo).
  Future<PagoDetalle> procesar({String? escenario}) async {
    final actual = state;
    if (actual == null) return Future.error(StateError('No hay pago en curso'));
    final pago = await ref
        .read(pagoRepositoryProvider)
        .procesar(actual.idPago, escenario: escenario);
    state = pago;
    return pago;
  }

  void limpiar() => state = null;
}
