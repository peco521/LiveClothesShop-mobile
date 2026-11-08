import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:liveclothesshop_mobile/core/api_client.dart';
import 'package:liveclothesshop_mobile/core/catalog_repository.dart';
import 'package:liveclothesshop_mobile/core/credential_store.dart';
import 'package:liveclothesshop_mobile/core/offline_database.dart';
import 'package:liveclothesshop_mobile/core/offline_sync.dart';
import 'package:liveclothesshop_mobile/core/session.dart';
import 'package:liveclothesshop_mobile/modules/ventas_reportes/caja_screen.dart';

class LegacyQueue implements OfflineQueueStorage {
  @override Future<String?> read(String key) async=>null;
  @override Future<void> write(String key,String value) async{}
}
Map<String,dynamic> identity(String type,List<String> permissions)=>{
  'empresa':'manaco','plataforma':false,
  'usuario':{'idUsuario':'cash-test','nombres':'Prueba','correo':'test@example.com','tipo':type},
  'rol':{'nro':'test','descripcion':'Prueba'},'permisos':permissions,'expiraEn':'2099-01-01T00:00:00Z'};

void main(){
  sqfliteFfiInit();
  test('estimación de promoción usa centavos HALF_UP por unidad, limitada al precio',(){
    final lines=[{'id':'v','price':'11.11','quantity':2,'promotion':{'tipoDescuento':'porcentaje','valorDescuento':'15.00'}}];
    expect(cashIntent(lines)['descuento'],'3.34');
    expect(cashIntent([{'id':'v','price':'11.11','quantity':2,'promotion':{'tipoDescuento':'montoFijo','valorDescuento':'20.00'}}])['descuento'],'22.22');
  });
  testWidgets('cliente no entra a caja aunque conozca la ruta o tenga CU24 en snapshot', (tester) async{
    final session=SessionState(store:MemoryCredentialStore(),queueStorage:LegacyQueue())
      ..user=SessionUser.fromJson(identity('C',['CU24']))..status=SessionStatus.authenticated;
    await tester.pumpWidget(ChangeNotifierProvider.value(value:session,child:const MaterialApp(home:CajaScreen())));
    expect(find.text('Acceso reservado a cajeros con permiso CU24.'),findsOneWidget);
    expect(find.text('Guardar venta de efectivo pendiente'),findsNothing);
  });

  testWidgets('cajero descarga SQLite y envía el UUID persistido por sync, nunca checkout', (tester) async{
    await tester.runAsync(() async {
    Future<void> waitFor(Finder finder) async {
      for(var attempt=0;attempt<200 && finder.evaluate().isEmpty;attempt++){
        await Future<void>.delayed(const Duration(milliseconds:10));
        await tester.pump();
      }
      expect(finder,findsWidgets);
    }
    final directory=await Directory.systemTemp.createTemp('fashionstore-cash-test-');
    final database=OfflineDatabase(open:()=>OfflineDatabase.openAt(databaseFactoryFfi,'${directory.path}/cash.db'));
    final sent=<Map<String,dynamic>>[];final paths=<String>[];
    final api=ApiClient(httpClient:MockClient((request) async{
      paths.add(request.url.path);
      if(request.url.path=='/api/auth/login/admin'){
        return http.Response(jsonEncode(identity('E',['CU24'])),200,
          headers:{'set-cookie':'liveclothes_session=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmno12; Path=/api; HttpOnly'});
      }
      if(request.url.path=='/api/admin/caja/referencias')return http.Response('{"sucursales":[{"nro":1,"nombre":"Central","ciudad":"SC"}]}',200);
      if(request.url.path=='/api/admin/caja/productos')return http.Response('{"items":[{"idProd":"p1"}]}',200);
      if(request.url.path=='/api/admin/caja/productos/p1'){return http.Response(jsonEncode({
        'idProd':'p1','descripcion':'Camisa de caja','variantes':[{'idVariante':'v1','sku':'s1','precio':'25.00','talla':{'descripcion':'M'},'colores':[]}],
        'disponibilidad':[{'nroSuc':1,'sucursal':'Central','ciudad':'SC','idVariante':'v1','stock':7,'cantDisp':7}]}),200);}
      if(request.url.path=='/api/sync/lote'){
        final operation=(jsonDecode(request.body)['operaciones'] as List).single as Map<String,dynamic>;
        sent.add(operation);
        return http.Response(jsonEncode({'resultados':[{'id':operation['id'],'estado':'sincronizada','nroVenta':99}]}),200);
      }
      return http.Response('{}',404);
    }));
    final session=SessionState(api:api,store:MemoryCredentialStore(),
      queueStorage:SqliteOfflineQueueStorage(database:database,legacy:LegacyQueue()));
    try{
      await session.login('manaco','test@example.com','fictional',staff:true);
      expect(session.user!.isCashier,isTrue);
      await tester.pumpWidget(ChangeNotifierProvider.value(value:session,child:MaterialApp(home:CajaScreen(api:api,repository:CatalogRepository(database:database)))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descargar 20 productos para caja'));await tester.pumpAndSettle();
      await waitFor(find.textContaining('Subconjunto de caja guardado en SQLite.'));
      expect((await (await database.database).query('catalog_variant')).length,1);
      await tester.tap(find.byType(DropdownButtonFormField<String>));await tester.pumpAndSettle();
      await tester.tap(find.text('Camisa de caja · M · 25.00').last);await tester.pumpAndSettle();
      await tester.tap(find.text('Añadir línea'));await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Guardar venta de efectivo pendiente'));
      await tester.tap(find.text('Guardar venta de efectivo pendiente'));await tester.pumpAndSettle();
      for(var attempt=0;attempt<200;attempt++){
        if((await session.sync.list()).any((operation)=>operation.nroVenta==99))break;
        await Future<void>.delayed(const Duration(milliseconds:10));await tester.pump();
      }
      expect(sent,hasLength(1),reason:'La pantalla debe despachar por sync después de persistir en SQLite');
      expect((await session.sync.list()).single.nroVenta,99);
      await tester.scrollUntilVisible(find.text('Ledger de ventas del dispositivo'),150,
        scrollable:find.descendant(of:find.byType(ListView),matching:find.byType(Scrollable)).first);
      await tester.drag(find.byType(ListView),const Offset(0,-250));await tester.pumpAndSettle();
      await waitFor(find.text('Venta 99'));
      expect(sent.length,1);
      expect(sent.single['tipo'],'venta');
      expect(sent.single['datos'],{'metodo':'efectivo','lineas':[{'idVariante':'v1','cantidad':1,'precio':'25.00'}]});
      await database.close();
      final persisted=await session.sync.list();
      expect(persisted.single.id,sent.single['id']);
      expect(persisted.single.nroVenta,99);
      expect(paths.any((path)=>path.contains('/cliente/compras')||path.contains('/cliente/pagos')),isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    }finally{await database.close();api.close();await directory.delete(recursive:true);}
    });
  });

  test('sesión offline vencida no se restaura ni envía cola',() async{
    final store=MemoryCredentialStore();await store.write('fictional');
    await store.writeSessionSnapshot(jsonEncode({...identity('E',['CU24']),'expiraEn':'2020-01-01T00:00:00Z'}));
    final api=ApiClient(httpClient:MockClient((_) async=>throw http.ClientException('offline')));
    final session=SessionState(api:api,store:store,queueStorage:LegacyQueue());
    await session.restore();expect(session.isAuthenticated,isFalse);expect(session.sync.activeUser,isNull);api.close();
  });
}
