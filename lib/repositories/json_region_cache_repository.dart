import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/errors/app_failure.dart';
import '../core/storage/app_directories.dart';
import '../data_sources/region_code.dart';
import '../domain/region_snapshot.dart';
import '../domain/sync_status.dart';
import 'region_cache_repository.dart';

class JsonRegionCacheRepository implements RegionCacheRepository {
  const JsonRegionCacheRepository(this._directories);

  final AppDirectories _directories;

  @override
  Future<RegionSnapshot?> readSnapshot(RegionCode region) async {
    final json = await _readJsonOrNull(region, 'operators.snapshot.json');
    if (json == null) {
      return null;
    }

    try {
      return RegionSnapshot.fromJson(json);
    } on CacheFailure catch (error) {
      if (error.message.startsWith('Unsupported region snapshot schema')) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<RegionSummarySnapshot?> readSummary(RegionCode region) async {
    final json = await _readJsonOrNull(region, 'operators.summary.json');
    if (json == null) {
      return null;
    }

    try {
      return RegionSummarySnapshot.fromJson(json);
    } on CacheFailure catch (error) {
      if (error.message.startsWith('Unsupported region summary schema')) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<RegionSyncStatus?> readStatus(RegionCode region) async {
    final json = await _readJsonOrNull(region, 'status.json');
    return json == null ? null : RegionSyncStatus.fromJson(json);
  }

  @override
  Future<Map<String, String>> readTerms(RegionCode region) async {
    final json = await _readJsonOrNull(region, 'terms.json');
    if (json == null) {
      return {};
    }

    return json.map((key, value) => MapEntry(key, value as String));
  }

  @override
  Future<void> writeSnapshot(RegionSnapshot snapshot) {
    return _writeJson(
      snapshot.region,
      'operators.snapshot.json',
      snapshot.toJson(),
    );
  }

  @override
  Future<void> writeSummary(RegionSummarySnapshot summary) {
    return _writeJson(
      summary.region,
      'operators.summary.json',
      summary.toJson(),
    );
  }

  @override
  Future<void> writeStatus(RegionSyncStatus status) {
    return _writeJson(status.region, 'status.json', status.toJson());
  }

  @override
  Future<void> writeTerms(RegionCode region, Map<String, String> terms) {
    return _writeJson(region, 'terms.json', terms);
  }

  Future<Map<String, Object?>?> _readJsonOrNull(
    RegionCode region,
    String fileName,
  ) async {
    final file = await _regionFile(region, fileName);
    if (!await file.exists()) {
      return null;
    }

    try {
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, Object?>;
    } catch (error) {
      throw CacheFailure('Failed to read ${file.path}: $error');
    }
  }

  Future<void> _writeJson(
    RegionCode region,
    String fileName,
    Object? value,
  ) async {
    final file = await _regionFile(region, fileName);
    await file.parent.create(recursive: true);
    final tempFile = File('${file.path}.tmp');

    try {
      await tempFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(value),
      );
      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(file.path);
    } catch (error) {
      throw CacheFailure('Failed to write ${file.path}: $error');
    }
  }

  Future<File> _regionFile(RegionCode region, String fileName) async {
    final root = await _directories.cacheRoot();
    return File(p.join(root.path, 'regions', region.value, fileName));
  }
}
