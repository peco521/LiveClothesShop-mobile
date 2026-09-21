import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/sesion_provider.dart';
import '../data/catalogo_repository.dart';
import '../models/producto.dart';

/// Filtros activos del catálogo (CU10).
final filtrosCatalogoProvider =
    NotifierProvider<FiltrosCatalogoNotifier, FiltrosCatalogo>(
      FiltrosCatalogoNotifier.new,
    );

class FiltrosCatalogoNotifier extends Notifier<FiltrosCatalogo> {
  @override
  FiltrosCatalogo build() => const FiltrosCatalogo();

  void buscar(String texto) => state = state.copyWith(q: texto, offset: 0);

  void aplicar(FiltrosCatalogo nuevos) => state = nuevos.copyWith(offset: 0);

  void limpiar() => state = const FiltrosCatalogo();

  void pagina(int offset) =>
      state = state.copyWith(offset: offset < 0 ? 0 : offset);
}

/// Listado de poleras disponibles (mismo endpoint que la web).
final catalogoProvider =
    AsyncNotifierProvider<CatalogoController, ProductosCatalogo>(
      CatalogoController.new,
    );

class CatalogoController extends AsyncNotifier<ProductosCatalogo> {
  @override
  Future<ProductosCatalogo> build() async {
    ref.watch(sesionProvider); // se recarga al iniciar o cerrar sesión
    final filtros = ref.watch(filtrosCatalogoProvider);
    return ref.watch(catalogoRepositoryProvider).listar(filtros);
  }

  Future<void> refrescar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(catalogoRepositoryProvider)
          .listar(ref.read(filtrosCatalogoProvider)),
    );
  }
}

/// Facetas de los filtros (modelo de polera, marca, temporada, talla).
final facetasCatalogoProvider = FutureProvider<FacetasCatalogo>((ref) {
  ref.watch(sesionProvider);
  return ref.watch(catalogoRepositoryProvider).facetas();
});

/// Detalle de una polera con sus variantes y disponibilidad por sucursal.
final productoDetalleProvider = FutureProvider.family<ProductoDetalle, String>((
  ref,
  idProd,
) {
  ref.watch(sesionProvider);
  return ref.watch(catalogoRepositoryProvider).detalle(idProd);
});
