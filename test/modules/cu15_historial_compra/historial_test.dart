import 'package:flutter_test/flutter_test.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu15_historial_compra/screens/historial_screen.dart';

import '../../soporte/ambiente.dart';
import '../../soporte/datos_falsos.dart';
import '../../soporte/repositorios_falsos.dart';

void main() {
  testWidgets('el historial muestra las compras y su detalle', (tester) async {
    await montarApp(
      tester,
      overridesRepositorios(
        sesion: SesionRepositoryFalso(sesion: sesionFalsa()),
      ),
    );

    await tester.tap(find.text('Cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mis compras'));
    await tester.pumpAndSettle();

    expect(find.text('Compra #10'), findsOneWidget);
    expect(find.textContaining('USD 81,00'), findsWidgets);
    expect(find.text('Pago aprobado'), findsOneWidget);

    await tester.tap(find.text('Compra #10'));
    await tester.pumpAndSettle();
    expect(find.text('Productos'), findsOneWidget);
    expect(find.text('Polera Nike Pro'), findsOneWidget);
    expect(find.textContaining('Registrada'), findsWidgets);
  });

  testWidgets('sin compras se muestra el mensaje del backend', (tester) async {
    await montarPantalla(
      tester,
      overridesRepositorios(
        sesion: SesionRepositoryFalso(sesion: sesionFalsa()),
        historial: HistorialRepositoryFalso(sinCompras: true),
      ),
      const HistorialScreen(),
    );
    expect(find.text('Aún no tienes compras'), findsOneWidget);
    expect(find.text('No existen compras en tu historial'), findsOneWidget);
  });
}
