
import 'package:field_notes/core/database/app_database.dart';

import 'site.dart';

class SiteLocalDataSource {
  SiteLocalDataSource(this._database);

  final AppDatabase _database;

  static const _selectWithCustomer = '''
    SELECT s.*, c.name AS customer_name
    FROM sites s
    JOIN customers c ON c.id = s.customer_id
  ''';

  /// Active sites of the user, optionally for one customer.
  Future<List<Site>> list(int userId, {String? customerId}) async {
    final db = await _database.database;
    final rows = await db.rawQuery('''
      $_selectWithCustomer
      WHERE s.user_id = ? AND s.deleted_at IS NULL AND c.deleted_at IS NULL
        AND (? IS NULL OR s.customer_id = ?)
      ORDER BY s.site_name COLLATE NOCASE ASC
    ''', [userId, customerId, customerId]);
    return rows.map(Site.fromMap).toList();
  }

  Future<Site?> findById(int userId, String id) async {
    final db = await _database.database;
    final rows = await db.rawQuery('''
      $_selectWithCustomer
      WHERE s.id = ? AND s.user_id = ?
      LIMIT 1
    ''', [id, userId]);
    return rows.isEmpty ? null : Site.fromMap(rows.first);
  }

  Future<void> upsert({
    required int userId,
    required String id,
    required String customerId,
    required String siteName,
    String? address,
    required DateTime clientUpdatedAt,
  }) async {
    final db = await _database.database;
    await db.rawInsert('''
      INSERT INTO sites (id, user_id, customer_id, site_name, address, client_updated_at, sync_status)
      VALUES (?, ?, ?, ?, ?, ?, 'pending')
      ON CONFLICT(id) DO UPDATE SET
        customer_id = excluded.customer_id,
        site_name = excluded.site_name,
        address = excluded.address,
        client_updated_at = excluded.client_updated_at,
        sync_status = 'pending'
    ''', [id, userId, customerId, siteName, address, clientUpdatedAt.toUtc().toIso8601String()]);
  }

  /// Soft delete the site and its notes in one transaction.
  Future<void> softDeleteCascade({
    required int userId,
    required String id,
    required DateTime now,
  }) async {
    final db = await _database.database;
    final ts = now.toUtc().toIso8601String();

    await db.transaction((txn) async {
      await txn.rawUpdate('''
        UPDATE field_notes
        SET deleted_at = ?, client_updated_at = ?, sync_status = 'pending'
        WHERE user_id = ? AND site_id = ? AND deleted_at IS NULL
      ''', [ts, ts, userId, id]);

      await txn.rawUpdate('''
        UPDATE sites
        SET deleted_at = ?, client_updated_at = ?, sync_status = 'pending'
        WHERE user_id = ? AND id = ? AND deleted_at IS NULL
      ''', [ts, ts, userId, id]);
    });
  }
}