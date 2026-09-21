import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:liveclothesshop_mobile/core/api_error.dart';
import 'package:liveclothesshop_mobile/core/credential_store.dart';
import 'package:liveclothesshop_mobile/core/session.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu10_consultar_prendas/data/catalogo_api.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu10_consultar_prendas/models/catalogo.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu10_consultar_prendas/screens/catalogo_screen.dart';

ProductoResumen _item(String id, String nombre) => ProductoResumen(
      idProd: id,
      descripcion: nombre,
      categoria: 'Camisas',
      marca: 'Andes',
      coleccion: 'Otoño',
      promocion: null,
      precioMin: 100,
      precioMax: 150,
      imagen: null,
      disponible: true,
      totalVariantes: 2,
    );

class FakeCatalogoApi extends CatalogoApi {
  FakeCatalogoApi() : super(credential: () => 'cred');

  ProductosListado? pagina;
  Object? falla;
  ProductoDetalle? detalleObj;

  @override
  Future<ProductosListado> listar(CatalogoFiltros filtros, {int offset = 0, int limit = 20}) async {
    if (falla != null) throw falla!;
    return pagina!;
  }

  @override
  Future<List<FacetaItem>> faceta(String grupo) async => [];

  @override
  Future<ProductoDetalle> detalle(String idProd) async => detalleObj!;
}

Widget _appConApi(FakeCatalogoApi api) => ChangeNotifierProvider(
      create: (_) => SessionState(store: MemoryCredentialStore()),
      child: MaterialApp(home: CatalogoScreen(api: api)),
    );

void main() {
  group('CatalogoScreen', () {
    testWidgets('muestra lista, paginación y sin códigos internos', (tester) async {
      final api = FakeCatalogoApi()
        ..pagina = ProductosListado(items: [_item('p1', 'Camisa Oxford'), _item('p2', 'Pantalón Chino')],
            total: 2, offset: 0, limit: 20);
      await tester.pumpWidget(_appConApi(api));
      await tester.pumpAndSettle();
      expect(find.text('Catálogo'), findsOneWidget);
      expect(find.text('Camisa Oxford'), findsOneWidget);
      expect(find.text('2 prendas encontradas.'), findsOneWidget);
      expect(find.textContaining('CU10'), findsNothing);
      expect(find.textContaining('CU11'), findsNothing);
    });

    testWidgets('muestra estado vacío funcional', (tester) async {
      final api = FakeCatalogoApi()
        ..pagina = const ProductosListado(items: [], total: 0, offset: 0, limit: 20);
      await tester.pumpWidget(_appConApi(api));
      await tester.pumpAndSettle();
      expect(find.text('No hay prendas para los filtros aplicados.'), findsOneWidget);
    });

    testWidgets('muestra error y reintenta', (tester) async {
      final api = FakeCatalogoApi()..falla = const ApiException(500, 'error_interno');
      await tester.pumpWidget(_appConApi(api));
      await tester.pumpAndSettle();
      expect(find.text('No se pudo completar la operación. Inténtalo nuevamente.'), findsOneWidget);
      api
        ..falla = null
        ..pagina = ProductosListado(items: [_item('p1', 'Camisa Oxford')], total: 1, offset: 0, limit: 20);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Camisa Oxford'), findsOneWidget);
    });

    testWidgets('tap en tarjeta abre el detalle', (tester) async {
      final api = FakeCatalogoApi()
        ..pagina = ProductosListado(items: [_item('p1', 'Camisa Oxford')], total: 1, offset: 0, limit: 20)
        ..detalleObj = ProductoDetalle(
            idProd: 'p1',
            descripcion: 'Camisa Oxford',
            marca: 'Andes',
            categoria: 'Camisas',
            coleccion: 'Otoño',
            promocion: null,
            variantes: const [],
            disponibilidad: const [],
          );
      await tester.pumpWidget(_appConApi(api));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Camisa Oxford'));
      await tester.pumpAndSettle();
      expect(find.text('Detalle de prenda'), findsOneWidget);
      expect(find.text('Disponibilidad por sucursal'), findsOneWidget);
    });
  });
}
