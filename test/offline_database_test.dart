import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liveclothesshop_mobile/core/api_client.dart';
import 'package:liveclothesshop_mobile/core/api_error.dart';
import 'package:liveclothesshop_mobile/core/catalog_repository.dart';
import 'package:liveclothesshop_mobile/core/offline_database.dart';
import 'package:liveclothesshop_mobile/core/offline_sync.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu10_consultar_prendas/data/catalogo_api.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu10_consultar_prendas/models/catalogo.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class LegacyStorage implements OfflineQueueStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

String scope(String tenant, String user) =>
  'fashionstore_sync_${base64Url.encode(utf8.encode('$tenant|$user')).replaceAll('=', '')}';

Map<String, dynamic> operation(String id, {String state = 'pending'}) => {
  'id': id, 'tenant': 'a', 'user': 'u', 'type': 'reserva', 'formatVersion': 1,
  'localDate': '2026-11-01T10:00:00Z', 'branch': 1,
  'data': {'lineas': [{'idVariante': 'v1', 'cantidad': 2}]},
  'dependsOn': ['predecessor'], 'state': state, 'attempts': 3,
  'nextAttemptMs': 123, 'code': 'prueba', 'detail': 'resultado', 'nroReserva': 77,
  'nroVenta': 56, 'serverResult': {'estado': state, 'nroVenta': 56, 'idempotente': true},
};

Map<String, dynamic> detail() => {
  'idProd': 'p1', 'descripcion': 'Camisa', 'marca': {'nombre': 'Marca'},
  'categoria': {'descripcion': 'Camisas'}, 'coleccion': {'descripcion': 'Actual'},
  'variantes': [{'idVariante': 'v1', 'sku': 'sku', 'precio': 10,
    'talla': {'idTalla': 1, 'descripcion': 'M'}, 'colores': []}],
  'disponibilidad': [{'nroSuc': 1, 'sucursal': 'Centro', 'ciudad': 'SC',
    'idVariante': 'v1', 'stock': 5, 'cantDisp': 3}],
};

Map<String, dynamic> page() => {
  'items': [{'idProd': 'p1', 'descripcion': 'Camisa',
    'marca': {'nombre': 'Marca'}, 'categoria': {'descripcion': 'Camisas'},
    'coleccion': {'descripcion': 'Actual'}, 'precioMin': 10, 'precioMax': 10,
    'disponible': true, 'totalVariantes': 1}],
  'total': 100, 'offset': 0, 'limit': 20,
};

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late OfflineDatabase database;
  late LegacyStorage legacy;
  late SqliteOfflineQueueStorage storage;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fashionstore-sqlite-test-');
    database = OfflineDatabase(open: () => OfflineDatabase.openAt(databaseFactoryFfi, '${directory.path}/test.db'));
    legacy = LegacyStorage();
    storage = SqliteOfflineQueueStorage(database: database, legacy: legacy);
  });
  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('migración real conserva todos los campos/estados y retiene JSON legado', () async {
    final items = [for (final state in OfflineOperationState.values) operation(state.name, state: state.name)];
    final key = scope('a', 'u');
    legacy.values[key] = jsonEncode(items);
    expect(jsonDecode((await storage.read(key))!), items);
    expect(jsonDecode(legacy.values[key]!), items);
    final db = await database.database;
    expect(await db.query('offline_operation'), hasLength(6));
    expect((await db.query('legacy_migration')).single['item_count'], 6);
    expect((await db.query('offline_operation')).first['tenant'], 'a');
    expect((await db.query('offline_operation')).first.containsKey('credential'), isFalse);
  });

  test('migración repetible/reinicio no revive ni sobreescribe estados del ledger', () async {
    final key = scope('a', 'u');
    legacy.values[key] = jsonEncode([operation('one')]);
    await storage.read(key);
    final updated = operation('one', state: 'synchronized');
    await storage.write(key, jsonEncode([updated]));
    await database.close();
    expect(jsonDecode((await storage.read(key))!), [updated]);
    expect((await (await database.database).query('legacy_migration')), hasLength(1));
    expect(jsonDecode(legacy.values[key]!), [operation('one')]);
  });

  test('SQLite revierte migración interrumpida completa y permite repetir', () async {
    final key = scope('a', 'u');
    legacy.values[key] = jsonEncode([operation('one'), operation('two')]);
    final db = await database.database;
    await db.execute("CREATE TRIGGER interrupt_migration BEFORE INSERT ON offline_operation WHEN NEW.id = 'two' BEGIN SELECT RAISE(ABORT, 'interrupted'); END");
    await expectLater(storage.read(key), throwsA(isA<DatabaseException>()));
    expect(await db.query('offline_operation'), isEmpty);
    expect(await db.query('legacy_migration'), isEmpty);
    expect(legacy.values[key], isNotNull);
    await db.execute('DROP TRIGGER interrupt_migration');
    expect(jsonDecode((await storage.read(key))!), hasLength(2));
  });

  test('JSON corrupto, UUID duplicado y propietario inválido no marcan migración', () async {
    final key = scope('a', 'u');
    for (final raw in ['invalid', jsonEncode([operation('x'), operation('x')]),
      jsonEncode([{...operation('x'), 'tenant': 'other'}])]) {
      legacy.values[key] = raw;
      await expectLater(storage.read(key), throwsFormatException);
      expect(await (await database.database).query('legacy_migration'), isEmpty);
      expect(legacy.values[key], raw);
    }
  });

  test('migración concurrente se ejecuta una sola vez', () async {
    final key = scope('a', 'u');
    legacy.values[key] = jsonEncode([operation('one')]);
    final second = SqliteOfflineQueueStorage(database: database, legacy: legacy);
    final results = await Future.wait([storage.read(key), second.read(key)]);
    expect(results.first, results.last);
    expect(await (await database.database).query('offline_operation'), hasLength(1));
    expect(await (await database.database).query('legacy_migration'), hasLength(1));
  });

  test('dos conexiones SQLite independientes migran sin duplicar ni cambiar UUID', () async {
    final key = scope('a', 'u');
    legacy.values[key] = jsonEncode([operation('one')]);
    final secondDatabase = OfflineDatabase(open: () => OfflineDatabase.openAt(databaseFactoryFfi,
      '${directory.path}/test.db', singleInstance: false));
    final otherStorage = SqliteOfflineQueueStorage(database: secondDatabase, legacy: legacy);
    try {
      // Open both handles before contending on the same migration marker.
      await database.database;
      await secondDatabase.database;
      final results = await Future.wait([storage.read(key), otherStorage.read(key)]);
      expect(results.first, results.last);
      expect(await (await secondDatabase.database).query('offline_operation'), hasLength(1));
      expect(await (await secondDatabase.database).query('legacy_migration'), hasLength(1));
    } finally {
      await secondDatabase.close();
    }
  });

  test('cola real usa SQLite, conserva UUID de processing y persiste respuesta después de reiniciar', () async {
    final key = scope('a', 'u');
    legacy.values[key] = jsonEncode([operation('uuid-existing', state: 'processing')]);
    final api = ApiClient(httpClient: MockClient((request) async {
      final sent = jsonDecode(request.body)['operaciones'] as List;
      expect(sent.single['id'], 'uuid-existing');
      expect(sent.single['dependeDe'], ['predecessor']);
      return http.Response(jsonEncode({'resultados': [
        {'id': 'uuid-existing', 'estado': 'sincronizada', 'nroReserva': 89,
          'nroVenta': 99, 'idempotente': true}]}), 200);
    }));
    final queue = OfflineSyncQueue(api: api, queueStorage: storage)
      ..activate(tenant: 'a', user: 'u', credential: 'fictional');
    await queue.flush();
    await database.close();
    expect((await queue.list()).single.state, OfflineOperationState.synchronized);
    expect((await queue.list()).single.nroReserva, 89);
    expect((await queue.list()).single.nroVenta, 99);
    expect((await queue.list()).single.serverResult!['idempotente'], isTrue);
    queue.activate(tenant: 'a', user: 'other', credential: 'fictional');
    expect(await queue.list(), isEmpty);
    queue.activate(tenant: 'other', user: 'u', credential: 'fictional');
    expect(await queue.list(), isEmpty);
    api.close();
  });

  test('encolados concurrentes SQLite no pierden operaciones', () async {
    final api = ApiClient();
    final q1 = OfflineSyncQueue(api: api, queueStorage: storage)
      ..activate(tenant: 'a', user: 'u', credential: 'fictional');
    final q2 = OfflineSyncQueue(api: api, queueStorage: storage)
      ..activate(tenant: 'a', user: 'u', credential: 'fictional');
    final ids = await Future.wait([q1.enqueue(type: 'reserva', branch: 1, data: {}),
      q2.enqueue(type: 'reserva', branch: 1, data: {})]);
    expect((await q1.list()).map((item) => item.id).toSet(), ids.toSet());
    api.close();
  });

  test('respuesta perdida después del efecto conserva UUID en SQLite y reintenta idempotente tras reiniciar', () async {
    var now=DateTime.now().millisecondsSinceEpoch;
    var attempts=0;final accepted=<String>{};
    final api=ApiClient(httpClient:MockClient((request) async{
      attempts++;
      final sent=(jsonDecode(request.body)['operaciones'] as List).single;
      accepted.add(sent['id'] as String); // Simulated commercial commit before transport loss.
      if(attempts==1)throw http.ClientException('response lost after commit');
      return http.Response(jsonEncode({'resultados':[{'id':sent['id'],'estado':'sincronizada','nroVenta':123,'idempotente':true}]}),200);
    }));
    final first=OfflineSyncQueue(api:api,queueStorage:storage,nowMs:()=>now)
      ..activate(tenant:'a',user:'u',credential:'fictional');
    final id=await first.enqueue(type:'venta',branch:1,data:{'metodo':'efectivo','lineas':[{'idVariante':'v1','cantidad':1,'precio':'10.00'}]});
    await first.flush();
    expect((await first.list()).single.id,id);
    expect((await first.list()).single.state,OfflineOperationState.retryPending);
    await database.close();
    now+=61000; // Advance injected retry clock, not UUID/content or assertions.
    final reopened=OfflineSyncQueue(api:api,queueStorage:storage,nowMs:()=>now)
      ..activate(tenant:'a',user:'u',credential:'fictional');
    await reopened.flush();
    expect(attempts,2);expect(accepted,{id});
    final operation=(await reopened.list()).single;
    expect(operation.id,id);expect(operation.nroVenta,123);expect(operation.serverResult!['idempotente'],isTrue);
    expect(operation.state,OfflineOperationState.synchronized);api.close();
  });

  test('catálogo guarda variantes/sucursales, aísla cuenta y revierte subconjunto inválido', () async {
    final repository = CatalogRepository(database: database);
    await repository.saveSubset(tenant: 'a', user: 'u', pageKey: 'page', page: page(), details: [detail()], facets: {});
    final db = await database.database;
    for (final table in ['catalog_product', 'catalog_variant', 'catalog_branch', 'catalog_availability']) {
      expect(await db.query(table), hasLength(1));
    }
    expect(await repository.read('b', 'u', 'page'), isNull);
    expect(await repository.read('a', 'other', 'page'), isNull);
    final saved = await repository.read('a', 'u', 'detail:p1');
    expect(saved!.data, detail());
    expect(saved.stale, isFalse);
    expect(CatalogSnapshot({}, DateTime.utc(2020)).stale, isTrue);
    final invalid = detail()..['disponibilidad'] = [
      {'nroSuc': 1, 'sucursal': 'Centro', 'ciudad': 'SC', 'idVariante': 'nonexistent'}];
    await expectLater(repository.saveSubset(tenant: 'a', user: 'u', pageKey: 'page',
      page: {'changed': true}, details: [invalid], facets: {}), throwsA(isA<DatabaseException>()));
    expect((await repository.read('a', 'u', 'page'))!.data, page());
    expect((await repository.read('a', 'u', 'detail:p1'))!.data, detail());
  });

  test('descarga explícita, fallback real offline y no ocultar 401/403 con caché', () async {
    final repository = CatalogRepository(database: database);
    var status = 200;
    final api = ApiClient(httpClient: MockClient((request) async {
      if (status != 200) return http.Response('{}', status);
      if (request.url.path.endsWith('/productos')) return http.Response(jsonEncode(page()), 200);
      if (request.url.path.endsWith('/p1')) return http.Response(jsonEncode(detail()), 200);
      return http.Response('{"items":[]}', 200);
    }));
    final catalog = CatalogoApi(api: api, credential: () => 'fictional', repository: repository, tenant: 'a', user: 'u');
    expect(await catalog.descargar(const CatalogoFiltros()), 1);
    status = 503;
    final saved = await catalog.listar(const CatalogoFiltros());
    expect(saved.items.single.idProd, 'p1');
    expect(saved.total, 1); // never advertise 99 products that were not downloaded
    expect(catalog.usingOffline, isTrue);
    expect((await catalog.detalle('p1')).variantes.single.id, 'v1');
    expect(await catalog.faceta('tallas'), isEmpty);
    for (final denied in [401, 403]) {
      status = denied;
      await expectLater(catalog.listar(const CatalogoFiltros()), throwsA(isA<ApiException>()));
    }
    status = 503;
    await expectLater(catalog.listar(const CatalogoFiltros(q: 'otro filtro')), throwsA(isA<ApiException>()));
    api.close();
  });
}
