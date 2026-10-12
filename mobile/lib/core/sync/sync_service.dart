import 'dart:io';

import 'package:dio/dio.dart';
import 'package:field_notes/core/network/api_client.dart';
import 'package:field_notes/core/network/api_exception.dart';
import 'package:field_notes/core/storage/photo_store.dart';
import 'package:path/path.dart' as p;
import 'sync_local_data_source.dart';
import 'sync_state_store.dart';

/// What a sync run could not finish (shown to the user as a count).
class SyncReport {
  int rejected = 0;
  int photoFailures = 0;

  int get problems => rejected + photoFailures;
}

/// Offline-first sync: push local changes, upload photos, pull server changes,
/// download photos. Throws [ApiException] when the server cannot be reached.
class SyncService {
  SyncService({
    required ApiClient api,
    required SyncLocalDataSource local,
    required SyncStateStore state,
    required PhotoStore photos,
  })  : _api = api,
        _local = local,
        _state = state,
        _photos = photos;

  final ApiClient _api;
  final SyncLocalDataSource _local;
  final SyncStateStore _state;
  final PhotoStore _photos;

  Future<int> pendingCount(int userId) => _local.pendingCount(userId);

  Future<SyncReport> sync(int userId) async {
    final report = SyncReport();
    try {
      await _push(userId, report);
      await _uploadPhotos(userId, report);
      await _pull(userId);
      await _downloadPhotos(userId);
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
    return report;
  }

  // ------------------------------------------------------------------ push

  Future<void> _push(int userId, SyncReport report) async {
    final customers = await _local.pending('customers', userId);
    final sites = await _local.pending('sites', userId);
    final notes = await _local.pending('field_notes', userId);
    if (customers.isEmpty && sites.isEmpty && notes.isEmpty) return;

    // The exact edit time we sent, used later to avoid marking a newer edit as synced.
    final sent = <String, String>{
      for (final r in customers) 'customer:${r['id']}': r['client_updated_at'] as String,
      for (final r in sites) 'site:${r['id']}': r['client_updated_at'] as String,
      for (final r in notes) 'note:${r['id']}': r['client_updated_at'] as String,
    };

    final response = await _api.dio.post('/api/sync/push', data: {
      'customers': [
        for (final r in customers)
          {
            'id': r['id'],
            'name': r['name'],
            'contactInfo': r['contact_info'],
            'clientUpdatedAt': r['client_updated_at'],
            'deletedAt': r['deleted_at'],
          },
      ],
      'sites': [
        for (final r in sites)
          {
            'id': r['id'],
            'customerId': r['customer_id'],
            'siteName': r['site_name'],
            'address': r['address'],
            'clientUpdatedAt': r['client_updated_at'],
            'deletedAt': r['deleted_at'],
          },
      ],
      'notes': [
        for (final r in notes)
          {
            'id': r['id'],
            'siteId': r['site_id'],
            'title': r['title'],
            'description': r['description'],
            'latitude': r['latitude'],
            'longitude': r['longitude'],
            'notedAt': r['noted_at'],
            'status': r['status'],
            'clientUpdatedAt': r['client_updated_at'],
            'deletedAt': r['deleted_at'],
          },
      ],
    });

    final results = ((response.data as Map<String, dynamic>)['results'] as List)
        .cast<Map<String, dynamic>>();

    for (final r in results) {
      final entity = r['entity'] as String;
      final id = r['id'] as String;

      // REJECTED stays pending and is counted; ACCEPTED and SKIPPED are both settled
      // (SKIPPED means the server already has a newer edit, the pull will bring it).
      if (r['status'] == 'REJECTED') {
        report.rejected++;
        continue;
      }
      final stamp = sent['$entity:$id'];
      if (stamp != null) await _local.markSynced(_tableOf(entity), id, stamp);
    }
  }

  String _tableOf(String entity) => switch (entity) {
    'customer' => 'customers',
    'site' => 'sites',
    _ => 'field_notes',
  };

  // ---------------------------------------------------------------- photos

  Future<void> _uploadPhotos(int userId, SyncReport report) async {
    for (final row in await _local.notesWithPendingPhoto(userId)) {
      final id = row['id'] as String;
      final localPath = row['local_photo_path'] as String?;

      try {
        if (localPath == null) {
          // The user removed the photo.
          await _api.dio.delete('/api/notes/$id/photo');
          await _local.completePhotoRemoval(id);
        } else if (!await File(localPath).exists()) {
          await _local.dropPhotoPending(id);
          report.photoFailures++;
        } else {
          final form = FormData.fromMap({
            'file': await MultipartFile.fromFile(localPath, filename: p.basename(localPath)),
          });
          final res = await _api.dio.post('/api/notes/$id/photo', data: form);
          final serverName = (res.data as Map<String, dynamic>)['photoPath'] as String?;
          await _local.completePhotoUpload(id, localPath, serverName);
        }
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        if (code == null || code == 401) rethrow; // offline or expired: stop the whole run
        if (code == 400 || code == 413 || code == 415) {
          // The server will never accept this file, do not retry forever.
          await _local.dropPhotoPending(id);
          report.photoFailures++;
        }
        // Other errors (404, 5xx): leave it pending for the next run.
      }
    }
  }

  Future<void> _downloadPhotos(int userId) async {
    for (final row in await _local.notesNeedingPhotoDownload(userId)) {
      final id = row['id'] as String;
      final serverName = row['photo_path'] as String;

      try {
        final res = await _api.dio.get<List<int>>(
          '/api/notes/$id/photo',
          options: Options(responseType: ResponseType.bytes),
        );
        final bytes = res.data;
        if (bytes == null || bytes.isEmpty) continue;

        final path = await _photos.saveBytes(bytes, extension: p.extension(serverName));
        await _local.setLocalPhoto(id, path);
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        if (code == null || code == 401) rethrow;
        // A missing photo must not break the sync, it is retried next time.
      }
    }
  }

  // ------------------------------------------------------------------ pull

  Future<void> _pull(int userId) async {
    final since = _state.read(userId);
    final response = await _api.dio.get(
      '/api/sync/pull',
      queryParameters: {if (since != null) 'since': since},
    );

    final data = response.data as Map<String, dynamic>;
    await _local.applyPull(
      userId,
      customers: (data['customers'] as List).cast<Json>(),
      sites: (data['sites'] as List).cast<Json>(),
      notes: (data['notes'] as List).cast<Json>(),
    );

    // Saved only after the merge worked, so a failed run simply asks again.
    await _state.write(userId, data['serverTime'] as String);
  }
}