import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../soporte/ambiente.dart';
import '../../soporte/datos_falsos.dart';
import '../../soporte/repositorios_falsos.dart';

void main() {
  testWidgets('una recomendación de CU17 abre el detalle de CU10', (
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

    // La tarjeta recomendada navega al flujo normal del catálogo (CU10).
    await tester.tap(find.text('Polera Nike Pro').first);
    await tester.pumpAndSettle();

    expect(find.text('Detalle de polera'), findsOneWidget);
    expect(find.text('Modelo de polera: Deportiva'), findsOneWidget);
    expect(
      find.widgetWithText(ElevatedButton, 'Agregar al carrito'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Reservar en sucursal'),
      findsOneWidget,
    );
  });
}
