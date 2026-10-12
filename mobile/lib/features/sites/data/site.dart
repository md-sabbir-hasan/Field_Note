import 'package:equatable/equatable.dart';

class Site extends Equatable {
  const Site({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.siteName,
    this.address,
    required this.clientUpdatedAt,
    this.updatedAt,
    this.deletedAt,
    this.syncStatus = 'pending',
  });

  final String id;
  final String customerId;

  /// Read from the customers table via JOIN. Never stored on the site row.
  final String customerName;

  final String siteName;
  final String? address;
  final DateTime clientUpdatedAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String syncStatus;

  bool get isPending => syncStatus == 'pending';

  /// Expects the columns of `sites s JOIN customers c` with `c.name AS customer_name`.
  factory Site.fromMap(Map<String, Object?> m) => Site(
    id: m['id'] as String,
    customerId: m['customer_id'] as String,
    customerName: (m['customer_name'] as String?) ?? '',
    siteName: m['site_name'] as String,
    address: m['address'] as String?,
    clientUpdatedAt: DateTime.parse(m['client_updated_at'] as String),
    updatedAt: _parse(m['updated_at']),
    deletedAt: _parse(m['deleted_at']),
    syncStatus: m['sync_status'] as String,
  );

  static DateTime? _parse(Object? v) => v == null ? null : DateTime.parse(v as String);

  @override
  List<Object?> get props => [
    id, customerId, customerName, siteName, address,
    clientUpdatedAt, updatedAt, deletedAt, syncStatus,
  ];
}