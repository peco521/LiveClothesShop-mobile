import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/sesion_provider.dart';
import '../data/carrito_repository.dart';
import '../models/carrito.dart';

/// Estado del carrito (CU12). Al cambiar la sesión se recalcula solo, y el
/// contador de la barra inferior observa este mismo provider.
final carritoProvider = AsyncNotifierProvider<CarritoController, Carrito>(
  CarritoController.new,
);

class CarritoController extends AsyncNotifier<Carrito> {
  @override
  Future<Carrito> build() async {
    ref.watch(sesionProvider);
    return ref.watch(carritoRepositoryProvider).obtener();
  }

  Future<void> refrescar() async {
    state = await AsyncValue.guard(
      () => ref.read(carritoRepositoryProvider).obtener(),
    );
  }

  /// Las operaciones lanzan [AppException] si el backend rechaza el cambio
  /// (stock, compra pendiente, etc.). Así la pantalla muestra el aviso sin
  /// perder el contenido del carrito que ya estaba cargado.
  Future<void> agregar({required String idVar, required int cantidad}) async {
    final carrito = await ref
        .read(carritoRepositoryProvider)
        .agregar(idVar: idVar, cantidad: cantidad);
    state = AsyncData(carrito);
  }

  Future<void> cambiarCantidad({
    required int idDetalleCarro,
    required int cantidad,
  }) async {
    if (cantidad < 1) return;
    final carrito = await ref
        .read(carritoRepositoryProvider)
        .cambiarCantidad(idDetalleCarro: idDetalleCarro, cantidad: cantidad);
    state = AsyncData(carrito);
  }

  Future<void> eliminar(int idDetalleCarro) async {
    final carrito = await ref
        .read(carritoRepositoryProvider)
        .eliminar(idDetalleCarro);
    state = AsyncData(carrito);
  }

  /// Contador para la barra de navegación (0 mientras carga o si falla).
  int get cantidadItems => state.asData?.value.cantidadItems ?? 0;
}
