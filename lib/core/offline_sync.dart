import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:workmanager/workmanager.dart';

import 'api_client.dart';
import 'api_config.dart';
import 'api_error.dart';
import 'credential_store.dart';
import 'offline_database.dart';

const _backgroundSyncTask = 'fashionstore-offline-sync';

/// Android WorkManager / iOS BGTaskScheduler dispatcher. Tokens and queue
/// credentials remain in secure storage; task input never contains credentials.
@pragma('vm:entry-point')
void offlineSyncCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != _backgroundSyncTask) return true;
    WidgetsFlutterBinding.ensureInitialized();
    final credentialStore = SecureCredentialStore(key: ApiConfig.credentialStorageKey);
    final credential = await credentialStore.read();
    if (credential == null || credential.isEmpty) return true;

    final api = ApiClient();
    try {
      final response = await api.getRaw('/api/auth/me', credential: credential);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final user = body['usuario'] as Map<String, dynamic>;
      final tenant = body['empresa'] as String?;
      final userId = user['idUsuario'] as String?;
      if (body['plataforma'] == true || tenant == null || tenant.isEmpty || userId == null) {
        return true;
      }

      // A new isolate re-reads the identity from the server, never from task
      // arguments or mutable UI state, before selecting its tenant/user queue.
      await credentialStore.writeSessionSnapshot(response.body);
      final queue = OfflineSyncQueue(api: api);
      queue.activate(tenant: tenant, user: userId, credential: credential);
      await queue.flush();
      final remaining = await queue.list();
      return !remaining.any((item) => item.state == OfflineOperationState.pending
          || item.state == OfflineOperationState.retryPending);
    } on ApiException catch (error) {
      // Expired/revoked session: preserve pending work and wait for a foreground
      // login. Network/service failures ask Android to retry; iOS may defer it.
      if (error.status == 401 || error.status == 403) return true;
      return false;
    } catch (_) {
      return false;
    } finally {
      api.close();
    }
  });
}

class OfflineBackgroundWorker {
  static Future<void> initialize() async {
    if (kIsWeb || !(defaultTargetPlatform == TargetPlatform.android
        || defaultTargetPlatform == TargetPlatform.iOS)) {
      return;
    }
    await Workmanager().initialize(offlineSyncCallbackDispatcher);
  }

  static Future<void> schedule() async {
    if (kIsWeb || !(defaultTargetPlatform == TargetPlatform.android
        || defaultTargetPlatform == TargetPlatform.iOS)) {
      return;
    }
    try {
      await Workmanager().registerOneOffTask(
        'fashionstore-sync-queue', _backgroundSyncTask,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(seconds: 30),
      );
    } catch (_) {
      // Platform restrictions must not prevent foreground/manual sync.
    }
  }
}

enum OfflineOperationState { pending, retryPending, processing, synchronized, conflict, rejected }

abstract interface class OfflineQueueStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class _SecureQueueStorage implements OfflineQueueStorage {
  final FlutterSecureStorage storage;
  const _SecureQueueStorage(this.storage);

  @override
  Future<String?> read(String key) => storage.read(key: key);

  @override
  Future<void> write(String key, String value) => storage.write(key: key, value: value);
}

/// Legacy secure JSON is read once per owner and retained as a recovery copy.
class SqliteOfflineQueueStorage implements OfflineQueueStorage {
  final OfflineDatabase database;
  final OfflineQueueStorage legacy;
  SqliteOfflineQueueStorage({OfflineDatabase? database, required this.legacy})
      : database = database ?? OfflineDatabase.shared;

  @override
  Future<String?> read(String key) async {
    await database.migrateQueue(key, () => legacy.read(key));
    return database.readQueue(key);
  }

  @override
  Future<void> write(String key, String value) async {
    await database.migrateQueue(key, () => legacy.read(key));
    await database.writeQueue(key, value);
  }
}

@immutable
class OfflineOperation {
  final String id;
  final String tenant;
  final String user;
  final String type;
  final int formatVersion;
  final String localDate;
  final int branch;
  final Map<String, dynamic> data;
  final List<String> dependsOn;
  final OfflineOperationState state;
  final int attempts;
  final int nextAttemptMs;
  final String? code;
  final String? detail;
  final int? nroReserva;
  final int? nroVenta;
  final Map<String, dynamic>? serverResult;

  const OfflineOperation({required this.id, required this.tenant, required this.user,
    required this.type, required this.formatVersion, required this.localDate,
    required this.branch, required this.data, required this.dependsOn,
    this.state = OfflineOperationState.pending, this.attempts = 0,
    this.nextAttemptMs = 0, this.code, this.detail, this.nroReserva,
    this.nroVenta, this.serverResult});

  Map<String, dynamic> toJson() => {
    'id': id, 'tenant': tenant, 'user': user, 'type': type, 'formatVersion': formatVersion,
    'localDate': localDate, 'branch': branch, 'data': data, 'dependsOn': dependsOn,
    'state': state.name, 'attempts': attempts, 'nextAttemptMs': nextAttemptMs,
    if (code != null) 'code': code, if (detail != null) 'detail': detail,
    if (nroReserva != null) 'nroReserva': nroReserva,
    if (nroVenta != null) 'nroVenta': nroVenta,
    if (serverResult != null) 'serverResult': serverResult,
  };

  factory OfflineOperation.fromJson(Map<String, dynamic> json) => OfflineOperation(
    id: json['id'] as String, tenant: json['tenant'] as String, user: json['user'] as String,
    type: json['type'] as String, formatVersion: json['formatVersion'] as int,
    localDate: json['localDate'] as String, branch: json['branch'] as int,
    data: Map<String, dynamic>.from(json['data'] as Map),
    dependsOn: List<String>.from(json['dependsOn'] as List),
    state: OfflineOperationState.values.firstWhere((state) => state.name == json['state'], orElse: () => OfflineOperationState.pending),
    attempts: json['attempts'] as int? ?? 0, nextAttemptMs: json['nextAttemptMs'] as int? ?? 0,
    code: json['code'] as String?, detail: json['detail'] as String?,
    nroReserva: (json['nroReserva'] as num?)?.toInt(),
    nroVenta: (json['nroVenta'] as num?)?.toInt(),
    serverResult: json['serverResult'] == null ? null : Map<String, dynamic>.from(json['serverResult'] as Map),
  );
}

/// Persistent local queue for the backend contract POST /api/sync/lote.
/// The server remains authoritative; this class never marks a payment approved.
class OfflineSyncQueue {
  final ApiClient api;
  final OfflineQueueStorage storage;
  final int Function() _nowMs;
  String? _tenant;
  String? _user;
  String? _credential;
  bool _running = false;
  String? persistenceError;

  OfflineSyncQueue({required this.api, FlutterSecureStorage? storage, OfflineQueueStorage? queueStorage, int Function()? nowMs})
      : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
        storage = queueStorage ?? SqliteOfflineQueueStorage(
          legacy: _SecureQueueStorage(storage ?? const FlutterSecureStorage()));

  void activate({required String tenant, required String user, required String credential}) {
    _tenant = tenant;
    _user = user;
    _credential = credential;
    unawaited(OfflineBackgroundWorker.schedule());
  }

  void pause() { _tenant = null; _user = null; _credential = null; }

  String? get activeTenant => _tenant;
  String? get activeUser => _user;

  String _key(String tenant, String user) => 'fashionstore_sync_${base64Url.encode(utf8.encode('$tenant|$user')).replaceAll('=', '')}';

  Future<List<OfflineOperation>> list() async {
    final tenant = _tenant, user = _user;
    if (tenant == null || user == null) return const [];
    return _read(tenant, user);
  }

  Future<List<OfflineOperation>> _read(String tenant, String user) async {
    final raw = await storage.read(_key(tenant, user));
    if (raw == null) return const [];
    final values = jsonDecode(raw) as List;
    return values.map((value) => OfflineOperation.fromJson(Map<String, dynamic>.from(value as Map))).toList();
  }

  Future<String> enqueue({required String type, required int branch,
      required Map<String, dynamic> data, List<String> dependsOn = const []}) async {
    final tenant = _tenant, user = _user;
    if (tenant == null || user == null || _credential == null) throw StateError('Se requiere una sesión válida de empresa.');
    if (!const {'venta', 'reserva'}.contains(type)) throw ArgumentError.value(type, 'type', 'Tipo offline no soportado');
    final uuid = _uuidV4();
    final operation = OfflineOperation(id: uuid, tenant: tenant, user: user, type: type,
      formatVersion: 1, localDate: DateTime.now().toUtc().toIso8601String(), branch: branch,
      data: Map.unmodifiable(data), dependsOn: List.unmodifiable(dependsOn));
    final lock = await _openLock(tenant, user);
    try {
      final items = [...await _read(tenant, user), operation];
      await _write(tenant, user, items);
    } finally { await lock.close(); }
    unawaited(OfflineBackgroundWorker.schedule());
    return uuid;
  }

  Future<void> flush() async {
    final tenant = _tenant, user = _user, credential = _credential;
    if (_running || tenant == null || user == null || credential == null) return;
    _running = true;
    persistenceError = null;
    final lockName = base64Url.encode(utf8.encode('$tenant|$user')).replaceAll('=', '');
    final lockFile = File('${Directory.systemTemp.path}${Platform.pathSeparator}fashionstore-sync-$lockName.lock');
    RandomAccessFile? lock;
    try {
      await lockFile.parent.create(recursive: true);
      lock = await lockFile.open(mode: FileMode.append);
      // Windows reports a sharing violation instead of waiting for an
      // overlapping lock held by another handle; retry until the owner exits.
      for (var attempt = 0;; attempt++) {
        try {
          await lock.lock(FileLock.exclusive);
          break;
        } on FileSystemException {
          if (attempt >= 300) rethrow;
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
      if (_tenant != tenant || _user != user || _credential != credential) return;
      // A killed isolate can leave an operation in processing. Reclaim it
      // only after acquiring the OS file lock, so another dispatcher cannot
      // still be sending that same batch.
      final stored = await _read(tenant, user);
      final recovered = stored.map((item) => item.state == OfflineOperationState.processing
          ? _copy(item, state: OfflineOperationState.pending) : item).toList();
      if (recovered.any((item) => item.state != OfflineOperationState.processing
          && stored.any((old) => old.id == item.id && old.state == OfflineOperationState.processing))) {
        await _write(tenant, user, recovered);
      }
      final pending = (await list()).where((item) =>
        (item.state == OfflineOperationState.pending || item.state == OfflineOperationState.retryPending)
        && item.nextAttemptMs <= _nowMs()).toList()
        ..sort((a, b) => a.localDate.compareTo(b.localDate));
      for (var start = 0; start < pending.length; start += 25) {
        if (_tenant != tenant || _user != user || _credential != credential) return;
        final batch = pending.skip(start).take(25).toList();
        try {
          final current = await _read(tenant, user);
          final ids = batch.map((item) => item.id).toSet();
          await _write(tenant, user, current.map((item) => ids.contains(item.id)
              ? _copy(item, state: OfflineOperationState.processing) : item).toList());
          final response = await api.postRaw('/api/sync/lote', {
            'dispositivo': 'fashionstore-flutter', 'origen': 'movil',
            'operaciones': batch.map((item) => {
              'id': item.id, 'tipo': item.type, 'version': item.formatVersion,
              'fecha': item.localDate, 'sucursal': item.branch, 'datos': item.data,
              'dependeDe': item.dependsOn,
            }).toList(),
          }, credential: credential);
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final results = (body['resultados'] as List).cast<Map<String, dynamic>>();
          for (final result in results) {
            final original = batch.where((item) => item.id == result['id']).firstOrNull;
            if (original == null) continue;
            final serverState = result['estado'] as String;
            final nextState = switch (serverState) {
              'sincronizada' => OfflineOperationState.synchronized,
              'conflicto' => OfflineOperationState.conflict,
              'rechazada' => OfflineOperationState.rejected,
              _ => OfflineOperationState.retryPending,
            };
            await _replace(original, OfflineOperation(id: original.id, tenant: original.tenant, user: original.user,
              type: original.type, formatVersion: original.formatVersion, localDate: original.localDate,
              branch: original.branch, data: original.data, dependsOn: original.dependsOn,
              state: nextState, attempts: original.attempts + 1,
              nextAttemptMs: nextState == OfflineOperationState.retryPending ? _nowMs() + _backoff(original.attempts + 1) : 0,
              code: result['codigo'] as String?, detail: result['detalle'] as String?,
               nroReserva: (result['nroReserva'] as num?)?.toInt(),
               nroVenta: (result['nroVenta'] as num?)?.toInt(),
               serverResult: Map<String, dynamic>.from(result)));
          }
        } on ApiException catch (error) {
          if (error.status == 401 || error.status == 403) {
            for (final item in batch) {
              await _replace(item, OfflineOperation(id: item.id, tenant: item.tenant, user: item.user,
                type: item.type, formatVersion: item.formatVersion, localDate: item.localDate,
                branch: item.branch, data: item.data, dependsOn: item.dependsOn,
                state: OfflineOperationState.retryPending, attempts: item.attempts + 1,
                code: 'sesion_requerida', detail: 'Inicia sesión de nuevo para sincronizar esta operación.'));
            }
            break;
          }
          for (final item in batch) {
            final attempt = item.attempts + 1;
            await _replace(item, OfflineOperation(id: item.id, tenant: item.tenant, user: item.user,
              type: item.type, formatVersion: item.formatVersion, localDate: item.localDate,
              branch: item.branch, data: item.data, dependsOn: item.dependsOn,
              state: OfflineOperationState.retryPending, attempts: attempt,
              nextAttemptMs: _nowMs() + _backoff(attempt)));
          }
          break;
        } catch (_) {
          for (final item in batch) {
            final attempt = item.attempts + 1;
            await _replace(item, OfflineOperation(id: item.id, tenant: item.tenant, user: item.user,
              type: item.type, formatVersion: item.formatVersion, localDate: item.localDate,
              branch: item.branch, data: item.data, dependsOn: item.dependsOn,
              state: OfflineOperationState.retryPending, attempts: attempt,
              nextAttemptMs: _nowMs() + _backoff(attempt)));
          }
          break;
        }
      }
    } catch (_) {
      // An unavailable/corrupt local database must not crash an unawaited
      // login/background flush or pretend the operation reached the server.
      persistenceError = 'No se pudo acceder a la cola local. Los datos existentes se conservan.';
    } finally {
      if (lock != null) {
        // Closing the handle releases the OS-level file lock. On Windows an
        // explicit unlock can race with handle teardown and report EINVAL.
        await lock.close();
      }
      _running = false;
    }
  }

  OfflineOperation _copy(OfflineOperation item, {required OfflineOperationState state}) => OfflineOperation(
    id: item.id, tenant: item.tenant, user: item.user, type: item.type,
    formatVersion: item.formatVersion, localDate: item.localDate, branch: item.branch,
    data: item.data, dependsOn: item.dependsOn, state: state, attempts: item.attempts,
    nextAttemptMs: item.nextAttemptMs, code: item.code, detail: item.detail,
    nroReserva: item.nroReserva,
    nroVenta: item.nroVenta, serverResult: item.serverResult,
  );

  Future<RandomAccessFile> _openLock(String tenant, String user) async {
    final name = base64Url.encode(utf8.encode('$tenant|$user')).replaceAll('=', '');
    final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}fashionstore-sync-$name.lock');
    await file.parent.create(recursive: true);
    final lock = await file.open(mode: FileMode.append);
    try {
      for (var attempt = 0;; attempt++) {
        try { await lock.lock(FileLock.exclusive); return lock; }
        on FileSystemException {
          if (attempt >= 300) rethrow;
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
    } catch (_) { await lock.close(); rethrow; }
  }

  int _backoff(int attempt) => min(3600000, 60000 * pow(2, min(attempt - 1, 6)).toInt());

  Future<void> _replace(OfflineOperation old, OfflineOperation replacement) async {
    final values = await _read(old.tenant, old.user);
    final updated = values.map((item) => item.id == old.id ? replacement : item).toList();
    await _write(old.tenant, old.user, updated);
  }

  Future<void> _write(String tenant, String user, List<OfflineOperation> values) =>
      storage.write(_key(tenant, user), jsonEncode(values.map((item) => item.toJson()).toList()));

  String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0,8)}-${hex.substring(8,12)}-${hex.substring(12,16)}-${hex.substring(16,20)}-${hex.substring(20)}';
  }
}
