
import 'package:field_notes/core/database/app_database.dart';

import 'note.dart';
import 'note_status.dart';

class NoteLocalDataSource {
  NoteLocalDataSource(this._database);

  final AppDatabase _database;

  // Note -> site -> customer. Names come from the parents, nothing is duplicated.
  static const _selectJoined = '''
    SELECT n.*,
           s.site_name   AS site_name,
           s.customer_id AS customer_id,
           c.name        AS customer_name
    FROM field_notes n
    JOIN sites s     ON s.id = n.site_id
    JOIN customers c ON c.id = s.customer_id
  ''';

  /// Search + filters in one query. Deleted notes, and notes under a deleted
  /// site or customer, are hidden.
  Future<List<Note>> list(
      int userId, {
        String? query,
        NoteStatus? status,
        String? siteId,
      }) async {
    final db = await _database.database;

    final where = <String>[
      'n.user_id = ?',
      'n.deleted_at IS NULL',
      's.deleted_at IS NULL',
      'c.deleted_at IS NULL',
    ];
    final args = <Object?>[userId];

    if (status != null) {
      where.add('n.status = ?');
      args.add(status.apiValue);
    }
    if (siteId != null) {
      where.add('n.site_id = ?');
      args.add(siteId);
    }

    final text = query?.trim();
    if (text != null && text.isNotEmpty) {
      const like = "LIKE ? ESCAPE '\\'";
      where.add('(n.title $like OR n.description $like OR s.site_name $like OR c.name $like)');
      final pattern = '%${_escapeLike(text)}%';
      args.addAll([pattern, pattern, pattern, pattern]);
    }

    final rows = await db.rawQuery(
      '$_selectJoined WHERE ${where.join(' AND ')} ORDER BY n.noted_at DESC',
      args,
    );
    return rows.map(Note.fromMap).toList();
  }

  /// Insert or update. Photo columns are only touched when [photoChanged] is true.
  Future<void> save({
    required int userId,
    required String id,
    required String siteId,
    required String title,
    String? description,
    double? latitude,
    double? longitude,
    required DateTime notedAt,
    required NoteStatus status,
    required bool photoChanged,
    String? localPhotoPath,
    required DateTime clientUpdatedAt,
  }) async {
    final db = await _database.database;

    final values = <String, Object?>{
      'site_id': siteId,
      'title': title,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'noted_at': notedAt.toUtc().toIso8601String(),
      'status': status.apiValue,
      'client_updated_at': clientUpdatedAt.toUtc().toIso8601String(),
      'sync_status': 'pending',
    };
    if (photoChanged) {
      values['local_photo_path'] = localPhotoPath;
      values['photo_pending'] = 1;
    }

    await db.transaction((txn) async {
      final updated = await txn.update(
        'field_notes',
        values,
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, userId],
      );
      if (updated == 0) {
        await txn.insert('field_notes', {...values, 'id': id, 'user_id': userId});
      }
    });
  }

  Future<void> softDelete({
    required int userId,
    required String id,
    required DateTime now,
  }) async {
    final db = await _database.database;
    final ts = now.toUtc().toIso8601String();
    await db.rawUpdate('''
      UPDATE field_notes
      SET deleted_at = ?, client_updated_at = ?, sync_status = 'pending'
      WHERE user_id = ? AND id = ? AND deleted_at IS NULL
    ''', [ts, ts, userId, id]);
  }

  // % and _ are wildcards in LIKE; escape them so the user's text is literal.
  static String _escapeLike(String v) => v
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');
}