import 'package:field_notes/core/database/app_database.dart';
import 'package:sqflite/sqflite.dart';


typedef Json = Map<String, dynamic>;

/// All SQLite work needed by sync. Kept apart from the feature data sources.
class SyncLocalDataSource {
  SyncLocalDataSource(this._database);

  final AppDatabase _database;

  // ------------------------------------------------------------------ push

  Future<List<Map<String, Object?>>> pending(String table, int userId) async {
    final db = await _database.database;
    return db.query(table,
        where: "user_id = ? AND sync_status = 'pending'", whereArgs: [userId]);
  }

  /// Only marks the row when it was not edited again while the request was running.
  Future<void> markSynced(String table, String id, String clientUpdatedAt) async {
    final db = await _database.database;
    await db.update(
      table,
      {'sync_status': 'synced'},
      where: 'id = ? AND client_updated_at = ?',
      whereArgs: [id, clientUpdatedAt],
    );
  }

  /// Everything the user has not sent yet, photos included.
  Future<int> pendingCount(int userId) async {
    final db = await _database.database;
    final rows = await db.rawQuery('''
      SELECT
        (SELECT COUNT(*) FROM customers WHERE user_id = ? AND sync_status = 'pending') +
        (SELECT COUNT(*) FROM sites WHERE user_id = ? AND sync_status = 'pending') +
        (SELECT COUNT(*) FROM field_notes
           WHERE user_id = ?
             AND (sync_status = 'pending' OR (photo_pending = 1 AND deleted_at IS NULL))
        ) AS total
    ''', [userId, userId, userId]);
    return (rows.first['total'] as num).toInt();
  }

  // ---------------------------------------------------------------- photos

  /// Notes that already exist on the server and still need a photo upload or removal.
  Future<List<Map<String, Object?>>> notesWithPendingPhoto(int userId) async {
    final db = await _database.database;
    return db.query('field_notes',
        where: "user_id = ? AND photo_pending = 1 AND sync_status = 'synced' AND deleted_at IS NULL",
        whereArgs: [userId]);
  }

  /// Server has a photo, this phone does not have the file yet.
  Future<List<Map<String, Object?>>> notesNeedingPhotoDownload(int userId) async {
    final db = await _database.database;
    return db.query('field_notes',
        where: 'user_id = ? AND photo_path IS NOT NULL AND local_photo_path IS NULL '
            'AND photo_pending = 0 AND deleted_at IS NULL',
        whereArgs: [userId]);
  }

  /// No-op when the user picked another photo meanwhile (the path no longer matches).
  Future<void> completePhotoUpload(String id, String uploadedLocalPath, String? serverName) async {
    final db = await _database.database;
    await db.rawUpdate(
      'UPDATE field_notes SET photo_pending = 0, photo_path = ? '
          'WHERE id = ? AND local_photo_path IS ?',
      [serverName, id, uploadedLocalPath],
    );
  }

  Future<void> completePhotoRemoval(String id) async {
    final db = await _database.database;
    await db.rawUpdate(
      'UPDATE field_notes SET photo_pending = 0, photo_path = NULL '
          'WHERE id = ? AND local_photo_path IS NULL',
      [id],
    );
  }

  /// Gives up on a photo the server will never accept, so it is not retried forever.
  Future<void> dropPhotoPending(String id) async {
    final db = await _database.database;
    await db.update('field_notes', {'photo_pending': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setLocalPhoto(String id, String path) async {
    final db = await _database.database;
    await db.update(
      'field_notes',
      {'local_photo_path': path},
      where: 'id = ? AND local_photo_path IS NULL AND photo_pending = 0',
      whereArgs: [id],
    );
  }

  // ------------------------------------------------------------------ pull

  /// Merges the server changes in one transaction (all or nothing).
  Future<void> applyPull(
      int userId, {
        required List<Json> customers,
        required List<Json> sites,
        required List<Json> notes,
      }) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      // Parents first, so a child never points at a missing row.
      for (final c in customers) {
        await _mergeCustomer(txn, userId, c);
      }
      for (final s in sites) {
        await _mergeSite(txn, userId, s);
      }
      for (final n in notes) {
        await _mergeNote(txn, userId, n);
      }
      await _purgeSyncedDeletions(txn, userId);
    });
  }

  Future<void> _mergeCustomer(Transaction txn, int userId, Json j) async {
    final id = j['id'] as String;
    final deleted = j['deletedAt'] != null;
    final row = await _find(txn, 'customers', id);

    final values = <String, Object?>{
      'name': j['name'],
      'contact_info': j['contactInfo'],
      'client_updated_at': _iso(j['clientUpdatedAt']),
      'updated_at': _iso(j['updatedAt']),
      'deleted_at': _iso(j['deletedAt']),
      'sync_status': 'synced',
    };

    if (row == null) {
      if (deleted) return; // nothing to delete locally
      await txn.insert('customers', {...values, 'id': id, 'user_id': userId});
      return;
    }
    if (row['user_id'] != userId || _keepLocal(row, j)) return;
    await txn.update('customers', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _mergeSite(Transaction txn, int userId, Json j) async {
    final id = j['id'] as String;
    final deleted = j['deletedAt'] != null;
    final row = await _find(txn, 'sites', id);

    final values = <String, Object?>{
      'customer_id': j['customerId'],
      'site_name': j['siteName'],
      'address': j['address'],
      'client_updated_at': _iso(j['clientUpdatedAt']),
      'updated_at': _iso(j['updatedAt']),
      'deleted_at': _iso(j['deletedAt']),
      'sync_status': 'synced',
    };

    if (!deleted && await _find(txn, 'customers', j['customerId'] as String) == null) return;

    if (row == null) {
      if (deleted) return;
      await txn.insert('sites', {...values, 'id': id, 'user_id': userId});
      return;
    }
    if (row['user_id'] != userId || _keepLocal(row, j)) return;
    await txn.update('sites', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _mergeNote(Transaction txn, int userId, Json j) async {
    final id = j['id'] as String;
    final deleted = j['deletedAt'] != null;
    final row = await _find(txn, 'field_notes', id);

    final values = <String, Object?>{
      'site_id': j['siteId'],
      'title': j['title'],
      'description': j['description'],
      'latitude': (j['latitude'] as num?)?.toDouble(),
      'longitude': (j['longitude'] as num?)?.toDouble(),
      'noted_at': _iso(j['notedAt']),
      'status': j['status'],
      'client_updated_at': _iso(j['clientUpdatedAt']),
      'updated_at': _iso(j['updatedAt']),
      'deleted_at': _iso(j['deletedAt']),
      'sync_status': 'synced',
    };
    final serverPhoto = j['photoPath'] as String?;

    if (!deleted && await _find(txn, 'sites', j['siteId'] as String) == null) return;

    if (row == null) {
      if (deleted) return;
      await txn.insert('field_notes', {
        ...values,
        'id': id,
        'user_id': userId,
        'photo_path': serverPhoto,
        'photo_pending': 0,
      });
      return;
    }
    if (row['user_id'] != userId || _keepLocal(row, j)) return;

    // A photo change of this phone that is still waiting must not be overwritten.
    final photoPending = ((row['photo_pending'] as num?) ?? 0) == 1;
    if (!photoPending && row['photo_path'] != serverPhoto) {
      values['photo_path'] = serverPhoto;
      values['local_photo_path'] = null; // forces a fresh download
    }
    await txn.update('field_notes', values, where: 'id = ?', whereArgs: [id]);
  }

  /// Last-write-wins: a pending local edit that is as new or newer than the server copy stays.
  bool _keepLocal(Map<String, Object?> row, Json incoming) {
    if (row['sync_status'] != 'pending') return false;
    final local = DateTime.parse(row['client_updated_at'] as String);
    final server = DateTime.parse(incoming['clientUpdatedAt'] as String);
    return !local.isBefore(server);
  }

  /// Deleted rows that the server already knows are no longer needed.
  /// Children go first; a parent is kept while any child row still points at it.
  Future<void> _purgeSyncedDeletions(Transaction txn, int userId) async {
    const done = "user_id = ? AND deleted_at IS NOT NULL AND sync_status = 'synced'";
    await txn.delete('field_notes', where: done, whereArgs: [userId]);
    await txn.delete('sites',
        where: '$done AND NOT EXISTS (SELECT 1 FROM field_notes WHERE site_id = sites.id)',
        whereArgs: [userId]);
    await txn.delete('customers',
        where: '$done AND NOT EXISTS (SELECT 1 FROM sites WHERE customer_id = customers.id)',
        whereArgs: [userId]);
  }

  Future<Map<String, Object?>?> _find(Transaction txn, String table, String id) async {
    final rows = await txn.query(table, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  // One time format everywhere, so string ordering in SQL stays correct.
  String? _iso(Object? v) =>
      v == null ? null : DateTime.parse(v as String).toUtc().toIso8601String();
}