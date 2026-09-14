import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:liveclothesshop_mobile/core/api_client.dart';
import 'package:liveclothesshop_mobile/core/credential_store.dart';
import 'package:liveclothesshop_mobile/core/session.dart';
import 'package:liveclothesshop_mobile/modules/seguridad_accesos/login_screen.dart';

const _token = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmno12';

Widget _app(SessionState session) => ChangeNotifierProvider.value(
      value: session,
      child: MaterialApp(
        routes: {
          '/login': (_) => const LoginScreen(),
          '/tienda': (_) => const Scaffold(body: Text('Catálogo')),
        },
        home: const LoginScreen(),
      ),
    );

void main() {
  group('LoginScreen', () {
    testWidgets('valida correo y contraseña vacíos', (tester) async {
      final session = SessionState(store: MemoryCredentialStore());
      await tester.pumpWidget(_app(session));
      await tester.tap(find.text('Entrar'));
      await tester.pump();
      expect(find.text('Ingresa un correo válido'), findsOneWidget);
      expect(find.text('Ingresa tu contraseña'), findsOneWidget);
    });

    testWidgets('login válido navega a tienda sin mostrar códigos', (tester) async {
      final api = ApiClient(
        httpClient: MockClient((request) async => http.Response(
            jsonEncode({
              'usuario': {'idUsuario': 'c1', 'nombres': 'Ana', 'correo': 'ana@example.com'},
              'rol': {'nro': 'cliente', 'descripcion': 'Cliente'},
              'permisos': [],
              'expiraEn': '2030-01-01T00:00:00Z',
            }),
            200,
            headers: {'set-cookie': 'liveclothes_session=$_token; Path=/api; HttpOnly'})),
        baseUrl: 'http://test',
        origin: 'http://test',
      );
      final session = SessionState(api: api, store: MemoryCredentialStore());
      await tester.pumpWidget(_app(session));
      await tester.enterText(find.byType(TextFormField).at(0), 'ana@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'secreta123456');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(find.text('Catálogo'), findsOneWidget);
      expect(find.textContaining('CU10'), findsNothing);
    });
  });
}
