import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liveclothesshop_mobile/core/errors/app_exception.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu12_carrito/screens/carrito_screen.dart';

import '../../soporte/ambiente.dart';
import '../../soporte/datos_falsos.dart';
import '../../soporte/repositorios_falsos.dart';

void main() {
  List<Override> conSesion(CarritoRepositoryFalso carrito) =>
      overridesRepositorios(
        sesion: SesionRepositoryFalso(sesion: sesionFalsa()),
        carrito: carrito,
      );

  testWidgets('muestra productos, subtotal y permite cambiar cantidades', (
    tester,
  ) async {
    final carrito = CarritoRepositoryFalso();
    await montarPantalla(tester, conSesion(carrito), const CarritoScreen());

    expect(find.text('Polera Nike Pro'), findsOneWidget);
    expect(
      find.text('Talla M · Rojo'),
      findsNothing,
    ); // el SKU y el color van separados
    expect(find.text('SKU SKU-1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.textContaining('USD 90,00'), findsWidgets);

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    expect(carrito.cambios, 1);

    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    await tester.pumpAndSettle();
    expect(carrito.eliminados, 1);
    expect(find.text('Tu carrito está vacío'), findsOneWidget);
  });

  testWidgets('carrito vacío muestra el estado vacío', (tester) async {
    await montarPantalla(
      tester,
      conSesion(CarritoRepositoryFalso(vacio: true)),
      const CarritoScreen(),
    );
    expect(find.text('Tu carrito está vacío'), findsOneWidget);
  });

  testWidgets('un rechazo del backend se avisa sin perder el carrito', (
    tester,
  ) async {
    final carrito = CarritoRepositoryFalso();
    await montarPantalla(tester, conSesion(carrito), const CarritoScreen());

    carrito.error = const AppException(
      AppErrorKind.conflict,
      'La cantidad supera las existencias disponibles de esta variante.',
    );
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'La cantidad supera las existencias disponibles de esta variante.',
      ),
      findsOneWidget,
    );
    expect(find.text('Polera Nike Pro'), findsOneWidget);
  });
}
