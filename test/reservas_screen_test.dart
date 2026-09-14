import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:liveclothesshop_mobile/core/api_error.dart';
import 'package:liveclothesshop_mobile/core/credential_store.dart';
import 'package:liveclothesshop_mobile/core/session.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu11_gestionar_reserva/data/reservas_api.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu11_gestionar_reserva/models/reserva.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu11_gestionar_reserva/screens/detalle_reserva_screen.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu11_gestionar_reserva/screens/mis_reservas_screen.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu11_gestionar_reserva/screens/nueva_reserva_screen.dart';

ReservaDetalle _reserva({String estado = 'pendiente', bool vencida = false}) => ReservaDetalle(
      nroReserva: 7,
      fecha: '2026-09-20',
      hora: '10:00:00',
      estado: estado,
      sucursal: const ReservaSucursal(nro: 1, nombre: 'Central', ciudad: 'La Paz'),
      items: const [
        ReservaItem(idDetalle: 1, idVar: 'v1', sku: 'SKU-1', producto: 'Camisa Oxford', cantidad: 2),
      ],
      totalUnidades: 2,
      vencida: vencida,
    );

class FakeReservasApi extends ReservasApi {
  FakeReservasApi() : super(credential: () => 'cred');

  ReservasListado? pagina;
  Object? falla;
  ReservaDetalle? detalleObj;
  ReservaDetalle? canceladaObj;
  List<SucursalCliente> sucursalesObj = const [];
  int cancelarLlamadas = 0;
  Map<String, dynamic>? creado;

  @override
  Future<ReservasListado> listar({String? estado, int offset = 0, int limit = 20}) async {
    if (falla != null) throw falla!;
    return pagina!;
  }

  @override
  Future<ReservaDetalle> detalle(int nro) async {
    if (falla != null) throw falla!;
    return detalleObj!;
  }

  @override
  Future<ReservaDetalle> cancelar(int nro) async {
    cancelarLlamadas++;
    return canceladaObj!;
  }

  @override
  Future<ReservaDetalle> crear(ReservaCrear input) async {
    creado = input.toJson();
    return detalleObj!;
  }

  @override
  Future<List<SucursalCliente>> sucursales() async => sucursalesObj;

  @override
  Future<List<HorarioRango>> horarios(int nroSuc) async => const [];
}

Widget _app(Widget child) => ChangeNotifierProvider(
      create: (_) => SessionState(store: MemoryCredentialStore()),
      child: MaterialApp(home: child),
    );

void main() {
  group('MisReservasScreen', () {
    testWidgets('muestra lista sin códigos internos', (tester) async {
      final api = FakeReservasApi()
        ..pagina = ReservasListado(items: [_reserva()], total: 1);
      await tester.pumpWidget(_app(MisReservasScreen(api: api)));
      await tester.pumpAndSettle();
      expect(find.text('Mis reservas'), findsOneWidget);
      expect(find.text('Reserva 7 · Central'), findsOneWidget);
      expect(find.text('1 reservas encontradas.'), findsOneWidget);
      expect(find.textContaining('CU11'), findsNothing);
    });

    testWidgets('vacío funcional', (tester) async {
      final api = FakeReservasApi()..pagina = const ReservasListado(items: [], total: 0);
      await tester.pumpWidget(_app(MisReservasScreen(api: api)));
      await tester.pumpAndSettle();
      expect(find.text('No tienes reservas registradas.'), findsOneWidget);
    });

    testWidgets('error con reintento', (tester) async {
      final api = FakeReservasApi()..falla = const ApiException(500, 'error_interno');
      await tester.pumpWidget(_app(MisReservasScreen(api: api)));
      await tester.pumpAndSettle();
      expect(find.text('No se pudo completar la operación. Inténtalo nuevamente.'), findsOneWidget);
      api
        ..falla = null
        ..pagina = ReservasListado(items: [_reserva()], total: 1);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Reserva 7 · Central'), findsOneWidget);
    });
  });

  group('NuevaReservaScreen', () {
    testWidgets('prellena variante y valida sucursal', (tester) async {
      final api = FakeReservasApi()
        ..sucursalesObj = const [
          SucursalCliente(nro: 1, nombre: 'Central', direccion: 'D1', ciudad: 'La Paz'),
        ]
        ..detalleObj = _reserva();
      await tester.pumpWidget(_app(
          NuevaReservaScreen(api: api, idVarInicial: 'v1', cantidadInicial: 2)));
      await tester.pumpAndSettle();
      expect(find.text('Nueva reserva'), findsOneWidget);
      final campos = tester.widgetList<TextFormField>(find.byType(TextFormField));
      expect(campos.any((c) => c.controller?.text == 'v1'), isTrue);
      await tester.tap(find.text('Confirmar reserva'));
      await tester.pump();
      expect(find.text('Selecciona una sucursal'), findsOneWidget);
      expect(api.creado, isNull);
      expect(find.textContaining('CU11'), findsNothing);
    });
  });

  group('DetalleReservaScreen', () {
    testWidgets('cancelación en dos pasos actualiza estado', (tester) async {
      final api = FakeReservasApi()
        ..detalleObj = _reserva()
        ..canceladaObj = _reserva(estado: 'cancelada');
      await tester.pumpWidget(_app(DetalleReservaScreen(nro: 7, api: api)));
      await tester.pumpAndSettle();
      expect(find.text('Reserva 7'), findsOneWidget);
      expect(find.text('Camisa Oxford'), findsOneWidget);
      await tester.tap(find.text('Cancelar reserva'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar cancelación'));
      await tester.pumpAndSettle();
      expect(api.cancelarLlamadas, 1);
      expect(find.text('cancelada'), findsWidgets);
      expect(find.textContaining('CU11'), findsNothing);
    });

    testWidgets('sin botón cancelar si no está pendiente', (tester) async {
      final api = FakeReservasApi()..detalleObj = _reserva(estado: 'confirmada');
      await tester.pumpWidget(_app(DetalleReservaScreen(nro: 7, api: api)));
      await tester.pumpAndSettle();
      expect(find.text('Cancelar reserva'), findsNothing);
    });
  });
}
