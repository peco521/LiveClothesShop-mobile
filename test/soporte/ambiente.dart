import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:liveclothesshop_mobile/app/app.dart';
import 'package:liveclothesshop_mobile/core/network/api_client.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu01_registro_cliente/data/registro_repository.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu02_iniciar_sesion/data/sesion_repository.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu04_recuperar_contrasena/data/recuperacion_repository.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu10_consultar_prendas/data/catalogo_repository.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu11_gestionar_reserva/data/reservas_repository.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu12_carrito/data/carrito_repository.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu13_compra_digital/data/compra_repository.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu14_pago_electronico/data/checkout_launcher.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu14_pago_electronico/data/pago_repository.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu15_historial_compra/data/historial_repository.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu17_recomendaciones/data/recomendaciones_repository.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/shared/providers/sesion_provider.dart';

import 'adaptador_falso.dart';
import 'repositorios_falsos.dart';

/// Cliente HTTP de prueba: jar en memoria + adaptador falso (nunca toca la red).
Future<(ApiClient, AdaptadorFalso)> clienteDePrueba(
  Map<String, Map<String, Object?>> respuestas,
) async {
  final adaptador = AdaptadorFalso(respuestas);
  final client = await ApiClient.create(cookieJar: CookieJar());
  client.dio.httpClientAdapter = adaptador;
  return (client, adaptador);
}

/// Lanzador de Stripe falso: registra la URL sin abrir el navegador.
class CheckoutLauncherFalso extends CheckoutLauncher {
  CheckoutLauncherFalso();

  final List<String> abiertas = [];

  @override
  Future<bool> abrir(String? checkoutUrl) async {
    abiertas.add(checkoutUrl ?? '');
    return true;
  }
}

/// Overrides de TODOS los repositorios: ninguna prueba toca el backend real.
List<Override> overridesRepositorios({
  SesionRepositoryFalso? sesion,
  CatalogoRepositoryFalso? catalogo,
  CarritoRepositoryFalso? carrito,
  ReservasRepositoryFalso? reservas,
  CompraRepositoryFalso? compra,
  PagoRepositoryFalso? pago,
  HistorialRepositoryFalso? historial,
  RecomendacionesRepositoryFalso? recomendaciones,
  RegistroRepositoryFalso? registro,
  RecuperacionRepositoryFalso? recuperacion,
  CheckoutLauncherFalso? launcher,
}) => [
  sesionRepositoryProvider.overrideWithValue(sesion ?? SesionRepositoryFalso()),
  catalogoRepositoryProvider.overrideWithValue(
    catalogo ?? CatalogoRepositoryFalso(),
  ),
  carritoRepositoryProvider.overrideWithValue(
    carrito ?? CarritoRepositoryFalso(),
  ),
  reservasRepositoryProvider.overrideWithValue(
    reservas ?? ReservasRepositoryFalso(),
  ),
  compraRepositoryProvider.overrideWithValue(compra ?? CompraRepositoryFalso()),
  pagoRepositoryProvider.overrideWithValue(pago ?? PagoRepositoryFalso()),
  historialRepositoryProvider.overrideWithValue(
    historial ?? HistorialRepositoryFalso(),
  ),
  recomendacionesRepositoryProvider.overrideWithValue(
    recomendaciones ?? RecomendacionesRepositoryFalso(),
  ),
  registroRepositoryProvider.overrideWithValue(
    registro ?? RegistroRepositoryFalso(),
  ),
  recuperacionRepositoryProvider.overrideWithValue(
    recuperacion ?? RecuperacionRepositoryFalso(),
  ),
  checkoutLauncherProvider.overrideWithValue(
    launcher ?? CheckoutLauncherFalso(),
  ),
];

/// Monta la app completa (router incluido) con repositorios falsos.
Future<void> montarApp(WidgetTester tester, List<Override> overrides) async {
  await tester.pumpWidget(
    ProviderScope(overrides: overrides, child: const LiveClothesShopApp()),
  );
  await tester.pumpAndSettle();
}

/// Monta una pantalla aislada (sin go_router) para probar estados.
Future<void> montarPantalla(
  WidgetTester tester,
  List<Override> overrides,
  Widget pantalla,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: pantalla),
    ),
  );
  await tester.pumpAndSettle();
}

/// Espera a que la sesión falsa se resuelva (evita depender de la cookie real).
Future<void> iniciarConSesion(
  WidgetTester tester,
  List<Override> overrides,
) async {
  await montarApp(tester, overrides);
  // La primera resolución de sesión dispara la petición de la pantalla inicial.
  await tester.pumpAndSettle();
}
