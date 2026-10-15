import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../core/errors/app_failure.dart';
import '../core/storage/app_directories.dart';
import '../core/storage/atomic_file.dart';
import '../data_sources/region_code.dart';
import '../domain/region_snapshot.dart';
import '../domain/sync_status.dart';
import 'region_cache_repository.dart';

/// Region cache files under `cache/regions/<region>/`.
///
/// Decoded files are kept in memory per region and file, and concurrent
/// reads share one decode: `operators.snapshot.json` is tens of megabytes
/// and most screens read it several times. The large files are decoded and
/// encoded on a background isolate. A write replaces the file and drops the
/// in-memory copy, so the next read sees the new content. This repository
/// must be the only writer of the cache while the app runs.
class JsonRegionCacheRepository implements RegionCacheRepository {
  JsonRegionCacheRepository(this._directories);

  static const _snapshotFile = 'operators.snapshot.json';
  static const _summaryFile = 'operators.summary.json';
  static const _statusFile = 'status.json';
  static const _termsFile = 'terms.json';

  final AppDirectories _directories;
  final _decoded = <String, Future<Object?>>{};

  @override
  Future<RegionSnapshot?> readSnapshot(RegionCode region) async {
    final value = await _read(
      region,
      _snapshotFile,
      _decodeSnapshotInBackground,
    );
    return value as RegionSnapshot?;
  }

  @override
  Future<RegionSummarySnapshot?> readSummary(RegionCode region) async {
    final value = await _read(
      region,
      _summaryFile,
      _decodeSummaryInBackground,
    );
    return value as RegionSummarySnapshot?;
  }

  @override
  Future<RegionSyncStatus?> readStatus(RegionCode region) async {
    final value = await _read(region, _statusFile, (path) async {
      final json = await _readJsonFile(path);
      return json == null ? null : RegionSyncStatus.fromJson(json);
    });
    return value as RegionSyncStatus?;
  }

  @override
  Future<Map<String, String>> readTerms(RegionCode region) async {
    final value = await _read(region, _termsFile, (path) async {
      final json = await _readJsonFile(path);
      return json?.map((key, value) => MapEntry(key, value as String));
    });
    // Callers get their own copy; the cached map stays untouched.
    return {...?value as Map<String, String>?};
  }

  @override
  Future<void> writeSnapshot(RegionSnapshot snapshot) {
    return _write(
      snapshot.region,
      _snapshotFile,
      () => _encodeSnapshotInBackground(snapshot),
    );
  }

  @override
  Future<void> writeSummary(RegionSummarySnapshot summary) {
    return _write(
      summary.region,
      _summaryFile,
      () => _encodeSummaryInBackground(summary),
    );
  }

  @override
  Future<void> writeStatus(RegionSyncStatus status) {
    return _write(
      status.region,
      _statusFile,
      () async => jsonEncode(status.toJson()),
    );
  }

  @override
  Future<void> writeTerms(RegionCode region, Map<String, String> terms) {
    return _write(region, _termsFile, () async => jsonEncode(terms));
  }

  /// Returns the cached decode of [fileName], starting one with [decode]
  /// (given the file path) when there is none. A failed decode is not
  /// cached, so the next read tries again.
  Future<Object?> _read(
    RegionCode region,
    String fileName,
    Future<Object?> Function(String path) decode,
  ) {
    final key = _key(region, fileName);
    final cached = _decoded[key];
    if (cached != null) {
      return cached;
    }

    final loading = () async {
      final file = await _regionFile(region, fileName);
      try {
        return await decode(file.path);
      } on CacheFailure {
        rethrow;
      } catch (error) {
        throw CacheFailure('Failed to read ${file.path}: $error');
      }
    }();
    _decoded[key] = loading;
    loading.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(_decoded[key], loading)) {
          _decoded.remove(key);
        }
      },
    );
    return loading;
  }

  Future<void> _write(
    RegionCode region,
    String fileName,
    Future<String> Function() encode,
  ) async {
    final file = await _regionFile(region, fileName);
    try {
      await writeFileAtomically(file, await encode());
    } catch (error) {
      throw CacheFailure('Failed to write ${file.path}: $error');
    } finally {
      // Also after a failed write: the file may or may not have changed.
      _decoded.remove(_key(region, fileName));
    }
  }

  String _key(RegionCode region, String fileName) =>
      '${region.value}/$fileName';

  Future<File> _regionFile(RegionCode region, String fileName) async {
    final root = await _directories.cacheRoot();
    return File(p.join(root.path, 'regions', region.value, fileName));
  }
}

// Top-level so the closures handed to `Isolate.run` capture nothing but
// their arguments (an instance closure could drag the repository along).

Future<RegionSnapshot?> _decodeSnapshotInBackground(String path) =>
    Isolate.run(() => _decodeSnapshotFile(path));

Future<RegionSummarySnapshot?> _decodeSummaryInBackground(String path) =>
    Isolate.run(() => _decodeSummaryFile(path));

Future<String> _encodeSnapshotInBackground(RegionSnapshot snapshot) =>
    Isolate.run(() => _encodeSnapshot(snapshot));

Future<String> _encodeSummaryInBackground(RegionSummarySnapshot summary) =>
    Isolate.run(() => _encodeSummary(summary));

Future<RegionSnapshot?> _decodeSnapshotFile(String path) async {
  final json = await _readJsonFile(path);
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

Future<RegionSummarySnapshot?> _decodeSummaryFile(String path) async {
  final json = await _readJsonFile(path);
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

/// Compact JSON: the pretty-printed snapshot was about twice the size.
String _encodeSnapshot(RegionSnapshot snapshot) =>
    jsonEncode(snapshot.toJson());

String _encodeSummary(RegionSummarySnapshot summary) =>
    jsonEncode(summary.toJson());

Future<Map<String, Object?>?> _readJsonFile(String path) async {
  final file = File(path);
  if (!await recoverAtomicFile(file)) {
    return null;
  }
  try {
    return jsonDecode(await file.readAsString()) as Map<String, Object?>;
  } catch (error) {
    throw CacheFailure('Failed to read $path: $error');
  }
}
