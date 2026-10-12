

import 'package:equatable/equatable.dart';

import 'note_status.dart';

class Note extends Equatable {
  const Note({
    required this.id,
    required this.siteId,
    required this.siteName,
    required this.customerId,
    required this.customerName,
    required this.title,
    this.description,
    this.latitude,
    this.longitude,
    required this.notedAt,
    required this.status,
    this.photoPath,
    this.localPhotoPath,
    this.photoPending = false,
    required this.clientUpdatedAt,
    this.updatedAt,
    this.deletedAt,
    this.syncStatus = 'pending',
  });

  final String id;
  final String siteId;

  // Read via JOIN, never stored on the note row.
  final String siteName;
  final String customerId;
  final String customerName;

  final String title;
  final String? description;
  final double? latitude;
  final double? longitude;
  final DateTime notedAt;
  final NoteStatus status;

  /// File name on the server (set after upload / restore).
  final String? photoPath;

  /// Photo file on this phone.
  final String? localPhotoPath;

  /// True when the photo change (upload or removal) is not on the server yet.
  final bool photoPending;

  final DateTime clientUpdatedAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String syncStatus;

  bool get isPending => syncStatus == 'pending';
  bool get hasLocation => latitude != null && longitude != null;

  /// A removal that is still waiting to sync leaves photoPath set but pending.
  bool get hasPhoto => localPhotoPath != null || (photoPath != null && !photoPending);

  /// Expects `field_notes n JOIN sites s JOIN customers c` with the aliases used in the data source.
  factory Note.fromMap(Map<String, Object?> m) => Note(
    id: m['id'] as String,
    siteId: m['site_id'] as String,
    siteName: (m['site_name'] as String?) ?? '',
    customerId: (m['customer_id'] as String?) ?? '',
    customerName: (m['customer_name'] as String?) ?? '',
    title: m['title'] as String,
    description: m['description'] as String?,
    latitude: (m['latitude'] as num?)?.toDouble(),
    longitude: (m['longitude'] as num?)?.toDouble(),
    notedAt: DateTime.parse(m['noted_at'] as String),
    status: NoteStatus.fromApi(m['status'] as String?),
    photoPath: m['photo_path'] as String?,
    localPhotoPath: m['local_photo_path'] as String?,
    photoPending: ((m['photo_pending'] as num?) ?? 0) == 1,
    clientUpdatedAt: DateTime.parse(m['client_updated_at'] as String),
    updatedAt: _parse(m['updated_at']),
    deletedAt: _parse(m['deleted_at']),
    syncStatus: m['sync_status'] as String,
  );

  static DateTime? _parse(Object? v) => v == null ? null : DateTime.parse(v as String);

  @override
  List<Object?> get props => [
    id, siteId, siteName, customerId, customerName, title, description,
    latitude, longitude, notedAt, status, photoPath, localPhotoPath,
    photoPending, clientUpdatedAt, updatedAt, deletedAt, syncStatus,
  ];
}