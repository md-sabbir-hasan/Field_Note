import 'package:field_notes/core/sync/local_change_notifier.dart';
import 'package:uuid/uuid.dart';
import 'site.dart';
import 'site_local_data_source.dart';

class SiteRepository {
  SiteRepository(this._local, [this._changes]);

  final SiteLocalDataSource _local;

  // Told after every local write, so sync can start soon after.
  final LocalChangeNotifier? _changes;

  static const _uuid = Uuid();

  Future<List<Site>> list(int userId, {String? customerId}) =>
      _local.list(userId, customerId: customerId);

  /// Creates (id == null) or edits a site. The UUID is made on the device.
  Future<void> save({
    required int userId,
    String? id,
    required String customerId,
    required String siteName,
    String? address,
  }) async {
    final trimmed = address?.trim();
    await _local.upsert(
      userId: userId,
      id: id ?? _uuid.v4(),
      customerId: customerId,
      siteName: siteName.trim(),
      address: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      clientUpdatedAt: DateTime.now().toUtc(),
    );
    _changes?.notify();
  }

  /// Soft deletes the site and its notes.
  Future<void> delete(int userId, String id) async {
    await _local.softDeleteCascade(userId: userId, id: id, now: DateTime.now().toUtc());
    _changes?.notify();
  }
}