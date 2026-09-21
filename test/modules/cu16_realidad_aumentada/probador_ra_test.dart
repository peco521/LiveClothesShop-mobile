import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liveclothesshop_mobile/app/app.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu16_realidad_aumentada/models/ra_estado.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu16_realidad_aumentada/providers/realidad_aumentada_provider.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu16_realidad_aumentada/screens/probador_ra_screen.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu16_realidad_aumentada/widgets/ra_status_overlay.dart';

import '../../soporte/ambiente.dart';
import '../../soporte/datos_falsos.dart';
import '../../soporte/ra_falsos.dart';
import '../../soporte/repositorios_falsos.dart';

void main() {
  /// Overrides de CU16: cámara falsa, plataforma Android y sin red.
  dynamic overridesRa({
    String? codigoErrorCamara,
    CatalogoRepositoryFalso? catalogo,
    bool soportada = true,
  }) => [
    ...overridesRepositorios(
      sesion: SesionRepositoryFalso(sesion: sesionFalsa()),
      catalogo: catalogo,
    ),
    plataformaRaSoportadaProvider.overrideWithValue(soportada),
    camaraServiceProvider.overrideWithValue(
      CamaraServiceFalso(codigoError: codigoErrorCamara),
    ),
    proveedorImagenRaProvider.overrideWithValue(proveedorImagenFalso),
  ];

  /// Catálogo cuya variante SÍ tiene imagen: así se llega al flujo de cámara.
  CatalogoRepositoryFalso catalogoConImagen() =>
      CatalogoRepositoryFalso(imagenVariante: 'https://cdn.test/polera.png');

  group('CU16 probador virtual (sin cámara real)', () {
    testWidgets('muestra carga mientras se arma el contexto', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          retry: sinReintentosAutomaticos,
          overrides: overridesRa(),
          child: const MaterialApp(
            home: ProbadorRaScreen(idProd: 'p1', idVar: 'v1', talla: 'M'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Preparando el probador virtual…'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('una variante sin imagen se explica sin abrir la cámara', (
      tester,
    ) async {
      await montarPantalla(
        tester,
        overridesRa(),
        const ProbadorRaScreen(idProd: 'p1', idVar: 'v1', talla: 'M'),
      );
      expect(find.text(RaErrorCamara.sinImagen.mensaje), findsOneWidget);
    });

    testWidgets('sin cámaras disponibles avisa y ofrece volver', (
      tester,
    ) async {
      await montarPantalla(
        tester,
        overridesRa(catalogo: catalogoConImagen()),
        const ProbadorRaScreen(idProd: 'p1', idVar: 'v1', talla: 'M'),
      );
      // La textura se decodifica con trabajo real: fuera del reloj simulado.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
      expect(find.text(RaErrorCamara.sinCamara.mensaje), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Volver al producto'),
        findsOneWidget,
      );
    });

    testWidgets('permiso de cámara denegado se explica con claridad', (
      tester,
    ) async {
      await montarPantalla(
        tester,
        overridesRa(
          codigoErrorCamara: 'CameraAccessDenied',
          catalogo: catalogoConImagen(),
        ),
        const ProbadorRaScreen(idProd: 'p1', idVar: 'v1', talla: 'M'),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
      expect(find.text(RaErrorCamara.permisoDenegado.mensaje), findsOneWidget);
    });

    testWidgets('el aviso de pose inválida indica qué hacer', (tester) async {
      await montarPantalla(
        tester,
        overridesRa(),
        const Scaffold(
          body: Center(child: RaStatusOverlay(estado: RaEstadoPose.sinTorso)),
        ),
      );
      expect(find.text(RaEstadoPose.sinTorso.mensaje), findsOneWidget);
    });

    testWidgets('en una plataforma no soportada se explica con claridad', (
      tester,
    ) async {
      await montarPantalla(
        tester,
        overridesRa(soportada: false),
        const ProbadorRaScreen(idProd: 'p1', idVar: 'v1'),
      );
      expect(find.text(RaErrorCamara.noSoportado.mensaje), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Volver al producto'),
        findsOneWidget,
      );
    });

    testWidgets('el detalle de CU10 abre CU16 y permite volver', (
      tester,
    ) async {
      await montarApp(tester, overridesRa());

      await tester.tap(find.text('Polera Nike Pro').first);
      await tester.pumpAndSettle();
      expect(find.text('Detalle de polera'), findsOneWidget);

      // Orden pedido: Agregar al carrito → Probar con RA → Reservar.
      final yCarrito = tester.getTopLeft(find.text('Agregar al carrito')).dy;
      final yProbar = tester
          .getTopLeft(find.text('Probar con realidad aumentada'))
          .dy;
      final yReservar = tester.getTopLeft(find.text('Reservar en sucursal')).dy;
      expect(yProbar, greaterThan(yCarrito));
      expect(yReservar, greaterThan(yProbar));

      await tester.ensureVisible(find.text('Probar con realidad aumentada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Probar con realidad aumentada'));
      await tester.pumpAndSettle();
      expect(find.text('Probador virtual'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Volver al producto'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Detalle de polera'), findsOneWidget);
    });
  });
}
