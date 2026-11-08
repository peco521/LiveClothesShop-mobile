import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:path_provider/path_provider.dart';

/// Device data only. Authentication credentials never enter this database.
/// All primary keys include the company AND user, not just a product/UUID.
class OfflineDatabase {
  final Future<Database> Function() _open;
  Future<Database>? _database;

  // Public named argument allows tests to inject a real isolated SQLite file.
  // ignore: prefer_initializing_formals
  OfflineDatabase({required Future<Database> Function() open}) : _open = open;

  static final shared = OfflineDatabase(open: () async {
    DatabaseFactory factory = databaseFactory;
    if (Platform.isWindows || Platform.isLinux) {
      ffi.sqfliteFfiInit();
      factory = ffi.databaseFactoryFfi;
    }
    final directory = Platform.isWindows || Platform.isLinux
        ? (await getApplicationSupportDirectory()).path
        : await factory.getDatabasesPath();
    return openAt(factory, '$directory${Platform.pathSeparator}fashionstore-offline.db');
  });

  static Future<Database> openAt(DatabaseFactory factory, String path, {bool singleInstance = true}) =>
      factory.openDatabase(path, options: OpenDatabaseOptions(
        version: 1,
        singleInstance: singleInstance,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          // Long synchronous busy waits starve the shared sqflite FFI isolate:
          // the first handle cannot COMMIT while another blocks BEGIN. Retry
          // briefly from Dart instead so both connections can make progress.
          await db.execute('PRAGMA busy_timeout = 50');
        },
        onCreate: (db, version) async {
          await db.execute('''CREATE TABLE offline_operation (
            scope TEXT NOT NULL, id TEXT NOT NULL, tenant TEXT NOT NULL,
            user_id TEXT NOT NULL, state TEXT NOT NULL, payload TEXT NOT NULL,
            PRIMARY KEY (scope, id))''');
          await db.execute('''CREATE TABLE legacy_migration (
            scope TEXT PRIMARY KEY, verified_at TEXT NOT NULL, item_count INTEGER NOT NULL)''');
          await db.execute('''CREATE TABLE catalog_snapshot (
            tenant TEXT NOT NULL, user_id TEXT NOT NULL, cache_key TEXT NOT NULL,
            payload TEXT NOT NULL, downloaded_at TEXT NOT NULL,
            PRIMARY KEY (tenant, user_id, cache_key))''');
          await db.execute('''CREATE TABLE catalog_product (
            tenant TEXT NOT NULL, user_id TEXT NOT NULL, id TEXT NOT NULL,
            payload TEXT NOT NULL, downloaded_at TEXT NOT NULL,
            PRIMARY KEY (tenant, user_id, id))''');
          await db.execute('''CREATE TABLE catalog_variant (
            tenant TEXT NOT NULL, user_id TEXT NOT NULL, id TEXT NOT NULL,
            product_id TEXT NOT NULL, payload TEXT NOT NULL,
            PRIMARY KEY (tenant, user_id, id),
            FOREIGN KEY (tenant, user_id, product_id)
              REFERENCES catalog_product(tenant, user_id, id) ON DELETE CASCADE)''');
          await db.execute('''CREATE TABLE catalog_branch (
            tenant TEXT NOT NULL, user_id TEXT NOT NULL, id INTEGER NOT NULL,
            name TEXT NOT NULL, city TEXT NOT NULL,
            PRIMARY KEY (tenant, user_id, id))''');
          await db.execute('''CREATE TABLE catalog_availability (
            tenant TEXT NOT NULL, user_id TEXT NOT NULL, variant_id TEXT NOT NULL,
            branch_id INTEGER NOT NULL, payload TEXT NOT NULL,
            PRIMARY KEY (tenant, user_id, variant_id, branch_id),
            FOREIGN KEY (tenant, user_id, variant_id)
              REFERENCES catalog_variant(tenant, user_id, id) ON DELETE CASCADE,
            FOREIGN KEY (tenant, user_id, branch_id)
              REFERENCES catalog_branch(tenant, user_id, id))''');
        },
      ));

  Future<Database> get database => _database ??= _open().catchError((Object error, StackTrace stack) {
    _database = null;
    Error.throwWithStackTrace(error, stack);
  });

  /// Migration is atomic and repeatable across foreground/background isolates.
  /// The legacy copy is intentionally retained, even after read-back verification.
  Future<void> migrateQueue(String scope, Future<String?> Function() readLegacy) async {
    final db = await database;
    if ((await db.query('legacy_migration', where: 'scope = ?', whereArgs: [scope])).isNotEmpty) return;
    final raw = await readLegacy();
    final items = raw == null ? <dynamic>[] : jsonDecode(raw) as List;
    final decoded = items.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    final owner = _ownerFromScope(scope);
    final ids = <String>{};
    for (final item in decoded) {
      if (item['id'] is! String || !ids.add(item['id'] as String)
          || item['tenant'] != owner.$1 || item['user'] != owner.$2
          || item['data'] is! Map || item['dependsOn'] is! List
          || !(item['dependsOn'] as List).every((id) => id is String)
          || item['type'] is! String || item['formatVersion'] is! int
          || item['localDate'] is! String || item['branch'] is! int
          || !const {'pending', 'retryPending', 'processing', 'synchronized', 'conflict', 'rejected'}.contains(item['state'])) {
        throw const FormatException('Cola heredada inválida o de otro propietario');
      }
    }
    await _transaction(db, (txn) async {
      if ((await txn.query('legacy_migration', where: 'scope = ?', whereArgs: [scope])).isNotEmpty) return;
      for (final item in decoded) {
        // Never silently replace a ledger row from a previous/incomplete migration.
        await txn.insert('offline_operation', _operationRow(scope, item), conflictAlgorithm: ConflictAlgorithm.ignore);
        final saved = await txn.query('offline_operation', where: 'scope = ? AND id = ?', whereArgs: [scope, item['id']]);
        if (saved.single['payload'] != jsonEncode(item)) {
          throw StateError('No se pudo verificar la migración de la cola');
        }
      }
      await txn.insert('legacy_migration', {
        'scope': scope, 'verified_at': DateTime.now().toUtc().toIso8601String(),
        'item_count': decoded.length,
      });
    });
  }

  (String, String) _ownerFromScope(String scope) {
    const prefix = 'fashionstore_sync_';
    if (!scope.startsWith(prefix)) throw const FormatException('Clave de cola inválida');
    final owner = utf8.decode(base64Url.decode(base64Url.normalize(scope.substring(prefix.length))));
    final separator = owner.indexOf('|');
    if (separator < 1 || separator == owner.length - 1) throw const FormatException('Propietario inválido');
    return (owner.substring(0, separator), owner.substring(separator + 1));
  }

  Map<String, Object?> _operationRow(String scope, Map<String, dynamic> item) => {
    'scope': scope, 'id': item['id'], 'tenant': item['tenant'],
    'user_id': item['user'], 'state': item['state'], 'payload': jsonEncode(item),
  };

  Future<String> readQueue(String scope) async {
    final rows = await (await database).query('offline_operation', where: 'scope = ?', whereArgs: [scope], orderBy: 'rowid');
    return '[${rows.map((row) => row['payload'] as String).join(',')}]';
  }

  Future<void> writeQueue(String scope, String value) async {
    final items = (jsonDecode(value) as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
    final owner = _ownerFromScope(scope);
    for (final item in items) {
      if (item['tenant'] != owner.$1 || item['user'] != owner.$2) {
        throw StateError('Operación de otro propietario');
      }
    }
    await _transaction(await database, (txn) async {
      // Upsert rather than deleting history: synchronized/rejected entries are a ledger.
      for (final item in items) {
        await txn.insert('offline_operation', _operationRow(scope, item), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<T> _transaction<T>(Database db, Future<T> Function(Transaction) action) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await db.transaction(action);
      } on DatabaseException catch (error) {
        if (attempt >= 30 || !error.toString().toLowerCase().contains('database is locked')) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 20 + attempt * 5));
      }
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) await (await db).close();
    _database = null;
  }
}
