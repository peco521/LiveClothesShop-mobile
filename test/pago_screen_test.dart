import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:liveclothesshop_mobile/core/api_error.dart';
import 'package:liveclothesshop_mobile/core/credential_store.dart';
import 'package:liveclothesshop_mobile/core/session.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu14_pago_electronico/data/pagos_api.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu14_pago_electronico/models/pago.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu14_pago_electronico/screens/estado_pago_screen.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu14_pago_electronico/screens/pago_screen.dart';

PagoDetalle _pago({String estado = 'aprobado', String? referencia = 'MOCK-000003-11'}) =>
    PagoDetalle(
      idPago: 3,
      metodo: 'tarjeta',
      monto: 180,
      estado: estado,
      fechaHora: '2026-09-13T10:05:00',
      referencia: referencia,
      nroVenta: 11,
      estadoVenta: estado == 'rechazado' ? 'anulada' : 'registrada',
    );

class FakePagosApi extends PagosApi {
  FakePagosApi() : super(credential: () => 'cred');

  int? nroUsado;
  String? metodoUsado;
  PagoDetalle? resultado;
  Object? falla;
  int procesarLlamadas = 0;

  @override
  Future<PagoPreparado> pagar(
      {required int nroVenta, required String metodo, String? escenario}) async {
    if (falla != null) throw falla!;
    nroUsado = nroVenta;
    metodoUsado = metodo;
    return PagoPreparado(pago: resultado!, reutilizado: false);
  }

  @override
  Future<PagoDetalle> detalle(int idPago) async {
    if (falla != null) throw falla!;
    return resultado!;
  }

  @override
  Future<PagoDetalle> procesar(int idPago, {String? escenario}) async {
    procesarLlamadas++;
    return resultado!;
  }
}

Widget _app(Widget child) => ChangeNotifierProvider(
      create: (_) => SessionState(store: MemoryCredentialStore()),
      child: MaterialApp(home: child),
    );

void main() {
  group('PagoScreen', () {
    testWidgets('métodos sin efectivo, simulación y sin datos reales', (tester) async {
      final api = FakePagosApi()..resultado = _pago();
      await tester.pumpWidget(_app(PagoScreen(nroVenta: 11, api: api)));
      await tester.pumpAndSettle();
      expect(find.text('Pago'), findsWidgets);
      expect(find.textContaining('Entorno de prueba'), findsOneWidget);
      expect(find.text('Efectivo'), findsNothing);
      expect(find.text('CVV'), findsNothing);
      expect(find.text('PAN'), findsNothing);
      await tester.tap(find.text('Realizar pago'));
      await tester.pumpAndSettle();
      expect(api.nroUsado, 11);
      expect(api.metodoUsado, 'tarjeta');
      expect(find.textContaining('Compra completada.'), findsOneWidget);
      expect(find.textContaining('CU14'), findsNothing);
    });

    testWidgets('error funcional ante fallo', (tester) async {
      final api = FakePagosApi()..falla = const ApiException(409, 'disponibilidad_insuficiente');
      await tester.pumpWidget(_app(PagoScreen(nroVenta: 11, api: api)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Realizar pago'));
      await tester.pumpAndSettle();
      expect(find.text('No hay disponibilidad suficiente en la sucursal elegida.'), findsOneWidget);
    });
  });

  group('EstadoPagoScreen', () {
    testWidgets('rechazado orienta al carrito', (tester) async {
      final api = FakePagosApi();
      await tester.pumpWidget(_app(EstadoPagoScreen(pago: _pago(estado: 'rechazado', referencia: null), api: api)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pago rechazado.'), findsOneWidget);
      expect(find.text('Volver al carrito'), findsOneWidget);
      expect(find.textContaining('Compra completada.'), findsNothing);
    });

    testWidgets('pendiente permite consultar estado', (tester) async {
      final api = FakePagosApi()..resultado = _pago();
      await tester.pumpWidget(_app(
          EstadoPagoScreen(pago: _pago(estado: 'pendiente', referencia: null), api: api)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pago pendiente:'), findsOneWidget);
      await tester.tap(find.text('Consultar estado'));
      await tester.pumpAndSettle();
      expect(api.procesarLlamadas, 1);
      expect(find.textContaining('Compra completada.'), findsOneWidget);
    });
  });
}
