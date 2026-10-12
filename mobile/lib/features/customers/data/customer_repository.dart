import 'package:field_notes/core/sync/local_change_notifier.dart';
import 'package:uuid/uuid.dart';

import 'customer.dart';
import 'customer_local_data_source.dart';

class CustomerRepository {
  CustomerRepository(this._local, [this._changes]);

  final CustomerLocalDataSource _local;
  final LocalChangeNotifier? _changes;
  static const _uuid = Uuid();

  Future<List<Customer>> list(int userId) => _local.list(userId);

  Future<Customer?> get(int userId, String id) => _local.findById(userId, id);

  /// Creates a new customer (id == null) or edits an existing one.
  /// The UUID is made here on the device so it works fully offline.
  Future<void> save({
    required int userId,
    String? id,
    required String name,
    String? contactInfo,
  }) async {
    final trimmedContact = contactInfo?.trim();
    await _local.upsert(
      userId: userId,
      id: id ?? _uuid.v4(),
      name: name.trim(),
      contactInfo: (trimmedContact == null || trimmedContact.isEmpty) ? null : trimmedContact,
      clientUpdatedAt: DateTime.now().toUtc(),
    );
    _changes?.notify();
  }

  Future<void> delete(int userId, String id) async {
    await _local.softDeleteCascade(userId: userId, id: id, now: DateTime.now().toUtc());
    _changes?.notify();
  }
}