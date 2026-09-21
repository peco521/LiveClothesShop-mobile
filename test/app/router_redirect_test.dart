import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../soporte/ambiente.dart';
import '../soporte/datos_falsos.dart';
import '../soporte/repositorios_falsos.dart';

void main() {
  testWidgets('sin sesión, cualquier ruta privada lleva al login', (
    tester,
  ) async {
    await montarApp(
      tester,
      overridesRepositorios(sesion: SesionRepositoryFalso()),
    );

    expect(find.text('Iniciar sesión'), findsWidgets);
    expect(find.byType(NavigationBar), findsNothing);

    // Deep link directo a una ruta privada: la guarda la bloquea igual.
    // El contexto debe estar DENTRO del Router (MaterialApp.router lo monta por
    // debajo de MaterialApp), así que se toma el Scaffold de la página visible.
    final contexto = tester.element(find.byType(Scaffold).first);
    GoRouter.of(contexto).go('/carrito');
    await tester.pumpAndSettle();
    expect(find.text('Cargando tu carrito…'), findsNothing);
    expect(
      find.text('Ingresa para ver el catálogo de poleras y tus pedidos.'),
      findsOneWidget,
    );
  });

  testWidgets('con sesión se abre el catálogo con la barra inferior (CU10)', (
    tester,
  ) async {
    await montarApp(
      tester,
      overridesRepositorios(
        sesion: SesionRepositoryFalso(sesion: sesionFalsa()),
      ),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Catálogo de poleras'), findsOneWidget);
    expect(find.text('Polera Nike Pro'), findsWidgets);
    for (final opcion in [
      'Inicio',
      'Para ti',
      'Reservas',
      'Carrito',
      'Cuenta',
    ]) {
      expect(find.text(opcion), findsOneWidget);
    }
  });

  testWidgets('la pestaña "Para ti" abre CU17 con recomendaciones', (
    tester,
  ) async {
    await montarApp(
      tester,
      overridesRepositorios(
        sesion: SesionRepositoryFalso(sesion: sesionFalsa()),
      ),
    );

    await tester.tap(find.text('Para ti'));
    await tester.pumpAndSettle();

    expect(find.text('Recomendaciones para ti'), findsWidgets);
    expect(
      find.text(
        'Seleccionamos estas poleras según tus compras, reservas y productos de interés.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'cerrar sesión desde Mi cuenta vuelve al login y limpia la sesión',
    (tester) async {
      final sesion = SesionRepositoryFalso(sesion: sesionFalsa());
      await montarApp(tester, overridesRepositorios(sesion: sesion));

      await tester.tap(find.text('Cuenta'));
      await tester.pumpAndSettle();
      expect(find.text('Ana Pérez'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(sesion.logouts, 1);
      expect(find.text('Iniciar sesión'), findsWidgets);
      expect(find.byType(NavigationBar), findsNothing);
    },
  );
}
