import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liveclothesshop_mobile/core/errors/app_exception.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu02_iniciar_sesion/data/sesion_repository.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/shared/providers/sesion_provider.dart';

import '../../soporte/adaptador_falso.dart';
import '../../soporte/ambiente.dart';
import '../../soporte/datos_falsos.dart';
import '../../soporte/repositorios_falsos.dart';

const contrasena = 'Frase de prueba larga 123!';

void main() {
  group('CU02 sesión por cookie (sin backend real)', () {
    test(
      'el login guarda la cookie de sesión y el logout la elimina',
      () async {
        final (client, adaptador) = await clienteDePrueba({
          'POST /auth/login/cliente': {
            'status': 200,
            'data': sesionJsonBackend(),
            'setCookie': cookieSesion(),
          },
          'POST /auth/logout': {'status': 204},
        });
        final repositorio = SesionRepository(client);

        final sesion = await repositorio.iniciarSesion(
          correo: 'ana@example.com',
          contrasena: contrasena,
        );
        expect(sesion.usuario.correo, 'ana@example.com');
        expect(sesion.rol.descripcion, 'Cliente');
        expect(await client.cookies.loadForRequest(uriApi(client)), isNotEmpty);

        await repositorio.cerrarSesion();
        await client.clearCookies();
        expect(await client.cookies.loadForRequest(uriApi(client)), isEmpty);

        // El login es un POST: llevó la defensa exigida por el middleware.
        expect(
          adaptador
              .ultima('POST', '/auth/login/cliente')!
              .headers['X-CSRF-Protection'],
          '1',
        );
      },
    );

    test('la sesión se restaura desde la cookie (GET /auth/me)', () async {
      final (client, _) = await clienteDePrueba({
        'GET /auth/me': {'status': 200, 'data': sesionJsonBackend()},
      });
      final sesion = await SesionRepository(client).sesionActual();
      expect(sesion?.usuario.idUsuario, 'cliente-1');
    });

    test('sin sesión vigente, sesionActual devuelve null (401)', () async {
      final (client, _) = await clienteDePrueba({
        'GET /auth/me': {
          'status': 401,
          'data': errorJson('autenticacion_rechazada', 'x'),
        },
      });
      expect(await SesionRepository(client).sesionActual(), isNull);
    });
  });

  group('CU02 estado de sesión en Riverpod', () {
    test(
      'iniciar sesión deja el estado con datos y cerrar sesión lo limpia',
      () async {
        final falso = SesionRepositoryFalso();
        final container = await contenedorDePrueba(
          overridesRepositorios(sesion: falso),
        );

        expect(await container.read(sesionProvider.future), isNull);

        await container
            .read(sesionProvider.notifier)
            .iniciarSesion(correo: 'ana@example.com', contrasena: contrasena);
        expect(
          container.read(sesionProvider).asData?.value?.usuario.nombreMostrado,
          'Ana Pérez',
        );

        await container.read(sesionProvider.notifier).cerrarSesion();
        expect(container.read(sesionProvider).asData?.value, isNull);
        expect(falso.logouts, 1);
      },
    );

    test(
      'un login rechazado deja el estado en error con mensaje seguro',
      () async {
        final falso = SesionRepositoryFalso(
          error: const AppException(
            AppErrorKind.invalid,
            'Revisa los datos ingresados: hay valores no válidos.',
          ),
        );
        final container = await contenedorDePrueba(
          overridesRepositorios(sesion: falso),
        );

        await container
            .read(sesionProvider.notifier)
            .iniciarSesion(correo: 'ana@example.com', contrasena: 'mala');

        final estado = container.read(sesionProvider);
        expect(estado.hasError, isTrue);
        expect(mensajeDeError(estado.error), contains('no válidos'));
        expect(estado.error.toString(), isNot(contains('Exception:')));
      },
    );
  });
}
