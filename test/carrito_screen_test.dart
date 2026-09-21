import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:liveclothesshop_mobile/core/api_error.dart';
import 'package:liveclothesshop_mobile/core/credential_store.dart';
import 'package:liveclothesshop_mobile/core/session.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu12_carrito/data/carrito_api.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu12_carrito/models/carrito.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu12_carrito/screens/carrito_screen.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu10_consultar_prendas/data/catalogo_api.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu10_consultar_prendas/models/catalogo.dart'
    as catalogo;
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu10_consultar_prendas/screens/detalle_screen.dart';

CarritoItem _item({int cantidad = 2, bool disponible = true}) => CarritoItem(
      idDetalle: 1,
      idVar: 'v1',
      sku: 'SKU-1',
      imagen: null,
      producto: 'Camisa Oxford',
      talla: 'M',
      colores: const ['Rojo'],
      precio: 100,
      promocion: 'Promo',
      cantidad: cantidad,
      subtotal: 100.0 * cantidad,
      disponible: disponible,
      cantidadDisponible: 4,
    );

class FakeCarritoApi extends CarritoApi {
  FakeCarritoApi() : super(credential: () => 'cred');

  CarritoDetalle? estado;
  Object? falla;
  int modificarLlamadas = 0;
  int eliminarLlamadas = 0;
  (String, int)? agregado;

  @override
  Future<CarritoDetalle> obtener() async {
    if (falla != null) throw falla!;
    return estado!;
  }

  @override
  Future<CarritoDetalle> agregar(String idVar, int cantidad) async {
    agregado = (idVar, cantidad);
    return estado!;
  }

  @override
  Future<CarritoDetalle> modificar(int idDetalle, int cantidad) async {
    modificarLlamadas++;
    return estado!;
  }

  @override
  Future<CarritoDetalle> eliminar(int idDetalle) async {
    eliminarLlamadas++;
    return CarritoDetalle.vacio();
  }
}

Widget _app(FakeCarritoApi api) => ChangeNotifierProvider(
      create: (_) => SessionState(store: MemoryCredentialStore()),
      child: MaterialApp(home: CarritoScreen(api: api)),
    );

void main() {
  group('CarritoScreen', () {
    testWidgets('muestra items, subtotal y sin checkout ni códigos', (tester) async {
      final api = FakeCarritoApi()
        ..estado = CarritoDetalle(idCarrito: 5, items: [_item()], cantidadItems: 2, subtotal: 200);
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      expect(find.text('Carrito'), findsOneWidget);
      expect(find.text('Camisa Oxford'), findsOneWidget);
      expect(find.text('Subtotal: Bs 200.00'), findsOneWidget);
      expect(find.text('2 prendas'), findsOneWidget);
      expect(find.text('Finalizar compra'), findsOneWidget);
      expect(find.text('Pagar'), findsNothing);
      expect(find.textContaining('CU12'), findsNothing);
    });

    testWidgets('vacío y error con reintento', (tester) async {
      final api = FakeCarritoApi()..estado = CarritoDetalle.vacio();
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      expect(find.text('No tienes productos en tu carrito.'), findsOneWidget);
    });

    testWidgets('error inicial con reintento', (tester) async {
      final api = FakeCarritoApi()..falla = const ApiException(500, 'error_interno');
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar'), findsOneWidget);
      api
        ..falla = null
        ..estado = CarritoDetalle(idCarrito: 5, items: [_item()], cantidadItems: 2, subtotal: 200);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Camisa Oxford'), findsOneWidget);
    });

    testWidgets('aumentar, disminuir y eliminar usan la API', (tester) async {
      final api = FakeCarritoApi()
        ..estado = CarritoDetalle(idCarrito: 5, items: [_item()], cantidadItems: 2, subtotal: 200);
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Aumentar'));
      await tester.pumpAndSettle();
      expect(api.modificarLlamadas, 1);
      await tester.tap(find.byTooltip('Disminuir'));
      await tester.pumpAndSettle();
      expect(api.modificarLlamadas, 2);
      await tester.tap(find.byTooltip('Eliminar'));
      await tester.pumpAndSettle();
      expect(api.eliminarLlamadas, 1);
      expect(find.text('No tienes productos en tu carrito.'), findsOneWidget);
    });

    testWidgets('marca no disponible sin borrar el item', (tester) async {
      final api = FakeCarritoApi()
        ..estado = CarritoDetalle(
            idCarrito: 5, items: [_item(disponible: false)], cantidadItems: 2, subtotal: 200);
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      expect(find.textContaining('No disponible actualmente'), findsOneWidget);
      expect(find.text('Camisa Oxford'), findsOneWidget);
    });
  });

  group('Integración detalle → carrito', () {
    testWidgets('agregar con cantidad elegida y sin checkout', (tester) async {
      final carrito = FakeCarritoApi()
        ..estado = CarritoDetalle(idCarrito: 5, items: [_item()], cantidadItems: 2, subtotal: 200);
      final detalle = _FakeDetalleApi();
      await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => SessionState(store: MemoryCredentialStore()),
        child: MaterialApp(
          routes: {'/tienda/carrito': (_) => const Text('RUTA CARRITO')},
          home: DetalleScreen(idProd: 'p1', api: detalle, carritoApi: carrito),
        ),
      ));
      await tester.pumpAndSettle();
      // Sin variante elegida no hay acción de agregar.
      expect(find.text('Agregar al carrito'), findsNothing);
      await tester.tap(find.text('Talla M · Bs 100.00').first);
      await tester.pumpAndSettle();
      expect(find.text('Agregar al carrito'), findsOneWidget);
      await tester.tap(find.byTooltip('Aumentar'));
      await tester.pump();
      await tester.tap(find.text('Agregar al carrito'));
      await tester.pumpAndSettle();
      expect(carrito.agregado, ('var-001', 2));
      expect(find.text('Prenda agregada al carrito.'), findsOneWidget);
      expect(find.text('Finalizar compra'), findsNothing);
      expect(find.textContaining('CU12'), findsNothing);
    });
  });
}

class _FakeDetalleApi extends CatalogoApi {
  _FakeDetalleApi() : super(credential: () => 'cred');

  @override
  Future<catalogo.ProductoDetalle> detalle(String idProd) async => catalogo.ProductoDetalle(
        idProd: 'p1',
        descripcion: 'Camisa Oxford',
        marca: 'Andes',
        categoria: 'Camisas',
        coleccion: 'Otoño',
        promocion: null,
        variantes: const [
          catalogo.VarianteDetalle(
            id: 'var-001',
            sku: 'SKU-1',
            precio: 100,
            imagen: null,
            talla: catalogo.TallaDetalle(id: 1, descripcion: 'M'),
            colores: [],
          ),
          catalogo.VarianteDetalle(
            id: 'var-002',
            sku: 'SKU-2',
            precio: 150,
            imagen: null,
            talla: catalogo.TallaDetalle(id: 2, descripcion: 'L'),
            colores: [],
          ),
        ],
        disponibilidad: const [],
      );

  @override
  Future<catalogo.ProductosListado> listar(catalogo.CatalogoFiltros filtros,
          {int offset = 0, int limit = 20}) =>
      throw UnimplementedError();

  @override
  Future<List<catalogo.FacetaItem>> faceta(String grupo) async => [];
}
