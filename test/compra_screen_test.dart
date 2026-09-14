import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:liveclothesshop_mobile/core/api_error.dart';
import 'package:liveclothesshop_mobile/core/credential_store.dart';
import 'package:liveclothesshop_mobile/core/session.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu11_gestionar_reserva/data/reservas_api.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu11_gestionar_reserva/models/reserva.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu12_carrito/data/carrito_api.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu12_carrito/models/carrito.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu13_compra_digital/data/compras_api.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu13_compra_digital/models/compra.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu13_compra_digital/screens/checkout_screen.dart';

VentaDetalle _venta() => const VentaDetalle(
      nroVenta: 11,
      fechaHora: '2026-09-13T10:00:00',
      estado: 'registrada',
      nit: null,
      sucursal: 'Central',
      ciudad: 'La Paz',
      carrito: 5,
      items: [
        VentaItem(
            idDetalle: 1,
            idVar: 'v1',
            sku: 'SKU-1',
            producto: 'Camisa Oxford',
            cantidad: 2,
            precioUnitario: 100,
            subtotalBruto: 200),
      ],
      brutoTotal: 200,
      descAplicado: 20,
      total: 180,
    );

class FakeCarrito extends CarritoApi {
  FakeCarrito() : super(credential: () => 'cred');

  @override
  Future<CarritoDetalle> obtener() async => CarritoDetalle(
        idCarrito: 5,
        items: const [
          CarritoItem(
              idDetalle: 1,
              idVar: 'v1',
              sku: 'SKU-1',
              imagen: null,
              producto: 'Camisa Oxford',
              talla: 'M',
              colores: ['Rojo'],
              precio: 100,
              promocion: null,
              cantidad: 2,
              subtotal: 200,
              disponible: true,
              cantidadDisponible: 4),
        ],
        cantidadItems: 2,
        subtotal: 200,
      );

  @override
  Future<CarritoDetalle> agregar(String idVar, int cantidad) =>
      throw UnimplementedError();
  @override
  Future<CarritoDetalle> modificar(int idDetalle, int cantidad) =>
      throw UnimplementedError();
  @override
  Future<CarritoDetalle> eliminar(int idDetalle) => throw UnimplementedError();
}

class FakeSucursales extends ReservasApi {
  FakeSucursales() : super(credential: () => 'cred');

  @override
  Future<List<SucursalCliente>> sucursales() async => const [
        SucursalCliente(nro: 1, nombre: 'Central', direccion: 'D1', ciudad: 'La Paz'),
      ];

  @override
  Future<ReservaDetalle> crear(ReservaCrear input) => throw UnimplementedError();
  @override
  Future<ReservasListado> listar({String? estado, int offset = 0, int limit = 20}) =>
      throw UnimplementedError();
  @override
  Future<ReservaDetalle> detalle(int nro) => throw UnimplementedError();
  @override
  Future<ReservaDetalle> cancelar(int nro) => throw UnimplementedError();
  @override
  Future<List<HorarioRango>> horarios(int nroSuc) async => [];
}

class FakeCompras extends ComprasApi {
  FakeCompras() : super(credential: () => 'cred');

  int? sucursalUsada;
  String? nitUsado;
  Object? falla;

  @override
  Future<CompraPreparada> preparar({required int nroSuc, String? nit}) async {
    if (falla != null) throw falla!;
    sucursalUsada = nroSuc;
    nitUsado = nit;
    return CompraPreparada(venta: _venta(), reutilizada: false);
  }

  @override
  Future<VentaDetalle> detalle(int nro) async => _venta();
}

Widget _app({required FakeCarrito carrito, required FakeSucursales sucursales, required FakeCompras compras}) =>
    ChangeNotifierProvider(
      create: (_) => SessionState(store: MemoryCredentialStore()),
      child: MaterialApp(
          home: CheckoutScreen(carritoApi: carrito, sucursalesApi: sucursales, api: compras)),
    );

void main() {
  group('CheckoutScreen', () {
    testWidgets('resumen, sucursal, NIT y confirmación sin pago', (tester) async {
      final compras = FakeCompras();
      await tester.pumpWidget(_app(
          carrito: FakeCarrito(), sucursales: FakeSucursales(), compras: compras));
      await tester.pumpAndSettle();
      expect(find.text('Finalizar compra'), findsOneWidget);
      expect(find.text('Camisa Oxford'), findsOneWidget);
      expect(find.textContaining('CU13'), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Central · La Paz').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.tap(find.text('Confirmar compra'));
      await tester.pumpAndSettle();
      expect(compras.sucursalUsada, 1);
      expect(compras.nitUsado, '123456');
      expect(find.text('Compra 11'), findsOneWidget);
      expect(find.textContaining('Compra preparada para realizar el pago.'), findsOneWidget);
      expect(find.text('Pagar'), findsNothing);
      expect(find.text('Compra completada'), findsNothing);
    });

    testWidgets('disponibilidad insuficiente funcional', (tester) async {
      final compras = FakeCompras()..falla = const ApiException(409, 'disponibilidad_insuficiente');
      await tester.pumpWidget(_app(
          carrito: FakeCarrito(), sucursales: FakeSucursales(), compras: compras));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Central · La Paz').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar compra'));
      await tester.pumpAndSettle();
      expect(find.text('No hay disponibilidad suficiente en la sucursal elegida.'), findsOneWidget);
    });
  });
}
