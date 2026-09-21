import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:liveclothesshop_mobile/app/app.dart';
import 'package:liveclothesshop_mobile/core/network/api_client.dart';
import 'package:liveclothesshop_mobile/core/network/providers.dart';
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

/// Lanzador de Stripe falso: registra la URL sin abrir el navegador real.
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
///
/// El tipo de la lista se deja inferir a propósito: flutter_riverpod 3.4 no
/// exporta su clase `Override`, así que nombrarla sería un error de análisis.
// ignore: prefer_function_declarations_over_variables — flutter_riverpod 3.4 no exporta `Override`.
final overridesRepositorios =
    ({
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
      sesionRepositoryProvider.overrideWithValue(
        sesion ?? SesionRepositoryFalso(),
      ),
      catalogoRepositoryProvider.overrideWithValue(
        catalogo ?? CatalogoRepositoryFalso(),
      ),
      carritoRepositoryProvider.overrideWithValue(
        carrito ?? CarritoRepositoryFalso(),
      ),
      reservasRepositoryProvider.overrideWithValue(
        reservas ?? ReservasRepositoryFalso(),
      ),
      compraRepositoryProvider.overrideWithValue(
        compra ?? CompraRepositoryFalso(),
      ),
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
///
/// Igual que `main()`, sobrescribe `apiClientProvider` (por diseño lanza
/// `UnimplementedError` si nadie lo sustituye) con un cliente en memoria.
Future<void> montarApp(WidgetTester tester, dynamic overrides) async {
  final client = await ApiClient.create(cookieJar: CookieJar());
  await tester.pumpWidget(
    ProviderScope(
      retry: sinReintentosAutomaticos,
      overrides: [apiClientProvider.overrideWithValue(client), ...overrides],
      child: const LiveClothesShopApp(),
    ),
  );
  await _estabilizar(tester);
}

/// Monta una pantalla aislada (sin go_router) para probar estados.
Future<void> montarPantalla(
  WidgetTester tester,
  dynamic overrides,
  Widget pantalla,
) async {
  final client = await ApiClient.create(cookieJar: CookieJar());
  await tester.pumpWidget(
    ProviderScope(
      retry: sinReintentosAutomaticos,
      overrides: [apiClientProvider.overrideWithValue(client), ...overrides],
      child: MaterialApp(home: pantalla),
    ),
  );
  await _estabilizar(tester);
}

/// Avanza la UI sin exigir que no queden animaciones: un
/// `CircularProgressIndicator` visible haría fallar `pumpAndSettle`.
Future<void> _estabilizar(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// Contenedor Riverpod con los repositorios falsos y el cliente en memoria.
///
/// Igual que `main()`: `apiClientProvider` nunca se deja sin sustituir.
Future<ProviderContainer> contenedorDePrueba(dynamic overrides) async {
  final client = await ApiClient.create(cookieJar: CookieJar());
  final container = ProviderContainer(
    retry: sinReintentosAutomaticos,
    overrides: [apiClientProvider.overrideWithValue(client), ...overrides],
  );
  addTearDown(container.dispose);
  return container;
}

/// URI de la API con el host real del cliente de pruebas.
///
/// El jar guarda las cookies por host y `Environment.apiBaseUrl` usa el alias
/// del emulador Android (10.0.2.2): asumir `localhost` daría un jar vacío
/// aunque la cookie se haya guardado correctamente.
Uri uriApi(ApiClient client) => Uri.parse(client.dio.options.baseUrl);
