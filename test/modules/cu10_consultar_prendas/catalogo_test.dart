import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liveclothesshop_mobile/core/errors/app_exception.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu10_consultar_prendas/screens/catalogo_screen.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu17_recomendaciones/screens/recomendaciones_screen.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/shared/widgets/producto_card.dart';

import '../../soporte/ambiente.dart';
import '../../soporte/datos_falsos.dart';
import '../../soporte/repositorios_falsos.dart';

void main() {
  List<Override> conSesion({
    CatalogoRepositoryFalso? catalogo,
    RecomendacionesRepositoryFalso? recomendaciones,
  }) => overridesRepositorios(
    sesion: SesionRepositoryFalso(sesion: sesionFalsa()),
    catalogo: catalogo,
    recomendaciones: recomendaciones,
  );

  group('CU10 catálogo', () {
    testWidgets('muestra carga y luego las poleras con su modelo', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: conSesion(),
          child: const MaterialApp(home: CatalogoScreen()),
        ),
      );
      await tester.pump();
      expect(find.text('Cargando poleras…'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(ProductoCard), findsOneWidget);
      expect(find.text('Polera Nike Pro'), findsOneWidget);
      expect(find.text('Modelo: Deportiva'), findsOneWidget);
      expect(find.textContaining('USD 45,00'), findsWidgets);
    });

    testWidgets('error del backend con reintento', (tester) async {
      final catalogo = CatalogoRepositoryFalso(
        error: const AppException(
          AppErrorKind.server,
          'Ocurrió un error en la tienda. Inténtalo más tarde.',
        ),
      );
      await montarPantalla(
        tester,
        conSesion(catalogo: catalogo),
        const CatalogoScreen(),
      );
      expect(
        find.text('Ocurrió un error en la tienda. Inténtalo más tarde.'),
        findsOneWidget,
      );

      catalogo.error = null;
      await tester.tap(find.widgetWithText(OutlinedButton, 'Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Polera Nike Pro'), findsOneWidget);
      expect(catalogo.llamadas, greaterThanOrEqualTo(2));
    });
  });

  group('CU17 recomendaciones', () {
    testWidgets(
      'estado de carga, resultado personalizado y motivos del backend',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: conSesion(),
            child: const MaterialApp(home: RecomendacionesScreen()),
          ),
        );
        await tester.pump();
        expect(find.text('Buscando recomendaciones para ti…'), findsOneWidget);

        await tester.pumpAndSettle();
        expect(
          find.text(
            'Seleccionamos estas poleras según tus compras, reservas y productos de interés.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Similar a los modelos de polera que prefieres'),
          findsOneWidget,
        );
        expect(find.byType(ProductoCard), findsOneWidget);
      },
    );

    testWidgets('fallback general cuando el cliente no tiene perfil', (
      tester,
    ) async {
      await montarPantalla(
        tester,
        conSesion(
          recomendaciones: RecomendacionesRepositoryFalso(tipo: 'general'),
        ),
        const RecomendacionesScreen(),
      );
      expect(
        find.text(
          'Todavía estamos conociendo tus gustos. Estas son algunas poleras populares que podrían interesarte.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('sin recomendaciones disponibles muestra el aviso', (
      tester,
    ) async {
      await montarPantalla(
        tester,
        conSesion(
          recomendaciones: RecomendacionesRepositoryFalso(sinItems: true),
        ),
        const RecomendacionesScreen(),
      );
      expect(
        find.text('No hay recomendaciones disponibles en este momento.'),
        findsOneWidget,
      );
    });

    testWidgets('error de CU17 con reintento', (tester) async {
      final recomendaciones = RecomendacionesRepositoryFalso(
        error: const AppException(
          AppErrorKind.network,
          'No se pudo conectar con la tienda. Revisa tu conexión.',
        ),
      );
      await montarPantalla(
        tester,
        conSesion(recomendaciones: recomendaciones),
        const RecomendacionesScreen(),
      );
      expect(find.textContaining('No se pudo conectar'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Reintentar'), findsOneWidget);
    });
  });
}
