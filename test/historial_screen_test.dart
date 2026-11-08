import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:liveclothesshop_mobile/core/api_client.dart';
import 'package:liveclothesshop_mobile/core/credential_store.dart';
import 'package:liveclothesshop_mobile/core/session.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu15_historial_compra/historial_screen.dart';
import 'caja_screen_test.dart' show LegacyQueue, identity;

void main(){
  SessionState session(ApiClient api)=>SessionState(api:api,store:MemoryCredentialStore(),queueStorage:LegacyQueue())
    ..user=SessionUser.fromJson(identity('C',[]))..status=SessionStatus.authenticated;
  Widget screen(SessionState state,ApiClient api)=>ChangeNotifierProvider.value(value:state,
    child:MaterialApp(home:HistorialScreen(api:api)));

  testWidgets('historial abre detalle con importes históricos del servidor',(tester) async{
    final api=ApiClient(httpClient:MockClient((request)async=>http.Response(jsonEncode(
      request.url.path.endsWith('/7')?{
        'nroVenta':7,'estado':'registrada','estadoPago':'aprobado','total':'22.20','descAplicado':'0.00',
        'items':[{'producto':'Camisa histórica','cantidad':2,'precioUnitario':'11.10'}],
        'pago':{'referencia':'MOCK-7'},
      }:{'items':[{'nroVenta':7,'monto':'22.20','fechaHora':'2026-11-08','estadoPago':'aprobado'}],'total':1}),200)));
    await tester.pumpWidget(screen(session(api),api));await tester.pumpAndSettle();
    await tester.tap(find.text('Compra 7 · 22.20'));await tester.pumpAndSettle();
    expect(find.text('Camisa histórica'),findsOneWidget);
    expect(find.text('2 × 11.10'),findsOneWidget);
    expect(find.textContaining('MOCK-7'),findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());api.close();
  });

  testWidgets('respuesta tardía de otra sesión no aparece después del logout',(tester) async{
    final pending=Completer<http.Response>();
    final api=ApiClient(httpClient:MockClient((request)async=>request.url.path.endsWith('/logout')
      ?http.Response('{}',200):pending.future));
    final state=session(api);
    await tester.pumpWidget(screen(state,api));await tester.pump();
    await state.logout();await tester.pump();
    pending.complete(http.Response('{"items":[{"nroVenta":99,"monto":"999","fechaHora":"ayer"}],"total":1}',200));
    await tester.pumpAndSettle();
    expect(find.textContaining('Compra 99'),findsNothing);
    expect(find.text('Inicia sesión como cliente para consultar tus compras.'),findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());api.close();
  });

  testWidgets('401 elimina sesión y no conserva compras visibles',(tester)async{
    final api=ApiClient(httpClient:MockClient((request)async=>http.Response('{}',request.url.path.endsWith('/logout')?200:401)));
    final state=session(api);
    await tester.pumpWidget(screen(state,api));await tester.pumpAndSettle();
    expect(state.isAuthenticated,isFalse);
    expect(find.text('Inicia sesión como cliente para consultar tus compras.'),findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());api.close();
  });
}
