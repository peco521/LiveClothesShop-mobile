import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu14_pago_electronico/screens/pago_screen.dart';

import '../../soporte/ambiente.dart';
import '../../soporte/datos_falsos.dart';
import '../../soporte/repositorios_falsos.dart';

void main() {
  testWidgets('abre Stripe Checkout y consulta el estado real al backend', (
    tester,
  ) async {
    final launcher = CheckoutLauncherFalso();
    final pagos = PagoRepositoryFalso(
      checkoutUrl: 'https://checkout.stripe.com/c/pay/test',
      estadoFinal: 'aprobado',
    );
    await montarPantalla(
      tester,
      overridesRepositorios(
        sesion: SesionRepositoryFalso(sesion: sesionFalsa()),
        compra: CompraRepositoryFalso(),
        pago: pagos,
        launcher: launcher,
      ),
      const PagoScreen(nroVenta: 10),
    );

    // CU14 nunca pide datos de tarjeta: Stripe Checkout los gestiona.
    expect(find.textContaining('no solicita ni almacena'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('USD 81,00'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Pagar con Stripe'));
    await tester.pumpAndSettle();
    expect(pagos.iniciados, 1);
    expect(launcher.abiertas.single, 'https://checkout.stripe.com/c/pay/test');

    // Volver de Stripe no aprueba nada: el estado lo confirma el backend.
    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Ya pagué: verificar estado'),
    );
    await tester.pumpAndSettle();
    expect(pagos.reconciliados, 1);
    expect(find.textContaining('Pago aprobado'), findsWidgets);
    expect(
      find.widgetWithText(OutlinedButton, 'Ver mis compras'),
      findsOneWidget,
    );
  });

  testWidgets('un pago rechazado se informa sin éxito falso', (tester) async {
    final pagos = PagoRepositoryFalso(estadoFinal: 'rechazado');
    await montarPantalla(
      tester,
      overridesRepositorios(
        sesion: SesionRepositoryFalso(sesion: sesionFalsa()),
        compra: CompraRepositoryFalso(),
        pago: pagos,
      ),
      const PagoScreen(nroVenta: 10),
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'Pagar con Stripe'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Ya pagué: verificar estado'),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('rechazado'), findsWidgets);
    expect(
      find.widgetWithText(OutlinedButton, 'Ver mis compras'),
      findsNothing,
    );
  });
}
