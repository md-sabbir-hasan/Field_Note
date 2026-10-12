import 'package:equatable/equatable.dart';

class Customer extends Equatable {
  const Customer({
    required this.id,
    required this.name,
    this.contactInfo,
    required this.clientUpdatedAt,
    this.updatedAt,
    this.deletedAt,
    this.syncStatus = 'pending',
  });

  final String id;
  final String name;
  final String? contactInfo;

  /// When the user made the edit (device clock, UTC). Used for last-write-wins.
  final DateTime clientUpdatedAt;

  /// Server save time. Null means the server has not seen this record yet.
  final DateTime? updatedAt;

  /// Non-null means soft deleted.
  final DateTime? deletedAt;

  /// 'pending' (needs push) or 'synced'.
  final String syncStatus;

  bool get isPending => syncStatus == 'pending';

  factory Customer.fromMap(Map<String, Object?> m) => Customer(
    id: m['id'] as String,
    name: m['name'] as String,
    contactInfo: m['contact_info'] as String?,
    clientUpdatedAt: DateTime.parse(m['client_updated_at'] as String),
    updatedAt: _parse(m['updated_at']),
    deletedAt: _parse(m['deleted_at']),
    syncStatus: m['sync_status'] as String,
  );

  static DateTime? _parse(Object? v) => v == null ? null : DateTime.parse(v as String);

  @override
  List<Object?> get props =>
      [id, name, contactInfo, clientUpdatedAt, updatedAt, deletedAt, syncStatus];
}