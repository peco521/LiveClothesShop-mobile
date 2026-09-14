import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liveclothesshop_mobile/core/api_client.dart';
import 'package:liveclothesshop_mobile/core/credential_store.dart';
import 'package:liveclothesshop_mobile/core/session.dart';

const _token = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmno12'; // 43 caracteres

Map<String, dynamic> _me() => {
      'usuario': {'idUsuario': 'c1', 'nombres': 'Ana', 'correo': 'ana@example.com'},
      'rol': {'nro': 'cliente', 'descripcion': 'Cliente'},
      'permisos': [],
      'expiraEn': '2030-01-01T00:00:00Z',
    };

SessionState _state(MockClient client, CredentialStore store) => SessionState(
      api: ApiClient(httpClient: client, baseUrl: 'http://test', origin: 'http://test'),
      store: store,
    );

void main() {
  group('SessionState', () {
    test('login guarda credencial de Set-Cookie y publica usuario', () async {
      final store = MemoryCredentialStore();
      final client = MockClient((request) async {
        expect(request.url.path, '/api/auth/login');
        expect(request.headers['Origin'], isNotNull);
        expect(request.headers['X-CSRF-Protection'], '1');
        return http.Response(jsonEncode(_me()), 200,
            headers: {'set-cookie': 'liveclothes_session=$_token; Path=/api; HttpOnly'});
      });
      final session = _state(client, store);
      await session.login('ana@example.com', 'secreta');
      expect(session.isAuthenticated, isTrue);
      expect(session.user?.correo, 'ana@example.com');
      expect(await store.read(), _token);
      expect(session.error, isNull);
    });

    test('login sin credencial en cabecera no autentica', () async {
      final store = MemoryCredentialStore();
      final client = MockClient((_) async => http.Response(jsonEncode(_me()), 200));
      final session = _state(client, store);
      await session.login('ana@example.com', 'secreta');
      expect(session.isAuthenticated, isFalse);
      expect(await store.read(), isNull);
    });

    test('login 401 expone mensaje funcional', () async {
      final session = _state(
        MockClient((_) async => http.Response('{"error":{"code":"x","message":"y"}}', 401)),
        MemoryCredentialStore(),
      );
      await session.login('a@b.c', 'mala');
      expect(session.isAuthenticated, isFalse);
      expect(session.error, contains('sesión'));
    });

    test('restore sin credencial queda no autenticado', () async {
      final session = _state(MockClient((_) async => http.Response('', 500)), MemoryCredentialStore());
      await session.restore();
      expect(session.isAuthenticated, isFalse);
    });

    test('restore con Bearer válido recupera usuario', () async {
      final store = MemoryCredentialStore();
      await store.write(_token);
      final client = MockClient((request) async {
        expect(request.url.path, '/api/auth/me');
        expect(request.headers['Authorization'], 'Bearer $_token');
        return http.Response(jsonEncode(_me()), 200);
      });
      final session = _state(client, store);
      await session.restore();
      expect(session.isAuthenticated, isTrue);
      expect(session.user?.rol, 'cliente');
    });

    test('logout limpia estado y almacenamiento', () async {
      final store = MemoryCredentialStore();
      await store.write(_token);
      final client = MockClient((request) async {
        expect(request.url.path, '/api/auth/logout');
        return http.Response('', 204);
      });
      final session = _state(client, store);
      await session.logout();
      expect(session.isAuthenticated, isFalse);
      expect(await store.read(), isNull);
    });
  });
}
