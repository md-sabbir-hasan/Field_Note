import 'package:uuid/uuid.dart';

import 'site.dart';
import 'site_local_data_source.dart';

class SiteRepository {
  SiteRepository(this._local);

  final SiteLocalDataSource _local;
  static const _uuid = Uuid();

  Future<List<Site>> list(int userId, {String? customerId}) =>
      _local.list(userId, customerId: customerId);

  Future<void> save({
    required int userId,
    String? id,
    required String customerId,
    required String siteName,
    String? address,
  }) {
    final trimmed = address?.trim();
    return _local.upsert(
      userId: userId,
      id: id ?? _uuid.v4(),
      customerId: customerId,
      siteName: siteName.trim(),
      address: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      clientUpdatedAt: DateTime.now().toUtc(),
    );
  }

  Future<void> delete(int userId, String id) =>
      _local.softDeleteCascade(userId: userId, id: id, now: DateTime.now().toUtc());
}