import 'package:field_notes/core/storage/photo_store.dart';
import 'package:field_notes/core/sync/local_change_notifier.dart';
import 'package:uuid/uuid.dart';
import 'note.dart';
import 'note_local_data_source.dart';
import 'note_status.dart';

class NoteRepository {
  NoteRepository(this._local, this._photoStore, [this._changes]);

  final NoteLocalDataSource _local;
  final PhotoStore _photoStore;

  // Told after every local write, so sync can start soon after.
  final LocalChangeNotifier? _changes;

  static const _uuid = Uuid();

  Future<List<Note>> list(
      int userId, {
        String? query,
        NoteStatus? status,
        String? siteId,
      }) =>
      _local.list(userId, query: query, status: status, siteId: siteId);

  /// Creates (id == null) or edits a note. [photoSourcePath] is the picker's
  /// temp file; it is copied into app storage before saving.
  Future<void> save({
    required int userId,
    String? id,
    required String siteId,
    required String title,
    String? description,
    double? latitude,
    double? longitude,
    required DateTime notedAt,
    required NoteStatus status,
    required bool photoChanged,
    String? photoSourcePath,
  }) async {
    String? storedPhoto;
    if (photoChanged && photoSourcePath != null) {
      storedPhoto = await _photoStore.copyIn(photoSourcePath);
    }

    final trimmedDescription = description?.trim();
    await _local.save(
      userId: userId,
      id: id ?? _uuid.v4(),
      siteId: siteId,
      title: title.trim(),
      description:
      (trimmedDescription == null || trimmedDescription.isEmpty) ? null : trimmedDescription,
      latitude: latitude,
      longitude: longitude,
      notedAt: notedAt.toUtc(),
      status: status,
      photoChanged: photoChanged,
      localPhotoPath: storedPhoto,
      clientUpdatedAt: DateTime.now().toUtc(),
    );
    _changes?.notify();
  }

  Future<void> delete(int userId, String id) async {
    await _local.softDelete(userId: userId, id: id, now: DateTime.now().toUtc());
    _changes?.notify();
  }
}