import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Keeps note photos in the app's own documents folder, so they survive
/// even when the picker's temporary cache is cleaned.
class PhotoStore {
  static const _uuid = Uuid();

  Future<Directory> _directory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'note_photos'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Copies the picked file in under a random name and returns the new path.
  Future<String> copyIn(String sourcePath) async {
    final dir = await _directory();
    final ext = p.extension(sourcePath).toLowerCase();
    final target = p.join(dir.path, '${_uuid.v4()}${ext.isEmpty ? '.jpg' : ext}');
    await File(sourcePath).copy(target);
    return target;
  }


  /// Saves bytes downloaded from the server under a random name.
  Future<String> saveBytes(List<int> bytes, {String extension = '.jpg'}) async {
    final dir = await _directory();
    final target = p.join(dir.path, '${_uuid.v4()}${extension.isEmpty ? '.jpg' : extension}');
    await File(target).writeAsBytes(bytes, flush: true);
    return target;
  }
}