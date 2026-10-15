import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/storage/app_directories.dart';
import 'image_cache_repository.dart';

/// [ImageCacheRepository] backed by the app cache directory. Cache-relative
/// paths use forward slashes and are joined against the platform cache root.
class FileImageCacheRepository implements ImageCacheRepository {
  FileImageCacheRepository(this._directories);

  final AppDirectories _directories;

  Future<String> _absolute(String relativePath) async {
    final root = await _directories.cacheRoot();
    final segments = relativePath.split('/').where((s) => s.isNotEmpty);
    return p.joinAll([root.path, ...segments]);
  }

  @override
  Future<File> fileFor(String relativePath) async {
    return File(await _absolute(relativePath));
  }

  @override
  Future<bool> exists(String relativePath) async {
    return File(await _absolute(relativePath)).exists();
  }

  @override
  Future<void> ensureParent(String parentRelativePath) async {
    await Directory(await _absolute(parentRelativePath))
        .create(recursive: true);
  }

  @override
  Future<void> writePart(String partRelativePath, List<int> bytes) async {
    final file = File(await _absolute(partRelativePath));
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<File> promotePart(String partRelativePath, String relativePath) async {
    final part = File(await _absolute(partRelativePath));
    final target = await _absolute(relativePath);
    return part.rename(target);
  }

  @override
  Future<void> removeIfExists(String relativePath) async {
    final absolute = await _absolute(relativePath);
    final file = File(absolute);
    if (await file.exists()) {
      await file.delete();
      return;
    }

    final directory = Directory(absolute);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
