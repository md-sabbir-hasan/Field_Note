import 'package:field_notes/core/database/app_database.dart';
import 'package:sqflite/sqflite.dart';

import 'customer.dart';

/// Raw SQLite access for customers. No business rules here.
class CustomerLocalDataSource {
  CustomerLocalDataSource(this._database);

  final AppDatabase _database;

  Future<List<Customer>> list(int userId) async {
    final db = await _database.database;
    final rows = await db.query(
      'customers',
      where: 'user_id = ? AND deleted_at IS NULL',
      whereArgs: [userId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<Customer?> findById(int userId, String id) async {
    final db = await _database.database;
    final rows = await db.query(
      'customers',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
      limit: 1,
    );
    return rows.isEmpty ? null : Customer.fromMap(rows.first);
  }

  Future<void> upsert({
    required int userId,
    required String id,
    required String name,
    String? contactInfo,
    required DateTime clientUpdatedAt,
  }) async {
    final db = await _database.database;
    // Insert-or-update in one statement. Server fields (updated_at) are kept on update.
    await db.rawInsert('''
      INSERT INTO customers (id, user_id, name, contact_info, client_updated_at, sync_status)
      VALUES (?, ?, ?, ?, ?, 'pending')
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        contact_info = excluded.contact_info,
        client_updated_at = excluded.client_updated_at,
        sync_status = 'pending'
    ''', [id, userId, name, contactInfo, clientUpdatedAt.toUtc().toIso8601String()]);
  }

  /// Soft delete the customer and everything below it in one transaction.
  Future<void> softDeleteCascade({
    required int userId,
    required String id,
    required DateTime now,
  }) async {
    final db = await _database.database;
    final ts = now.toUtc().toIso8601String();

    await db.transaction((txn) async {
      // Notes of this customer's sites.
      await txn.rawUpdate('''
        UPDATE field_notes
        SET deleted_at = ?, client_updated_at = ?, sync_status = 'pending'
        WHERE user_id = ? AND deleted_at IS NULL
          AND site_id IN (SELECT id FROM sites WHERE customer_id = ?)
      ''', [ts, ts, userId, id]);

      await txn.rawUpdate('''
        UPDATE sites
        SET deleted_at = ?, client_updated_at = ?, sync_status = 'pending'
        WHERE user_id = ? AND customer_id = ? AND deleted_at IS NULL
      ''', [ts, ts, userId, id]);

      await txn.rawUpdate('''
        UPDATE customers
        SET deleted_at = ?, client_updated_at = ?, sync_status = 'pending'
        WHERE user_id = ? AND id = ? AND deleted_at IS NULL
      ''', [ts, ts, userId, id]);
    });
  }
}