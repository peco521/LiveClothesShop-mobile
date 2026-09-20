import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cu12_carrito/providers/carrito_provider.dart';
import '../../shared/providers/sesion_provider.dart';
import '../data/compra_repository.dart';
import '../models/compra.dart';

/// Venta pendiente del cliente (CU13). Se recalcula con la sesión.
final checkoutProvider =
    AsyncNotifierProvider<CheckoutController, VentaDetalle?>(
      CheckoutController.new,
    );

class CheckoutController extends AsyncNotifier<VentaDetalle?> {
  @override
  Future<VentaDetalle?> build() async {
    ref.watch(sesionProvider);
    return ref.watch(compraRepositoryProvider).pendiente();
  }

  /// Registra la compra desde el carrito. El backend devuelve los importes
  /// definitivos (bruto, descuentos y total) que la app solo muestra.
  Future<VentaDetalle> preparar({required int nroSuc, String? nit}) async {
    final venta = await ref
        .read(compraRepositoryProvider)
        .checkout(nroSuc: nroSuc, nit: nit);
    state = AsyncData(venta);
    // El carrito se convirtió en venta: CU13 refresca el estado de CU12.
    await ref.read(carritoProvider.notifier).refrescar();
    return venta;
  }

  Future<void> cancelar(int nroVenta) async {
    await ref.read(compraRepositoryProvider).cancelar(nroVenta);
    state = const AsyncData(null);
    await ref.read(carritoProvider.notifier).refrescar();
  }
}

/// Detalle de una venta propia.
final ventaDetalleProvider = FutureProvider.family<VentaDetalle, int>((
  ref,
  nroVenta,
) {
  ref.watch(sesionProvider);
  return ref.watch(compraRepositoryProvider).detalle(nroVenta);
});
