import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:arknight_nexus/core/hash/sha256.dart';
import 'package:arknight_nexus/core/http/http_client.dart';
import 'package:arknight_nexus/data_sources/published_data.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/region_snapshot.dart';
import 'package:arknight_nexus/services/region_source.dart';
import 'package:path/path.dart' as p;

/// What happened to one region during a build.
class RegionBuildReport {
  const RegionBuildReport({
    required this.region,
    required this.outcome,
    this.entry,
    this.gzipBytes,
    this.elapsed = Duration.zero,
    this.error,
  });

  final RegionCode region;
  final RegionBuildOutcome outcome;
  final PublishedRegion? entry;

  /// Size after gzip, as GitHub Pages would roughly serve it.
  final int? gzipBytes;
  final Duration elapsed;
  final Object? error;
}

enum RegionBuildOutcome {
  /// Fetched and normalized from upstream.
  generated,

  /// Copied from the previous site: same upstream version and generator.
  reused,

  /// Generation failed; the previous site's copy was kept instead.
  keptPrevious,

  /// Generation failed and there was no usable previous copy.
  failed,
}

class SnapshotBuildResult {
  const SnapshotBuildResult({required this.manifest, required this.regions});

  final PublishedManifest manifest;
  final List<RegionBuildReport> regions;

  bool get hasFailures =>
      regions.any((report) => report.outcome == RegionBuildOutcome.failed);
}

/// Builds the published `data/` directory: one normalized snapshot per
/// region plus `manifest.json`, using the app's own [RegionSource] so the
/// published snapshot is exactly what the app's raw sync would produce.
class SnapshotBuilder {
  SnapshotBuilder({
    required NexusHttpClient httpClient,
    required Directory outDir,
    this.fingerprint,
    void Function(String message)? log,
    DateTime Function()? clock,
  })  : _httpClient = httpClient,
        _source = RegionSource(httpClient: httpClient),
        _outDir = outDir,
        _log = log ?? print,
        _clock = clock ?? (() => DateTime.now().toUtc());

  final NexusHttpClient _httpClient;
  final RegionSource _source;
  final Directory _outDir;
  final void Function(String message) _log;
  final DateTime Function() _clock;

  /// Identifies the generator inputs; see [PublishedManifest.fingerprint].
  final String? fingerprint;

  Future<SnapshotBuildResult> build({
    required List<RegionCode> regions,
    Uri? previousManifestUri,
  }) async {
    final previous = previousManifestUri == null
        ? null
        : await _readPreviousManifest(previousManifestUri);
    final sameGenerator = previous != null &&
        fingerprint != null &&
        previous.fingerprint == fingerprint;

    final reports = <RegionBuildReport>[];
    for (final region in regions) {
      final report = await _buildRegion(
        region,
        previous: previous?.regions[region],
        previousManifestUri: previousManifestUri,
        sameGenerator: sameGenerator,
      );
      reports.add(report);
      _log(_describe(report));
    }

    final manifest = PublishedManifest(
      formatVersion: PublishedData.manifestFormatVersion,
      generatedAt: _clock(),
      fingerprint: fingerprint,
      regions: {
        for (final report in reports)
          if (report.entry != null) report.region: report.entry!,
      },
    );
    await _outDir.create(recursive: true);
    await File(p.join(_outDir.path, PublishedData.manifestFile)).writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
    );
    return SnapshotBuildResult(manifest: manifest, regions: reports);
  }

  Future<RegionBuildReport> _buildRegion(
    RegionCode region, {
    required PublishedRegion? previous,
    required Uri? previousManifestUri,
    required bool sameGenerator,
  }) async {
    final stopwatch = Stopwatch()..start();
    final reusable = previous != null &&
            previousManifestUri != null &&
            previous.schemaVersion == RegionSnapshot.schemaVersion
        ? previous
        : null;

    try {
      final version = await _source.fetchDataVersion(region);
      if (reusable != null &&
          sameGenerator &&
          reusable.versionControl == version.versionControl) {
        try {
          final bytes = await _copyPrevious(reusable, previousManifestUri!);
          return RegionBuildReport(
            region: region,
            outcome: RegionBuildOutcome.reused,
            entry: reusable,
            gzipBytes: gzip.encode(bytes).length,
            elapsed: stopwatch.elapsed,
          );
        } catch (error) {
          _log('${region.value}: previous copy unusable ($error); '
              'regenerating');
        }
      }

      final downloaded = await _source.downloadTables(region);
      final normalized =
          await _source.normalizeInBackground(region, version, downloaded);
      final snapshot = normalized.snapshot;
      final bytes = utf8.encode(jsonEncode(snapshot.toJson()));
      final path = PublishedData.snapshotPath(
        RegionSnapshot.schemaVersion,
        region,
      );
      await _writeFile(path, bytes);
      return RegionBuildReport(
        region: region,
        outcome: RegionBuildOutcome.generated,
        entry: PublishedRegion(
          schemaVersion: snapshot.schemaVersionValue,
          versionControl: snapshot.sourceVersion.versionControl,
          sourceRevision: snapshot.sourceRevision,
          fetchedAt: snapshot.fetchedAt,
          operatorCount: snapshot.operators.length,
          snapshot: PublishedFile(
            path: path,
            sha256: sha256Hex(bytes),
            bytes: bytes.length,
          ),
        ),
        gzipBytes: gzip.encode(bytes).length,
        elapsed: stopwatch.elapsed,
      );
    } catch (error) {
      // A Pages deploy replaces the whole site: keep the last good copy
      // rather than dropping the region.
      if (reusable != null) {
        try {
          final bytes = await _copyPrevious(reusable, previousManifestUri!);
          return RegionBuildReport(
            region: region,
            outcome: RegionBuildOutcome.keptPrevious,
            entry: reusable,
            gzipBytes: gzip.encode(bytes).length,
            elapsed: stopwatch.elapsed,
            error: error,
          );
        } catch (copyError) {
          _log('${region.value}: previous copy unusable ($copyError)');
        }
      }
      return RegionBuildReport(
        region: region,
        outcome: RegionBuildOutcome.failed,
        elapsed: stopwatch.elapsed,
        error: error,
      );
    }
  }

  Future<PublishedManifest?> _readPreviousManifest(Uri uri) async {
    try {
      final body = await _httpClient.getText(uri);
      return PublishedManifest.fromJson(
        jsonDecode(body) as Map<String, Object?>,
      );
    } catch (error) {
      _log('No usable previous manifest at $uri ($error); '
          'generating every region');
      return null;
    }
  }

  /// Downloads the previous site's file, verifies it against its manifest
  /// entry and writes it to the same path.
  Future<Uint8List> _copyPrevious(
    PublishedRegion previous,
    Uri previousManifestUri,
  ) async {
    final file = previous.snapshot;
    final bytes = await _httpClient.getBytes(
      // Manifest paths are relative to the manifest itself.
      previousManifestUri.resolve(file.path),
    );
    if (bytes.length != file.bytes || sha256Hex(bytes) != file.sha256) {
      throw StateError('${file.path} does not match the previous manifest');
    }
    await _writeFile(file.path, bytes);
    return bytes;
  }

  Future<void> _writeFile(String relativePath, List<int> bytes) async {
    final file = File(p.joinAll([_outDir.path, ...relativePath.split('/')]));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }
}

String _describe(RegionBuildReport report) {
  final region = report.region.value;
  final seconds = (report.elapsed.inMilliseconds / 1000).toStringAsFixed(1);
  final entry = report.entry;
  final size = entry == null
      ? ''
      : ' ${entry.snapshot.bytes} bytes, ${report.gzipBytes} gzipped,';
  final error = report.error == null ? '' : ' error: ${report.error}';
  return '$region: ${report.outcome.name}'
      '${entry == null ? '' : ' ${entry.versionControl}'},$size '
      '${seconds}s$error';
}
