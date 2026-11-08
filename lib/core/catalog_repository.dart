import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'offline_database.dart';

class CatalogSnapshot {
  final Map<String, dynamic> data;
  final DateTime downloadedAt;
  const CatalogSnapshot(this.data, this.downloadedAt);
  bool get stale => DateTime.now().toUtc().difference(downloadedAt) > const Duration(hours: 24);
}

/// An explicit download stores one bounded page plus its variants/branch stock.
/// No local stock is authoritative and images remain remote URLs.
class CatalogRepository {
  final OfflineDatabase database;
  CatalogRepository({OfflineDatabase? database}) : database = database ?? OfflineDatabase.shared;

  Future<CatalogSnapshot?> read(String tenant, String user, String key) async {
    final rows = await (await database.database).query('catalog_snapshot',
      where: 'tenant = ? AND user_id = ? AND cache_key = ?', whereArgs: [tenant, user, key]);
    if (rows.isEmpty) return null;
    return CatalogSnapshot(jsonDecode(rows.single['payload'] as String) as Map<String, dynamic>,
      DateTime.parse(rows.single['downloaded_at'] as String));
  }

  Future<void> saveSubset({required String tenant, required String user,
      required String pageKey, required Map<String, dynamic> page,
      required List<Map<String, dynamic>> details,
      required Map<String, Map<String, dynamic>> facets}) async {
    final downloadedAt = DateTime.now().toUtc().toIso8601String();
    await (await database.database).transaction((txn) async {
      Future<void> snapshot(String key, Map<String, dynamic> data) => txn.insert('catalog_snapshot', {
        'tenant': tenant, 'user_id': user, 'cache_key': key,
        'payload': jsonEncode(data), 'downloaded_at': downloadedAt,
      }, conflictAlgorithm: ConflictAlgorithm.replace).then((_) {});
      await snapshot(pageKey, page);
      for (final entry in facets.entries) {
        await snapshot('facet:${entry.key}', entry.value);
      }
      for (final detail in details) {
        final productId = detail['idProd'] as String;
        await snapshot('detail:$productId', detail);
        await txn.insert('catalog_product', {
          'tenant': tenant, 'user_id': user, 'id': productId,
          'payload': jsonEncode(detail), 'downloaded_at': downloadedAt,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        for (final variant in detail['variantes'] as List? ?? []) {
          await txn.insert('catalog_variant', {
            'tenant': tenant, 'user_id': user, 'id': variant['idVariante'],
            'product_id': productId, 'payload': jsonEncode(variant),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final stock in detail['disponibilidad'] as List? ?? []) {
          final branch = <String, Object?>{
            'tenant': tenant, 'user_id': user, 'id': stock['nroSuc'],
            'name': stock['sucursal'], 'city': stock['ciudad'],
          };
          final updated = await txn.update('catalog_branch', branch,
            where: 'tenant = ? AND user_id = ? AND id = ?', whereArgs: [tenant, user, stock['nroSuc']]);
          if (updated == 0) await txn.insert('catalog_branch', branch);
          await txn.insert('catalog_availability', {
            'tenant': tenant, 'user_id': user, 'variant_id': stock['idVariante'],
            'branch_id': stock['nroSuc'], 'payload': jsonEncode(stock),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }
}
