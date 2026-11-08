import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liveclothesshop_mobile/core/api_client.dart';
import 'package:liveclothesshop_mobile/core/offline_sync.dart';

class MemoryQueueStorage implements OfflineQueueStorage {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async { values[key] = value; }
}

void main() {
  test('sesión vencida conserva UUID; cambio de empresa no lo envía y login propio lo acepta', () async {
    final storage = MemoryQueueStorage();
    var expired = true;
    final sent = <String>[];
    final api = ApiClient(httpClient: MockClient((request) async {
      final operation = (jsonDecode(request.body)['operaciones'] as List).single;
      sent.add(operation['id'] as String);
      if (expired) return http.Response('{}', 401);
      return http.Response(jsonEncode({'resultados': [{'id': operation['id'],
        'estado': 'sincronizada', 'nroReserva': 77}]}), 200);
    }), baseUrl: 'https://example.test', origin: 'https://example.test');
    final queue = OfflineSyncQueue(api: api, queueStorage: storage)
      ..activate(tenant: 'a', user: 'cliente-a', credential: 'old');
    final id = await queue.enqueue(type: 'reserva', branch: 1, data: {'lineas': []});
    await queue.flush();
    expect((await queue.list()).single.id, id);
    expect((await queue.list()).single.code, 'sesion_requerida');
    expect((await queue.list()).single.state, OfflineOperationState.retryPending);
    queue.activate(tenant: 'b', user: 'cliente-b', credential: 'other');
    expect(await queue.list(), isEmpty);
    await queue.flush(); expect(sent, [id]);
    expired = false;
    queue.activate(tenant: 'a', user: 'cliente-a', credential: 'new');
    await queue.flush();
    expect(sent, [id, id]);
    final restored = OfflineSyncQueue(api: api, queueStorage: storage)
      ..activate(tenant: 'a', user: 'cliente-a', credential: 'new');
    expect((await restored.list()).single.nroReserva, 77);
    expect((await restored.list()).single.state, OfflineOperationState.synchronized);
  });

  test('encolados concurrentes no pierden operaciones y conflictos/rechazos quedan persistidos', () async {
    final storage = MemoryQueueStorage();
    final api = ApiClient(httpClient: MockClient((request) async {
      final operations = jsonDecode(request.body)['operaciones'] as List;
      return http.Response(jsonEncode({'resultados': [for (var i=0; i<operations.length; i++)
        {'id': operations[i]['id'], 'estado': i==0 ? 'conflicto' : 'rechazada', 'codigo': 'prueba'}]}), 200);
    }), baseUrl: 'https://example.test', origin: 'https://example.test');
    final queue = OfflineSyncQueue(api: api, queueStorage: storage)
      ..activate(tenant: 'a', user: 'cliente', credential: 'test');
    final ids = await Future.wait([queue.enqueue(type: 'reserva', branch: 1, data: {}),
      queue.enqueue(type: 'reserva', branch: 1, data: {})]);
    expect((await queue.list()).map((item) => item.id).toSet(), ids.toSet());
    await queue.flush();
    final items = await queue.list();
    expect(items, hasLength(2));
    expect(items.map((item) => item.state).toSet(), {OfflineOperationState.conflict, OfflineOperationState.rejected});
  });

  test('persiste por empresa/usuario y sincroniza idempotente con estado servidor', () async {
    final storage = MemoryQueueStorage();
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      expect(request.url.path, '/api/sync/lote');
      final sent = jsonDecode(request.body) as Map<String, dynamic>;
      expect(sent['origen'], 'movil');
      expect((sent['operaciones'] as List).single['tipo'], 'reserva');
      return http.Response(jsonEncode({
        'empresa': 'tienda-a', 'dispositivo': 'fashionstore-flutter',
        'resultados': [
          {'id': (sent['operaciones'] as List).single['id'], 'estado': 'sincronizada', 'intentos': 1}
        ],
        'sincronizadas': 1, 'pendientes': 0, 'conflictos': 0, 'rechazadas': 0,
      }), 200, headers: {'content-type': 'application/json'});
    });
    final queue = OfflineSyncQueue(
      api: ApiClient(httpClient: client, baseUrl: 'https://example.test', origin: 'https://example.test'),
      queueStorage: storage,
    );
    queue.activate(tenant: 'tienda-a', user: 'cliente-1', credential: 'credencial-prueba');
    final id = await queue.enqueue(type: 'reserva', branch: 7, data: {
      'lineas': [{'idVariante': 'VAR-1', 'cantidad': 1}],
      'fecha': '2027-01-20', 'hora': '10:00:00',
    });
    expect(id, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect((await queue.list()).single.state, OfflineOperationState.pending);

    queue.activate(tenant: 'tienda-b', user: 'cliente-1', credential: 'otra-credencial');
    expect(await queue.list(), isEmpty);
    queue.activate(tenant: 'tienda-a', user: 'cliente-1', credential: 'credencial-prueba');
    await queue.flush();

    expect(requests, hasLength(1));
    expect((await queue.list()).single.state, OfflineOperationState.synchronized);
  });

  test('registra el fallo de transporte como reintento, sin declarar sincronización', () async {
    final storage = MemoryQueueStorage();
    final queue = OfflineSyncQueue(
      api: ApiClient(
        httpClient: MockClient((_) async => http.Response('{}', 503)),
        baseUrl: 'https://example.test', origin: 'https://example.test',
      ),
      queueStorage: storage,
    );
    queue.activate(tenant: 'tienda-a', user: 'cajero-1', credential: 'credencial-prueba');
    await queue.enqueue(type: 'venta', branch: 2, data: {
      'lineas': [{'idVariante': 'VAR-2', 'cantidad': 1, 'precio': 10}],
      'metodo': 'efectivo',
    });
    await queue.flush();

    final item = (await queue.list()).single;
    expect(item.state, OfflineOperationState.retryPending);
    expect(item.attempts, 1);
    expect(item.nextAttemptMs, greaterThan(DateTime.now().millisecondsSinceEpoch));
  });

  test('recupera processing interrumpido y serializa dos instancias con lock del sistema operativo', () async {
    final storage = MemoryQueueStorage();
    final entered = Completer<void>();
    final release = Completer<void>();
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      entered.complete();
      await release.future;
      final operation = (jsonDecode(request.body)['operaciones'] as List).single;
      return http.Response(jsonEncode({'resultados': [
        {'id': operation['id'], 'estado': 'sincronizada'}
      ]}), 200, headers: {'content-type': 'application/json'});
    });
    OfflineSyncQueue makeQueue() => OfflineSyncQueue(
      api: ApiClient(httpClient: client, baseUrl: 'https://example.test', origin: 'https://example.test'),
      queueStorage: storage,
    )..activate(tenant: 'tienda-a', user: 'cajero-1', credential: 'credencial-prueba');
    final first = makeQueue();
    final id = await first.enqueue(type: 'venta', branch: 2, data: {'lineas': []});
    // Simulate process death after claiming, before receiving the server reply.
    final key = storage.values.keys.single;
    final queued = (jsonDecode(storage.values[key]!) as List).single as Map<String, dynamic>;
    queued['state'] = OfflineOperationState.processing.name;
    storage.values[key] = jsonEncode([queued]);

    final q1 = makeQueue();
    final q2 = makeQueue();
    final dispatch1 = q1.flush();
    await entered.future;
    final dispatch2 = q2.flush();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(calls, 1);
    release.complete();
    await Future.wait([dispatch1, dispatch2]);

    expect(calls, 1);
    expect((await q1.list()).single.id, id);
    expect((await q1.list()).single.state, OfflineOperationState.synchronized);
  });
}
