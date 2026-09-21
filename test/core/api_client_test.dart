import 'package:flutter_test/flutter_test.dart';
import 'package:liveclothesshop_mobile/core/errors/app_exception.dart';

import '../soporte/adaptador_falso.dart';
import '../soporte/ambiente.dart';

void main() {
  test('la sesión por cookie se guarda y se reenvía automáticamente', () async {
    final (client, adaptador) = await clienteDePrueba({
      'POST /auth/login/cliente': {
        'status': 200,
        'data': sesionJson(),
        'setCookie': cookieSesion(),
      },
      'GET /auth/me': {'status': 200, 'data': sesionJson()},
    });

    await client.post<Map<String, dynamic>>(
      '/auth/login/cliente',
      body: {
        'correo': 'ana@example.com',
        'contrasena': 'Frase de prueba larga 123!',
      },
    );
    expect(await client.cookies.loadForRequest(uriApi(client)), isNotEmpty);

    await client.get<Map<String, dynamic>>('/auth/me');
    final reenvio = adaptador.ultima('GET', '/auth/me')!;
    // La cookie HttpOnly viaja de vuelta sin que Dart lea su valor.
    expect(
      reenvio.headers.toString(),
      contains('liveclothes_session=$credencialSesion'),
    );
    // Nunca se combinan cookie y Bearer: el backend rechaza esa solicitud.
    expect(reenvio.headers.containsKey('authorization'), isFalse);
  });

  test('los métodos que escriben envían Origin y X-CSRF-Protection', () async {
    final (client, adaptador) = await clienteDePrueba({
      'POST /cliente/carrito/items': {
        'status': 201,
        'data': {'idCarrito': 1, 'items': []},
      },
      'GET /cliente/carrito': {
        'status': 200,
        'data': {'idCarrito': null, 'items': []},
      },
    });

    await client.post<Map<String, dynamic>>(
      '/cliente/carrito/items',
      body: {'idVar': 'v1', 'cantidad': 1},
    );
    final post = adaptador.ultima('POST', '/cliente/carrito/items')!;
    expect(post.headers['X-CSRF-Protection'], '1');
    expect(post.headers['Origin'], 'http://localhost:4200');

    await client.get<Map<String, dynamic>>('/cliente/carrito');
    final get = adaptador.ultima('GET', '/cliente/carrito')!;
    expect(get.headers.containsKey('X-CSRF-Protection'), isFalse);
  });

  test('los errores del backend se normalizan sin detalles técnicos', () async {
    final (client, _) = await clienteDePrueba({
      'GET /cliente/reservas/9': {
        'status': 404,
        'data': errorJson('reserva_no_encontrada', 'x'),
      },
      'GET /cliente/carrito': {
        'status': 401,
        'data': errorJson('autenticacion_rechazada', 'x'),
      },
      'POST /cliente/carrito/items': {
        'status': 409,
        'data': errorJson(
          'compra_pendiente',
          'Tienes una compra pendiente de pago',
        ),
      },
    });

    await expectLater(
      client.get<Object?>('/cliente/reservas/9'),
      throwsA(
        isA<AppException>()
            .having((e) => e.kind, 'kind', AppErrorKind.notFound)
            .having((e) => e.code, 'code', 'reserva_no_encontrada'),
      ),
    );
    await expectLater(
      client.get<Object?>('/cliente/carrito'),
      throwsA(
        isA<AppException>().having(
          (e) => e.isUnauthorized,
          'unauthorized',
          isTrue,
        ),
      ),
    );
    await expectLater(
      client.post<Object?>('/cliente/carrito/items'),
      throwsA(
        isA<AppException>()
            .having((e) => e.kind, 'kind', AppErrorKind.conflict)
            .having(
              (e) => e.message,
              'mensaje de negocio',
              'Tienes una compra pendiente de pago',
            ),
      ),
    );
  });

  test(
    'un 401 avisa a la capa de sesión y limpiar cookies borra la sesión',
    () async {
      final (client, _) = await clienteDePrueba({
        'GET /auth/me': {
          'status': 401,
          'data': errorJson('autenticacion_rechazada', 'x'),
        },
      });
      final avisos = <void>[];
      final suscripcion = client.onUnauthorized.listen(avisos.add);

      await expectLater(
        client.get<Object?>('/auth/me'),
        throwsA(isA<AppException>()),
      );
      await client.clearCookies();
      await Future<void>.delayed(Duration.zero);

      expect(avisos, hasLength(1));
      expect(await client.cookies.loadForRequest(uriApi(client)), isEmpty);
      await suscripcion.cancel();
      client.dispose();
    },
  );
}
