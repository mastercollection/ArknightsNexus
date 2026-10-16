import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:arknight_nexus/core/http/http_client.dart';
import 'package:arknight_nexus/data_sources/data_version.dart';
import 'package:arknight_nexus/data_sources/published_data.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/region_snapshot.dart';
import 'package:arknight_nexus/services/region_source.dart';
import 'package:path/path.dart' as p;

import 'region_labels.dart';
import 'unreleased_operators.dart';

/// What happened to one region during a build.
class RegionBuildReport {
  const RegionBuildReport({
    required this.region,
    required this.outcome,
    this.entry,
    this.gzipBytes,
    this.elapsed = Duration.zero,
    this.error,
    this.unreleasedCounts = const {},
    this.labelStats,
  });

  final RegionCode region;
  final RegionBuildOutcome outcome;
  final PublishedRegion? entry;

  /// Unreleased operators added per source region code; only for a
  /// [RegionBuildOutcome.generated] region.
  final Map<String, int> unreleasedCounts;

  /// How many categorical labels of the unreleased operators were put in
  /// the region's language, and which were kept in a source's; only for a
  /// [RegionBuildOutcome.generated] region with unreleased operator sources.
  final LabelLocalizationStats? labelStats;

  /// Size after gzip, as GitHub Pages would roughly serve it.
  final int? gzipBytes;
  final Duration elapsed;
  final Object? error;
}

enum RegionBuildOutcome {
  /// Fetched and normalized from upstream.
  generated,

  /// Copied from the previous site: same upstream version of the region and
  /// of its unreleased operator sources, and same generator.
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
/// region plus `manifest.json`, using the app's own [RegionSource] so a
/// region's own data is exactly what the app's raw sync would produce.
///
/// On top of that each snapshot gets the operators its region has not
/// released yet, from the regions [unreleasedSourcesFor] names
/// ([mergeUnreleasedOperators]); the app's raw sync cannot add those, as it
/// only downloads the selected region's tables. A region's snapshot
/// therefore depends on its sources too: it is reused from the previous
/// site only while their versions, recorded in
/// [PublishedRegion.unreleasedSourceVersions], are unchanged as well. A
/// source not normalized in this run anyway is read from its previous
/// published copy when that is current, else normalized from upstream.
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

  final _versions = <RegionCode, Future<DataVersion>>{};

  /// Native snapshots of the regions others borrow operators from, kept for
  /// the whole build; other regions' are dropped once written.
  final _sourceNatives = <RegionCode, Future<RegionSnapshot>>{};
  final _sourceSnapshots = <RegionCode, Future<RegionSnapshot>>{};
  final _previousBytes = <String, Future<Uint8List>>{};

  /// The [RegionLabels.tableFiles] bodies of a region normalized in this
  /// run, kept until [_regionLabels] reads them so they are not downloaded
  /// twice.
  final _labelBodies = <RegionCode, Map<String, String>>{};
  final _labels = <RegionCode, Future<RegionLabels>>{};
  PublishedManifest? _previous;
  Uri? _previousManifestUri;
  bool _sameGenerator = false;

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
    _previous = previous;
    _previousManifestUri = previousManifestUri;
    _sameGenerator = sameGenerator;

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
      final version = await _version(region);
      final sources = unreleasedSourcesFor(region);
      final sourceVersions = {
        for (final source in sources)
          source.value: (await _version(source)).versionControl,
      };
      if (reusable != null &&
          sameGenerator &&
          reusable.matchesVersions(version.versionControl, sourceVersions)) {
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

      final native = await _native(region);
      final sourceSnapshots = [
        for (final source in sources) await _sourceSnapshot(source),
      ];
      final labelStats = sources.isEmpty ? null : LabelLocalizationStats();
      final snapshot = mergeUnreleasedOperators(
        native,
        sourceSnapshots,
        labels: {
          if (sources.isNotEmpty)
            for (final labelled in [region, ...sources])
              labelled: await _regionLabels(labelled),
        },
        labelStats: labelStats,
      );
      final bytes = utf8.encode(jsonEncode(snapshot.toJson()));
      final path = PublishedData.snapshotPath(
        RegionSnapshot.schemaVersion,
        region,
      );
      await _writeFile(path, bytes);
      final unreleasedCounts = <String, int>{};
      for (final operator in snapshot.operators) {
        final source = operator.unreleasedSource;
        if (source != null) {
          unreleasedCounts[source] = (unreleasedCounts[source] ?? 0) + 1;
        }
      }
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
            sha256: crypto.sha256.convert(bytes).toString(),
            bytes: bytes.length,
          ),
          unreleasedSourceVersions: snapshot.unreleasedSourceVersions,
        ),
        gzipBytes: gzip.encode(bytes).length,
        elapsed: stopwatch.elapsed,
        unreleasedCounts: unreleasedCounts,
        labelStats: labelStats,
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

  Future<DataVersion> _version(RegionCode region) => _versions.putIfAbsent(
        region,
        () => _source.fetchDataVersion(region),
      );

  /// [region] normalized from its own upstream tables only.
  Future<RegionSnapshot> _native(RegionCode region) {
    Future<RegionSnapshot> normalize() async {
      final version = await _version(region);
      final downloaded = await _source.downloadTables(region);
      // Every region borrows operators or lends them, so needs its labels.
      _labelBodies[region] = {
        for (final file in RegionLabels.tableFiles)
          if (downloaded.bodies[file] case final body?) file: body,
      };
      final normalized =
          await _source.normalizeInBackground(region, version, downloaded);
      return normalized.snapshot;
    }

    if (!_isSource(region)) {
      return normalize();
    }
    return _sourceNatives.putIfAbsent(region, normalize);
  }

  /// [region]'s [RegionLabels], from the tables [_native] downloaded when
  /// it normalized the region, the others (and all of them for a region
  /// read from the previous site) downloaded here.
  Future<RegionLabels> _regionLabels(RegionCode region) {
    return _labels.putIfAbsent(region, () async {
      final bodies = _labelBodies.remove(region) ?? {};
      for (final file in RegionLabels.tableFiles) {
        if (!bodies.containsKey(file)) {
          bodies[file] =
              await _httpClient.getText(region.descriptor.tableUri(file));
        }
      }
      return RegionLabels.fromTables(bodies);
    });
  }

  static bool _isSource(RegionCode region) => RegionCode.values
      .any((other) => unreleasedSourcesFor(other).contains(region));

  /// [region]'s operators to borrow: its native snapshot when this run
  /// normalized it, else its previous published copy when that is current
  /// (the merge skips the operators that copy borrowed itself), else a
  /// fresh native one.
  Future<RegionSnapshot> _sourceSnapshot(RegionCode region) {
    return _sourceSnapshots.putIfAbsent(region, () async {
      final native = _sourceNatives[region];
      if (native != null) {
        return native;
      }
      final previous = _previous?.regions[region];
      final manifestUri = _previousManifestUri;
      final version = await _version(region);
      if (_sameGenerator &&
          previous != null &&
          manifestUri != null &&
          previous.schemaVersion == RegionSnapshot.schemaVersion &&
          previous.versionControl == version.versionControl) {
        try {
          final bytes = await _previousFile(previous.snapshot, manifestUri);
          return RegionSnapshot.fromJson(
            jsonDecode(utf8.decode(bytes)) as Map<String, Object?>,
          );
        } catch (error) {
          _log('${region.value}: previous copy unusable as a source '
              '($error); normalizing it');
        }
      }
      return _native(region);
    });
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
    final bytes = await _previousFile(file, previousManifestUri);
    await _writeFile(file.path, bytes);
    return bytes;
  }

  /// Downloads (once per build) and verifies a file of the previous site.
  Future<Uint8List> _previousFile(PublishedFile file, Uri previousManifestUri) {
    return _previousBytes.putIfAbsent(file.path, () async {
      final bytes = await _httpClient.getBytes(
        // Manifest paths are relative to the manifest itself.
        previousManifestUri.resolve(file.path),
      );
      if (bytes.length != file.bytes ||
          crypto.sha256.convert(bytes).toString() != file.sha256) {
        throw StateError('${file.path} does not match the previous manifest');
      }
      return bytes;
    });
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
  final counts = [
    for (final MapEntry(:key, :value) in report.unreleasedCounts.entries)
      '$value from $key',
  ];
  final unreleased = report.outcome != RegionBuildOutcome.generated
      ? ''
      : ' unreleased: ${counts.isEmpty ? 'none' : counts.join(', ')},';
  final stats = report.labelStats;
  final keptCount = stats?.kept.values.fold(0, (sum, count) => sum + count);
  final kept = [
    for (final MapEntry(:key, :value) in stats?.kept.entries ?? {}.entries)
      value == 1 ? key : '$key x$value',
  ];
  final labels = stats == null
      ? ''
      : ' labels: ${stats.mapped} localized, $keptCount kept'
          '${kept.isEmpty ? '' : ' (${kept.join('; ')})'},';
  return '$region: ${report.outcome.name}'
      '${entry == null ? '' : ' ${entry.versionControl}'},'
      '$size$unreleased$labels ${seconds}s$error';
}
