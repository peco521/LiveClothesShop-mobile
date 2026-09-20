import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../soporte/ambiente.dart';
import '../../soporte/datos_falsos.dart';
import '../../soporte/repositorios_falsos.dart';

void main() {
  testWidgets('lista las reservas y permite cancelar desde el detalle', (
    tester,
  ) async {
    final reservas = ReservasRepositoryFalso();
    await montarApp(
      tester,
      overridesRepositorios(
        sesion: SesionRepositoryFalso(sesion: sesionFalsa()),
        reservas: reservas,
      ),
    );

    await tester.tap(find.text('Reservas'));
    await tester.pumpAndSettle();
    expect(find.text('Reserva #5'), findsOneWidget);
    expect(find.text('Confirmada'), findsOneWidget);
    expect(find.textContaining('21/09/2026'), findsOneWidget);

    await tester.tap(find.text('Reserva #5'));
    await tester.pumpAndSettle();
    expect(find.text('Prendas reservadas'), findsOneWidget);
    expect(find.text('Polera Nike Pro'), findsOneWidget);
    expect(find.textContaining('× 2'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar reserva'));
    await tester.pumpAndSettle();

    expect(reservas.canceladas, 1);
    expect(find.text('La reserva fue cancelada.'), findsOneWidget);
  });

  testWidgets('sin reservas muestra el estado vacío', (tester) async {
    await montarApp(
      tester,
      overridesRepositorios(
        sesion: SesionRepositoryFalso(sesion: sesionFalsa()),
        reservas: ReservasRepositoryFalso(sinReservas: true),
      ),
    );

    await tester.tap(find.text('Reservas'));
    await tester.pumpAndSettle();
    expect(find.text('Aún no tienes reservas'), findsOneWidget);
  });
}
